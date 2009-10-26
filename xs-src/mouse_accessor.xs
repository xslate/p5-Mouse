#include "mouse.h"

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

CV*
mouse_instantiate_xs_accessor(pTHX_ SV* const attr, XSUBADDR_t const accessor_impl){
    SV* const slot = mcall0s(attr,  "name");
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
                        mcall0s(tc, "name"));
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
        XS(XS_Mouse__Util__TypeConstraints_Item); /* prototype defined in Mouse.xs */

        tc_code = mcall0s(tc, "_compiled_type_constraint");

        if(SvROK(tc_code) && SvTYPE(SvRV(tc_code))
            && CvXSUB((CV*)SvRV(tc_code)) == XS_Mouse__Util__TypeConstraints_Item){
            /* built-in type constraints */
            mouse_tc const id = CvXSUBANY((CV*)SvRV(tc_code)).any_i32;
            av_store(xa, MOUSE_XA_TC_CODE, newSViv(id));
        }
        else{
            av_store(xa, MOUSE_XA_TC_CODE, newSVsv(tc_code));
        }
    }
    else{
        tc_code = MOUSE_xa_tc_code(xa);
    }

    if(!mouse_tc_check(aTHX_ tc_code, value)){
        mouse_throw_error(MOUSE_xa_attribute(xa), value,
            "Attribute (%"SVf") does not pass the type constraint because: %"SVf,
                mcall0s(MOUSE_xa_attribute(xa), "name"),
                mcall1s(tc, "get_message", value));
    }

    return value;
}


/* pushes return values, does auto-deref if needed */
static void
mouse_push_values(pTHX_ SV* const value, U16 const flags){
    dSP;

    if(flags & MOUSEf_ATTR_SHOULD_AUTO_DEREF && GIMME_V == G_ARRAY){
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
    }
    else{
        XPUSHs(value ? value : &PL_sv_undef);
    }

    PUTBACK;
}

static void
mouse_attr_get(pTHX_ SV* const self, MAGIC* const mg){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* const slot  = MOUSE_mg_slot(mg);
    SV* value;

    value = mouse_instance_get_slot(aTHX_ self, slot);

    /* check_lazy */
    if( !value && flags & MOUSEf_ATTR_IS_LAZY ){
        AV* const xa    = MOUSE_mg_xa(mg);
        SV* const attr = MOUSE_xa_attribute(xa);

        /* get default value by $attr->default or $attr->builder */
        if(flags & MOUSEf_ATTR_HAS_DEFAULT){
            value = mcall0s(attr, "default");

            if(SvROK(value) && SvTYPE(SvRV(value)) == SVt_PVCV){
                value = mcall0(self, value);
            }
        }
        else if(flags & MOUSEf_ATTR_HAS_BUILDER){
            SV* const builder = mcall0s(attr, "builder");
            value = mcall0(self, builder);
        }

        if(!value){
            value = sv_newmortal();
        }

        /* apply coerce and type constraint */
        if(flags & MOUSEf_ATTR_HAS_TC){
            value = mouse_apply_type_constraint(aTHX_ xa, value, flags);
        }

        /* store value to slot */
        value = mouse_instance_set_slot(aTHX_ self, slot, value);
    }

    mouse_push_values(aTHX_ value, flags);
}

static void
mouse_attr_set(pTHX_ SV* const self, MAGIC* const mg, SV* value){
    U16 const flags = MOUSE_mg_flags(mg);
    SV* const slot  = MOUSE_mg_slot(mg);

    if(flags & MOUSEf_ATTR_HAS_TC){
        value = mouse_apply_type_constraint(aTHX_ MOUSE_mg_xa(mg), value, flags);
    }

    mouse_instance_set_slot(aTHX_ self, slot, value);

    if(flags & MOUSEf_ATTR_IS_WEAK_REF){
        mouse_instance_weaken_slot(aTHX_ self, slot);
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

    mouse_push_values(aTHX_ value, flags);
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
