#include "mouse.h"

#define CHECK_INSTANCE(instance) STMT_START{                          \
        if(!(SvROK(instance) && SvTYPE(SvRV(instance)) == SVt_PVHV)){ \
            croak("Invalid object instance");                         \
        }                                                             \
    } STMT_END


#define MOUSE_mg_attribute(mg) MOUSE_xa_attribute(MOUSE_mg_xa(mg))

static MGVTBL mouse_accessor_vtbl; /* MAGIC identity */

#define dMOUSE_self  SV* const self = mouse_accessor_get_self(aTHX_ ax, items, cv)

static inline SV*
mouse_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv) {
    if(items < 1){
        croak("Too few arguments for %s", GvNAME(CvGV(cv)));
    }

    /* NOTE: If self has GETMAGIC, $self->accessor will invoke GETMAGIC
     *       before calling methods, so SvGETMAGIC(self) is not necessarily needed here.
     */

    return ST(0);
}


CV*
mouse_accessor_generate(pTHX_ SV* const attr, XSUBADDR_t const accessor_impl){
    AV* const xa = mouse_get_xa(aTHX_ attr);
    CV* xsub;
    MAGIC* mg;

    xsub = newXS(NULL, accessor_impl, __FILE__);
    sv_2mortal((SV*)xsub);

    mg = sv_magicext((SV*)xsub, MOUSE_xa_slot(xa), PERL_MAGIC_ext, &mouse_accessor_vtbl, (char*)xa, HEf_SVKEY);

    MOUSE_mg_flags(mg) = (U16)MOUSE_xa_flags(xa);

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}


#define PUSH_VALUE(value, flags) STMT_START { \
        if((flags) & MOUSEf_ATTR_SHOULD_AUTO_DEREF && GIMME_V == G_ARRAY){ \
            mouse_push_values(aTHX_ value, (flags));                       \
        }                                                                  \
        else{                                                              \
            dSP;                                                           \
            XPUSHs(value ? value : &PL_sv_undef);                          \
            PUTBACK;                                                       \
        }                                                                  \
    } STMT_END                                                             \

/* pushes return values, does auto-deref if needed */
static void
mouse_push_values(pTHX_ SV* const value, U16 const flags){
    dSP;

    assert( flags & MOUSEf_ATTR_SHOULD_AUTO_DEREF && GIMME_V == G_ARRAY );

    if(!(value && SvOK(value))){
        return;
    }

    if(flags & MOUSEf_TC_IS_ARRAYREF){
        AV* av;
        I32 len;
        I32 i;

        if(!IsArrayRef(value)){
            croak("Mouse-panic: Not an ARRAY reference");
        }

        av  = (AV*)SvRV(value);
        len = av_len(av) + 1;
        EXTEND(SP, len);
        for(i = 0; i < len; i++){
            SV** const svp = av_fetch(av, i, FALSE);
            PUSHs(svp ? *svp : &PL_sv_undef);
        }
    }
    else if(flags & MOUSEf_TC_IS_HASHREF){
        HV* hv;
        HE* he;

        if(!IsHashRef(value)){
            croak("Mouse-panic: Not a HASH reference");
        }

        hv = (HV*)SvRV(value);
        hv_iterinit(hv);
        while((he = hv_iternext(hv))){
            EXTEND(SP, 2);
            PUSHs(hv_iterkeysv(he));
            PUSHs(hv_iterval(hv, he));
        }
    }

    PUTBACK;
}

static void
mouse_attr_get(pTHX_ SV* const self, MAGIC* const mg){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* value;

    value = get_slot(self, MOUSE_mg_slot(mg));

    /* check_lazy */
    if( !value && flags & MOUSEf_ATTR_IS_LAZY ){
        value = mouse_xa_set_default(aTHX_ MOUSE_mg_xa(mg), self);
    }

    PUSH_VALUE(value, flags);
}

static void
mouse_attr_set(pTHX_ SV* const self, MAGIC* const mg, SV* value){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* const slot  = MOUSE_mg_slot(mg);

    if(flags & MOUSEf_ATTR_HAS_TC){
        value = mouse_xa_apply_type_constraint(aTHX_ MOUSE_mg_xa(mg), value, flags);
    }

    set_slot(self, slot, value);

    if(flags & MOUSEf_ATTR_IS_WEAK_REF){
        weaken_slot(self, slot);
    }

    if(flags & MOUSEf_ATTR_HAS_TRIGGER){
        SV* const trigger = mcall0s(MOUSE_mg_attribute(mg), "trigger");
        dSP;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(self);
        PUSHs(value);

        PUTBACK;
        call_sv(trigger, G_VOID | G_DISCARD);
        /* need not SPAGAIN */
    }

    PUSH_VALUE(value, flags);
}

XS(XS_Mouse_accessor)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = (MAGIC*)XSANY.any_ptr;

    SP -= items; /* PPCODE */
    PUTBACK;

    if(items == 1){ /* reader */
        mouse_attr_get(aTHX_ self, mg);
    }
    else if (items == 2){ /* writer */
        mouse_attr_set(aTHX_ self, mg, ST(1));
    }
    else{
        mouse_throw_error(MOUSE_mg_attribute(mg), NULL,
            "Expected exactly one or two argument for an accessor");
    }
}


XS(XS_Mouse_reader)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = (MAGIC*)XSANY.any_ptr;

    if (items != 1) {
        mouse_throw_error(MOUSE_mg_attribute(mg), NULL,
            "Cannot assign a value to a read-only accessor");
    }

    SP -= items; /* PPCODE */
    PUTBACK;

    mouse_attr_get(aTHX_ self, mg);
}

