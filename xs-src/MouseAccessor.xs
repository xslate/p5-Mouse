#include "mouse.h"

#define CHECK_INSTANCE(instance) STMT_START{                          \
        if(!(SvROK(instance) && SvTYPE(SvRV(instance)) == SVt_PVHV)){ \
            croak("Invalid object instance");                         \
        }                                                             \
    } STMT_END

/* Moose XS Attribute object */
enum mouse_xa_ix_t{
    MOUSE_XA_ATTRIBUTE,
    MOUSE_XA_TC,
    MOUSE_XA_TC_CODE,

    MOUSE_XA_last
};

#define MOUSE_xa_attribute(m) MOUSE_av_at(m, MOUSE_XA_ATTRIBUTE)
#define MOUSE_xa_tc(m)        MOUSE_av_at(m, MOUSE_XA_TC)
#define MOUSE_xa_tc_code(m)   MOUSE_av_at(m, MOUSE_XA_TC_CODE)

#define MOUSE_mg_attribute(mg) MOUSE_xa_attribute(MOUSE_mg_xa(mg))

enum mouse_xa_flags_t{
    MOUSEf_ATTR_HAS_TC          = 0x0001,
    MOUSEf_ATTR_HAS_DEFAULT     = 0x0002,
    MOUSEf_ATTR_HAS_BUILDER     = 0x0004,
    MOUSEf_ATTR_HAS_INITIALIZER = 0x0008, /* not used in Mouse */
    MOUSEf_ATTR_HAS_TRIGGER     = 0x0010,

    MOUSEf_ATTR_IS_LAZY         = 0x0020,
    MOUSEf_ATTR_IS_WEAK_REF     = 0x0040,
    MOUSEf_ATTR_IS_REQUIRED     = 0x0080,

    MOUSEf_ATTR_SHOULD_COERCE   = 0x0100,

    MOUSEf_ATTR_SHOULD_AUTO_DEREF
                                = 0x0200,
    MOUSEf_TC_IS_ARRAYREF       = 0x0400,
    MOUSEf_TC_IS_HASHREF        = 0x0800,

    MOUSEf_OTHER1               = 0x1000,
    MOUSEf_OTHER2               = 0x2000,
    MOUSEf_OTHER3               = 0x4000,
    MOUSEf_OTHER4               = 0x8000,

    MOUSEf_MOUSE_MASK           = 0xFFFF /* not used */
};

static MGVTBL mouse_accessor_vtbl; /* MAGIC identity */


SV*
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
mouse_instantiate_xs_accessor(pTHX_ SV* const attr, XSUBADDR_t const accessor_impl){
    SV* const slot = mcall0(attr,  mouse_name);
    AV* const xa = newAV();
    CV* xsub;
    MAGIC* mg;
    U16 flags = 0;

    sv_2mortal((SV*)xa);

    xsub = newXS(NULL, accessor_impl, __FILE__);
    sv_2mortal((SV*)xsub);

    mg = sv_magicext((SV*)xsub, slot, PERL_MAGIC_ext, &mouse_accessor_vtbl, (char*)xa, HEf_SVKEY);

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    av_extend(xa, MOUSE_XA_last - 1);

    av_store(xa, MOUSE_XA_ATTRIBUTE, newSVsv(attr));

    /* prepare attribute status */
    /* XXX: making it lazy is a good way? */

    if(SvTRUEx(mcall0s(attr, "has_type_constraint"))){
        SV* tc;
        flags |= MOUSEf_ATTR_HAS_TC;

        ENTER;
        SAVETMPS;

        tc = mcall0s(attr, "type_constraint");
        av_store(xa, MOUSE_XA_TC, newSVsv(tc));

        if(SvTRUEx(mcall0s(attr, "should_auto_deref"))){
            flags |= MOUSEf_ATTR_SHOULD_AUTO_DEREF;
            if( SvTRUEx(mcall1s(tc, "is_a_type_of", newSVpvs_flags("ArrayRef", SVs_TEMP))) ){
                flags |= MOUSEf_TC_IS_ARRAYREF;
            }
            else if( SvTRUEx(mcall1s(tc, "is_a_type_of", newSVpvs_flags("HashRef", SVs_TEMP))) ){
                flags |= MOUSEf_TC_IS_HASHREF;
            }
            else{
                mouse_throw_error(attr, tc,
                    "Can not auto de-reference the type constraint '%"SVf"'",
                        mcall0(tc, mouse_name));
            }
        }

        if(SvTRUEx(mcall0s(attr, "should_coerce"))){
            flags |= MOUSEf_ATTR_SHOULD_COERCE;
        }

        FREETMPS;
        LEAVE;
    }

    if(SvTRUEx(mcall0s(attr, "has_trigger"))){
        flags |= MOUSEf_ATTR_HAS_TRIGGER;
    }

    if(SvTRUEx(mcall0s(attr, "is_lazy"))){
        flags |= MOUSEf_ATTR_IS_LAZY;

        if(SvTRUEx(mcall0s(attr, "has_builder"))){
            flags |= MOUSEf_ATTR_HAS_BUILDER;
        }
        else if(SvTRUEx(mcall0s(attr, "has_default"))){
            flags |= MOUSEf_ATTR_HAS_DEFAULT;
        }
    }

    if(SvTRUEx(mcall0s(attr, "is_weak_ref"))){
        flags |= MOUSEf_ATTR_IS_WEAK_REF;
    }

    if(SvTRUEx(mcall0s(attr, "is_required"))){
        flags |= MOUSEf_ATTR_IS_REQUIRED;
    }

    MOUSE_mg_flags(mg) = flags;

    return xsub;
}

