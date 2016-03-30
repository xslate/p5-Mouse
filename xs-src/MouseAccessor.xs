#include "mouse.h"

#define CHECK_INSTANCE(instance) STMT_START{                           \
        assert(instance);                                              \
        if(UNLIKELY(                                                   \
                !(SvROK(instance)                                      \
                && SvTYPE(SvRV(instance)) == SVt_PVHV) )){             \
            croak("Invalid object instance: '%"SVf"'", instance);      \
        }                                                              \
    } STMT_END


#define MOUSE_mg_attribute(mg) MOUSE_xa_attribute(MOUSE_mg_xa(mg))

static MGVTBL mouse_accessor_vtbl; /* MAGIC identity */

#define dMOUSE_self  SV* const self = mouse_accessor_get_self(aTHX_ ax, items, cv)

/* simple instance slot accessor (or Mouse::Meta::Instance) */

SV*
mouse_instance_create(pTHX_ HV* const stash) {
    SV* instance;
    assert(stash);
    assert(SvTYPE(stash) == SVt_PVHV);
    instance = sv_bless( newRV_noinc((SV*)newHV()), stash );
    return sv_2mortal(instance);
}

SV*
mouse_instance_clone(pTHX_ SV* const instance) {
    SV* proto;
    CHECK_INSTANCE(instance);
    assert(SvOBJECT(SvRV(instance)));

    proto = newRV_noinc((SV*)newHVhv((HV*)SvRV(instance)));
    sv_bless(proto, SvSTASH(SvRV(instance)));
    return sv_2mortal(proto);
}

bool
mouse_instance_has_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_exists_ent((HV*)SvRV(instance), slot, 0U);
}

SV*
mouse_instance_get_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    return he ? HeVAL(he) : NULL;
}

SV*
mouse_instance_set_slot(pTHX_ SV* const instance, SV* const slot, SV* const value) {
    HE* he;
    SV* sv;
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
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    if(he){
        SV* const value = HeVAL(he);
        if (SvROK(value) && !SvWEAKREF(value)) {
            sv_rvweaken(value);
        }
    }
}

/* utilities */

STATIC_INLINE SV*
mouse_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv) {
    if(UNLIKELY( items < 1 )){
        croak("Too few arguments for %s", GvNAME(CvGV(cv)));
    }
    /* NOTE: If self has GETMAGIC, $self->accessor will invoke GETMAGIC
     *       before calling methods, so SvGETMAGIC(self) is not required here.
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

    mg = sv_magicext((SV*)xsub, MOUSE_xa_slot(xa),
        PERL_MAGIC_ext, &mouse_accessor_vtbl, (char*)xa, HEf_SVKEY);

    MOUSE_mg_flags(mg) = (U16)MOUSE_xa_flags(xa);

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to
     * CvXSUBANY for efficiency (gfx)
     */
#ifndef MULTIPLICITY
    CvXSUBANY(xsub).any_ptr = (void*)mg;
#endif

    return xsub;
}


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
    else{
        HV* hv;
        HE* he;

        assert(flags & MOUSEf_TC_IS_HASHREF);

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

STATIC_INLINE void
mouse_push_value(pTHX_ SV* const value, U16 const flags) {
    if(flags & MOUSEf_ATTR_SHOULD_AUTO_DEREF && GIMME_V == G_ARRAY){
        mouse_push_values(aTHX_ value, flags);
    }
    else{
        dSP;
        XPUSHs(value ? value : &PL_sv_undef);
        PUTBACK;
    }
}

STATIC_INLINE void
mouse_attr_get(pTHX_ SV* const self, MAGIC* const mg){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* value;

    value = get_slot(self, MOUSE_mg_slot(mg));

    /* check_lazy */
    if( !value && flags & MOUSEf_ATTR_IS_LAZY ){
        value = mouse_xa_set_default(aTHX_ MOUSE_mg_xa(mg), self);
    }

    mouse_push_value(aTHX_ value, flags);
}

static void
mouse_attr_set(pTHX_ SV* const self, MAGIC* const mg, SV* value){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* const slot  = MOUSE_mg_slot(mg);
    SV* old_value;
    int has_old_value = 0;

    /* Store the original value before we change it so it can be
       passed to the trigger */
    if(flags & MOUSEf_ATTR_HAS_TRIGGER && has_slot(self, slot)){
        has_old_value = 1;
        old_value = sv_mortalcopy( get_slot(self, slot) );
    }

    if(flags & MOUSEf_ATTR_HAS_TC){
        value = mouse_xa_apply_type_constraint(aTHX_ MOUSE_mg_xa(mg), value, flags);
    }

    value = set_slot(self, slot, value);

    if(flags & MOUSEf_ATTR_IS_WEAK_REF){
        weaken_slot(self, slot);
    }

    if(flags & MOUSEf_ATTR_HAS_TRIGGER){
        SV* const trigger = mcall0s(MOUSE_mg_attribute(mg), "trigger");
        dSP;

        /* NOTE: triggers can remove value, so
                 value must be copied here,
                 revealed by Net::Google::DataAPI (DANJOU).
         */
        value = sv_mortalcopy(value);

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(self);
        PUSHs(value);
        if( has_old_value ) {
            EXTEND(SP, 1);
            PUSHs(old_value);
        }

        PUTBACK;
        call_sv_safe(trigger, G_VOID | G_DISCARD);
        /* need not SPAGAIN */

        /* wrong assert(SvFLAGS(value) > SVTYPEMASK); can be undef/SVt_NULL */
    }

    mouse_push_value(aTHX_ value, flags);
}

XS(XS_Mouse_accessor)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl);

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
            "Expected exactly one or two argument for an accessor of %"SVf,
            MOUSE_mg_slot(mg));
    }
}