XS(XS_Mouse_writer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = (MAGIC*)XSANY.any_ptr;

    if (items != 2) {
        mouse_throw_error(MOUSE_mg_attribute(mg), NULL,
            "Too few arguments for a write-only accessor");
    }

    SP -= items; /* PPCODE */
    PUTBACK;

    mouse_attr_set(aTHX_ self, mg, ST(1));
}

/* simple accessors */

/*
static MAGIC*
mouse_accessor_get_mg(pTHX_ CV* const xsub){
    return moose_mg_find(aTHX_ (SV*)xsub, &mouse_simple_accessor_vtbl, MOOSEf_DIE_ON_FAIL);
}
*/

CV*
mouse_simple_accessor_generate(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl, void* const dptr, I32 const dlen){
    CV* const xsub = newXS((char*)fq_name, accessor_impl, __FILE__);
    SV* const slot = newSVpvn_share(key, keylen, 0U);
    MAGIC* mg;

    if(!fq_name){
        /* anonymous xsubs need sv_2mortal */
        sv_2mortal((SV*)xsub);
    }

    mg = sv_magicext((SV*)xsub, slot, PERL_MAGIC_ext, &mouse_accessor_vtbl, (char*)dptr, dlen);
    SvREFCNT_dec(slot); /* sv_magicext() increases refcnt in mg_obj */
    if(dlen == HEf_SVKEY){
        SvREFCNT_dec(dptr);
    }

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}

XS(XS_Mouse_simple_reader)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = (MAGIC*)XSANY.any_ptr;
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a reader for '%"SVf"'", MOUSE_mg_slot(mg));
    }

    value = get_slot(self, MOUSE_mg_slot(mg));
    if(!value) {
        if(MOUSE_mg_ptr(mg)){
            /* the default value must be a SV */
            assert(MOUSE_mg_len(mg) == HEf_SVKEY);
            value = (SV*)MOUSE_mg_ptr(mg);
        }
        else{
            value = &PL_sv_undef;
        }
    }

    ST(0) = value;
    XSRETURN(1);
}


XS(XS_Mouse_simple_writer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);

    if (items != 2) {
        croak("Expected exactly two argument for a writer for '%"SVf"'", slot);
    }

    ST(0) = set_slot(self, slot, ST(1));
    XSRETURN(1);
}

XS(XS_Mouse_simple_clearer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a clearer for '%"SVf"'", slot);
    }

    value = delete_slot(self, slot);
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}

XS(XS_Mouse_simple_predicate)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);

    if (items != 1) {
        croak("Expected exactly one argument for a predicate for '%"SVf"'", slot);
    }

    ST(0) = boolSV( has_slot(self, slot) );
    XSRETURN(1);
}

/* simple instance slot accessor (or Mouse::Meta::Instance) */

SV*
mouse_instance_create(pTHX_ HV* const stash) {
    assert(stash);
    assert(SvTYPE(stash) == SVt_PVHV);
    return sv_bless( newRV_noinc((SV*)newHV()), stash );
}

SV*
mouse_instance_clone(pTHX_ SV* const instance) {
    HV* proto;
    assert(instance);

    CHECK_INSTANCE(instance);
    proto = newHVhv((HV*)SvRV(instance));
    return sv_bless( newRV_noinc((SV*)proto), SvSTASH(SvRV(instance)) );
}

bool
mouse_instance_has_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_exists_ent((HV*)SvRV(instance), slot, 0U);
}

SV*
mouse_instance_get_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    return he ? HeVAL(he) : NULL;
}

SV*
mouse_instance_set_slot(pTHX_ SV* const instance, SV* const slot, SV* const value) {
    HE* he;
    SV* sv;
    assert(instance);
    assert(slot);
    assert(value);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, TRUE, 0U);
    sv = HeVAL(he);
    sv_setsv(sv, value);
    SvSETMAGIC(sv);
    return sv;
}

SV*
mouse_instance_delete_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_delete_ent((HV*)SvRV(instance), slot, 0, 0U);
}

void
mouse_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    if(he){
        sv_rvweaken(HeVAL(he));
    }
}

MODULE = Mouse::Meta::Method::Accessor::XS  PACKAGE = Mouse::Meta::Method::Accessor::XS

PROTOTYPES:   DISABLE
VERSIONCHECK: DISABLE

CV*
_generate_accessor(klass, SV* attr, metaclass)
CODE:
{
    RETVAL = mouse_accessor_generate(aTHX_ attr, XS_Mouse_accessor);
}
OUTPUT:
    RETVAL

CV*
_generate_reader(klass, SV* attr, metaclass)
CODE:
{
    RETVAL = mouse_accessor_generate(aTHX_ attr, XS_Mouse_reader);
}
OUTPUT:
    RETVAL

CV*
_generate_writer(klass, SV* attr, metaclass)
CODE:
{
    RETVAL = mouse_accessor_generate(aTHX_ attr, XS_Mouse_writer);
}
OUTPUT:
    RETVAL

CV*
_generate_clearer(klass, SV* attr, metaclass)
CODE:
{
    SV* const slot = mcall0s(attr, "name");
    STRLEN len;
    const char* const pv = SvPV_const(slot, len);
    RETVAL = mouse_simple_accessor_generate(aTHX_ NULL, pv, len, XS_Mouse_simple_clearer, NULL, 0);
}
OUTPUT:
    RETVAL

CV*
_generate_predicate(klass, SV* attr, metaclass)
CODE:
{
    SV* const slot = mcall0s(attr, "name");
    STRLEN len;
    const char* const pv = SvPV_const(slot, len);
    RETVAL = mouse_simple_accessor_generate(aTHX_ NULL, pv, len, XS_Mouse_simple_predicate, NULL, 0);
}
OUTPUT:
    RETVAL