static SV*
mouse_apply_type_constraint(pTHX_ AV* const xa, SV* value, U16 const flags){
    SV* const tc = MOUSE_xa_tc(xa);
    SV* tc_code;

    if(flags & MOUSEf_ATTR_SHOULD_COERCE){
          value = mcall1s(tc, "coerce", value);
    }

    if(!SvOK(MOUSE_xa_tc_code(xa))){
        tc_code = mcall0s(tc, "_compiled_type_constraint");
        av_store(xa, MOUSE_XA_TC_CODE, newSVsv(tc_code));

        if(!(SvROK(tc_code) && SvTYPE(SvRV(tc_code)) == SVt_PVCV)){
            mouse_throw_error(MOUSE_xa_attribute(xa), tc, "Not a CODE reference");
        }
    }
    else{
        tc_code = MOUSE_xa_tc_code(xa);
    }

    if(!mouse_tc_check(aTHX_ tc_code, value)){
        mouse_throw_error(MOUSE_xa_attribute(xa), value,
            "Attribute (%"SVf") does not pass the type constraint because: %"SVf,
                mcall0(MOUSE_xa_attribute(xa), mouse_name),
                mcall1s(tc, "get_message", value));
    }

    return value;
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
        AV* const av = (AV*)SvRV(value);
        I32 len;
        I32 i;

        if(SvTYPE(av) != SVt_PVAV){
            croak("Mouse-panic: Not an ARRAY reference");
        }

        len = av_len(av) + 1;
        EXTEND(SP, len);
        for(i = 0; i < len; i++){
            SV** const svp = av_fetch(av, i, FALSE);
            PUSHs(svp ? *svp : &PL_sv_undef);
        }
    }
    else if(flags & MOUSEf_TC_IS_HASHREF){
        HV* const hv = (HV*)SvRV(value);
        HE* he;

        if(SvTYPE(hv) != SVt_PVHV){
            croak("Mouse-panic: Not a HASH reference");
        }

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
    SV* const slot  = MOUSE_mg_slot(mg);
    SV* value;

    value = get_slot(self, slot);

    /* check_lazy */
    if( !value && flags & MOUSEf_ATTR_IS_LAZY ){
        AV* const xa   = MOUSE_mg_xa(mg);
        SV* const attr = MOUSE_xa_attribute(xa);

        /* get default value by $attr->builder or $attr->default */
        if(flags & MOUSEf_ATTR_HAS_BUILDER){
            SV* const builder = mcall0s(attr, "builder");
            value = mcall0(self, builder);
        }
        else {
            value = mcall0s(attr, "default");

            if(SvROK(value) && SvTYPE(SvRV(value)) == SVt_PVCV){
                value = mcall0(self, value);
            }
        }

        /* apply coerce and type constraint */
        if(flags & MOUSEf_ATTR_HAS_TC){
            value = mouse_apply_type_constraint(aTHX_ xa, value, flags);
        }

        /* store value to slot */
        value = set_slot(self, slot, value);
    }

    PUSH_VALUE(value, flags);
}

static void
mouse_attr_set(pTHX_ SV* const self, MAGIC* const mg, SV* value){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* const slot  = MOUSE_mg_slot(mg);

    if(flags & MOUSEf_ATTR_HAS_TC){
        value = mouse_apply_type_constraint(aTHX_ MOUSE_mg_xa(mg), value, flags);
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

XS(mouse_xs_accessor)
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


XS(mouse_xs_reader)
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

XS(mouse_xs_writer)
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
mouse_install_simple_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl){
    CV* const xsub = newXS((char*)fq_name, accessor_impl, __FILE__);
    SV* const slot = newSVpvn_share(key, keylen, 0U);
    MAGIC* mg;

    if(!fq_name){
        /* anonymous xsubs need sv_2mortal */
        sv_2mortal((SV*)xsub);
    }

    mg = sv_magicext((SV*)xsub, slot, PERL_MAGIC_ext, &mouse_accessor_vtbl, NULL, 0);
    SvREFCNT_dec(slot); /* sv_magicext() increases refcnt in mg_obj */

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}

XS(mouse_xs_simple_reader)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a reader for '%"SVf"'", slot);
    }

    value = get_slot(self, slot);
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}


XS(mouse_xs_simple_writer)
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

XS(mouse_xs_simple_clearer)
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

XS(mouse_xs_simple_predicate)
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
    sv_setsv_mg(sv, value);
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
    RETVAL = mouse_instantiate_xs_accessor(aTHX_ attr, mouse_xs_accessor);
}
OUTPUT:
    RETVAL

CV*
_generate_reader(klass, SV* attr, metaclass)
CODE:
{
    RETVAL = mouse_instantiate_xs_accessor(aTHX_ attr, mouse_xs_reader);
}
OUTPUT:
    RETVAL

CV*
_generate_writer(klass, SV* attr, metaclass)
CODE:
{
    RETVAL = mouse_instantiate_xs_accessor(aTHX_ attr, mouse_xs_writer);
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
    RETVAL = mouse_install_simple_accessor(aTHX_ NULL, pv, len, mouse_xs_simple_clearer);
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
    RETVAL = mouse_install_simple_accessor(aTHX_ NULL, pv, len, mouse_xs_simple_predicate);
}
OUTPUT:
    RETVAL

