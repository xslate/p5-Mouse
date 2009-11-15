#include "mouse.h"


AV*
mouse_get_xa(pTHX_ SV* const attr) {
    static MGVTBL mouse_xa_vtbl; /* identity */

    AV* xa;
    MAGIC* mg;

    if(!IsObject(attr)){
        croak("Not a Mouse meta attribute");
    }

    mg = mouse_mg_find(aTHX_ SvRV(attr), &mouse_xa_vtbl, 0x00);
    if(!mg){
        SV* slot;
        STRLEN len;
        const char* pv;
        U16 flags = 0x00;

        ENTER;
        SAVETMPS;

        xa    = newAV();

        mg = sv_magicext(SvRV(attr), (SV*)xa, PERL_MAGIC_ext, &mouse_xa_vtbl,NULL, 0);
        SvREFCNT_dec(xa); /* refcnt++ in sv_magicext */

        av_extend(xa, MOUSE_XA_last - 1);

        slot = mcall0(attr, mouse_name);
        pv = SvPV_const(slot, len);
        av_store(xa, MOUSE_XA_SLOT, newSVpvn_share(pv, len, 0U));

        av_store(xa, MOUSE_XA_ATTRIBUTE, newSVsv(attr));

        av_store(xa, MOUSE_XA_INIT_ARG, newSVsv(mcall0s(attr, "init_arg")));

        if(predicate_calls(attr, "has_type_constraint")){
            SV* tc;
            flags |= MOUSEf_ATTR_HAS_TC;

            tc = mcall0s(attr, "type_constraint");
            av_store(xa, MOUSE_XA_TC, newSVsv(tc));

            if(predicate_calls(attr, "should_auto_deref")){
                SV* const is_a_type_of = sv_2mortal(newSVpvs_share("is_a_type_of"));

                flags |= MOUSEf_ATTR_SHOULD_AUTO_DEREF;
                if( SvTRUEx(mcall1(tc, is_a_type_of, newSVpvs_flags("ArrayRef", SVs_TEMP))) ){
                    flags |= MOUSEf_TC_IS_ARRAYREF;
                }
                else if( SvTRUEx(mcall1(tc, is_a_type_of, newSVpvs_flags("HashRef", SVs_TEMP))) ){
                    flags |= MOUSEf_TC_IS_HASHREF;
                }
                else{
                    mouse_throw_error(attr, tc,
                        "Can not auto de-reference the type constraint '%"SVf"'",
                            mcall0(tc, mouse_name));
                }
            }

            if(predicate_calls(attr, "should_coerce")){
                flags |= MOUSEf_ATTR_SHOULD_COERCE;
            }

        }

        if(predicate_calls(attr, "has_trigger")){
            flags |= MOUSEf_ATTR_HAS_TRIGGER;
        }

        if(predicate_calls(attr, "is_lazy")){
            flags |= MOUSEf_ATTR_IS_LAZY;
        }
        if(predicate_calls(attr, "has_builder")){
            flags |= MOUSEf_ATTR_HAS_BUILDER;
        }
        else if(predicate_calls(attr, "has_default")){
            flags |= MOUSEf_ATTR_HAS_DEFAULT;
        }

        if(predicate_calls(attr, "is_weak_ref")){
            flags |= MOUSEf_ATTR_IS_WEAK_REF;
        }

        if(predicate_calls(attr, "is_required")){
            flags |= MOUSEf_ATTR_IS_REQUIRED;
        }

        av_store(xa, MOUSE_XA_FLAGS, newSVuv(flags));
        MOUSE_mg_flags(mg) = flags;

        FREETMPS;
        LEAVE;
    }
    else{
        xa    = (AV*)MOUSE_mg_obj(mg);

        assert(xa);
        assert(SvTYPE(xa) == SVt_PVAV);
    }

    return xa;
}

SV*
mouse_xa_apply_type_constraint(pTHX_ AV* const xa, SV* value, U16 const flags){
    SV* const tc = MOUSE_xa_tc(xa);
    SV* tc_code;

    if(flags & MOUSEf_ATTR_SHOULD_COERCE){
          value = mcall1s(tc, "coerce", value);
    }

    if(!SvOK(MOUSE_xa_tc_code(xa))){
        tc_code = mcall0s(tc, "_compiled_type_constraint");
        av_store(xa, MOUSE_XA_TC_CODE, newSVsv(tc_code));

        if(!IsCodeRef(tc_code)){
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


SV*
mouse_xa_set_default(pTHX_ AV* const xa, SV* const object) {
    U16 const flags = (U16)MOUSE_xa_flags(xa);
    SV* value;

    /* get default value by $attr->builder or $attr->default */
    if(flags & MOUSEf_ATTR_HAS_BUILDER){
        SV* const builder = mcall0s(MOUSE_xa_attribute(xa), "builder");
        value = mcall0(object, builder); /* $object->$builder() */
    }
    else {
        value = mcall0s(MOUSE_xa_attribute(xa), "default");

        if(IsCodeRef(value)){
            value = mcall0(object, value);
        }
    }

    /* apply coerce and type constraint */
    if(flags & MOUSEf_ATTR_HAS_TC){
        value = mouse_xa_apply_type_constraint(aTHX_ xa, value, flags);
    }

    /* store value to slot */
    value = set_slot(object, MOUSE_xa_slot(xa), value);

    if(flags & MOUSEf_ATTR_IS_WEAK_REF && SvROK(value)){
        weaken_slot(object, MOUSE_xa_slot(xa));
    }

    return value;
}

MODULE = Mouse::Meta::Attribute  PACKAGE = Mouse::Meta::Attribute

PROTOTYPES: DISABLE

BOOT:
    /* readers */
    INSTALL_SIMPLE_READER(Attribute, name);
    INSTALL_SIMPLE_READER(Attribute, associated_class);
    INSTALL_SIMPLE_READER(Attribute, accessor);
    INSTALL_SIMPLE_READER(Attribute, reader);
    INSTALL_SIMPLE_READER(Attribute, writer);
    INSTALL_SIMPLE_READER(Attribute, predicate);
    INSTALL_SIMPLE_READER(Attribute, clearer);
    INSTALL_SIMPLE_READER(Attribute, handles);

    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, _is_metadata, is);
    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, is_required, required);
    INSTALL_SIMPLE_READER(Attribute, default);
    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, is_lazy, lazy);
    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, is_lazy_build, lazy_build);
    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, is_weak_ref, weak_ref);
    INSTALL_SIMPLE_READER(Attribute, init_arg);
    INSTALL_SIMPLE_READER(Attribute, type_constraint);
    INSTALL_SIMPLE_READER(Attribute, trigger);
    INSTALL_SIMPLE_READER(Attribute, builder);
    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, should_auto_deref, auto_deref);
    INSTALL_SIMPLE_READER_WITH_KEY(Attribute, should_coerce, coerce);
    INSTALL_SIMPLE_READER(Attribute, documentation);

    /* predicates */
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_accessor, accessor);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_reader, reader);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_writer, writer);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_predicate, predicate);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_clearer, clearer);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_handles, handles);

    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_default, default);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_type_constraint, type_constraint);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_trigger, trigger);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_builder, builder);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Attribute, has_documentation, documentation);

    newCONSTSUB(gv_stashpvs("Mouse::Meta::Attribute", TRUE), "accessor_metaclass",
        newSVpvs("Mouse::Meta::Method::Accessor::XS"));