XS(XS_Mouse_reader)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl);

    if (items != 1) {
        mouse_throw_error(MOUSE_mg_attribute(mg), NULL,
            "Cannot assign a value to a read-only accessor of %"SVf,
            MOUSE_mg_slot(mg));
    }

    SP -= items; /* PPCODE */
    PUTBACK;

    mouse_attr_get(aTHX_ self, mg);
}

XS(XS_Mouse_writer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl);

    if (items != 2) {
        mouse_throw_error(MOUSE_mg_attribute(mg), NULL,
            "Too few arguments for a write-only accessor of %"SVf,
            MOUSE_mg_slot(mg));
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
mouse_simple_accessor_generate(pTHX_
    const char* const fq_name, const char* const key, I32 const keylen,
    XSUBADDR_t const accessor_impl, void* const dptr, I32 const dlen) {
    CV* const xsub = newXS((char*)fq_name, accessor_impl, __FILE__);
    SV* const slot = newSVpvn_share(key, keylen, 0U);
    MAGIC* mg;

    if(!fq_name){
        /* anonymous xsubs need sv_2mortal() */
        sv_2mortal((SV*)xsub);
    }

    mg = sv_magicext((SV*)xsub, slot,
        PERL_MAGIC_ext, &mouse_accessor_vtbl, (char*)dptr, dlen);

    SvREFCNT_dec(slot); /* sv_magicext() increases refcnt in mg_obj */
    if(dlen == HEf_SVKEY){
        SvREFCNT_dec(dptr);
    }

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY
     * for efficiency (gfx)
     */
#ifndef MULTIPLICITY
    CvXSUBANY(xsub).any_ptr = (void*)mg;
#endif

    return xsub;
}

XS(XS_Mouse_simple_reader)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    MAGIC* const mg = MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl);
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a reader of %"SVf,
            MOUSE_mg_slot(mg));
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
    SV* const slot = MOUSE_mg_slot(MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl));

    if (items != 2) {
        croak("Expected exactly two argument for a writer of %"SVf,
            slot);
    }

    ST(0) = set_slot(self, slot, ST(1));
    XSRETURN(1);
}

XS(XS_Mouse_simple_clearer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot(MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl));
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a clearer of %"SVf,
            slot);
    }

    value = delete_slot(self, slot);
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}

XS(XS_Mouse_simple_predicate)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot(MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl));

    if (items != 1) {
        croak("Expected exactly one argument for a predicate of %"SVf, slot);
    }

    ST(0) = boolSV( has_slot(self, slot) );
    XSRETURN(1);
}

/* Class::Data::Inheritable-like class accessor */
XS(XS_Mouse_inheritable_class_accessor) {
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot(MOUSE_get_magic(aTHX_ cv, &mouse_accessor_vtbl));
    SV* value;
    HV* stash;

    if(items == 1){ /* reader */
        value = NULL;
    }
    else if (items == 2){ /* writer */
        value = ST(1);
    }
    else{
        croak("Expected exactly one or two argument for a class data accessor"
            "of %"SVf, slot);
        value = NULL; /* -Wuninitialized */
    }

    stash = mouse_get_namespace(aTHX_ self);

    if(!value) { /* reader */
        value = get_slot(self, slot);
        if(!value) {
            AV* const isa   = mro_get_linear_isa(stash);
            I32 const len   = av_len(isa) + 1;
            I32 i;
            for(i = 1; i < len; i++) {
                SV* const klass = MOUSE_av_at(isa, i);
                SV* const meta  = get_metaclass(klass);
                if(!SvOK(meta)){
                    continue; /* skip non-Mouse classes */
                }
                value = get_slot(meta, slot);
                if(value) {
                    break;
                }
            }
            if(!value) {
                value = &PL_sv_undef;
            }
        }
    }
    else { /* writer */
        set_slot(self, slot, value);
        mro_method_changed_in(stash);
    }

    ST(0) = value;
    XSRETURN(1);
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
    SV* const slot = mcall0(attr, mouse_name);
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
    SV* const slot = mcall0(attr, mouse_name);
    STRLEN len;
    const char* const pv = SvPV_const(slot, len);
    RETVAL = mouse_simple_accessor_generate(aTHX_ NULL, pv, len, XS_Mouse_simple_predicate, NULL, 0);
}
OUTPUT:
    RETVAL

