#include "mouse.h"

static MGVTBL mouse_xa_vtbl; /* identity */

static AV*
mouse_build_xa(pTHX_ SV* const attr) {
    AV*    xa;
    MAGIC* mg;

    SV* slot;
    STRLEN len;
    const char* pv;
    U16 flags = 0x00;

    ENTER;
    SAVETMPS;

    xa = newAV();

    mg = sv_magicext(SvRV(attr), (SV*)xa, PERL_MAGIC_ext, &mouse_xa_vtbl, NULL, 0);
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
            if( sv_true(mcall1(tc, is_a_type_of, newSVpvs_flags("ArrayRef", SVs_TEMP))) ){
                flags |= MOUSEf_TC_IS_ARRAYREF;
            }
            else if( sv_true(mcall1(tc, is_a_type_of, newSVpvs_flags("HashRef", SVs_TEMP))) ){
                flags |= MOUSEf_TC_IS_HASHREF;
            }
            else{
                mouse_throw_error(attr, tc,
                    "Can not auto de-reference the type constraint '%"SVf"'",
                        mcall0(tc, mouse_name));
            }
        }

        if(predicate_calls(attr, "should_coerce") && predicate_calls(tc, "has_coercion")){
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

    return xa;
}

AV*
mouse_get_xa(pTHX_ SV* const attr) {
    AV*    xa;
    MAGIC* mg;

    if(!IsObject(attr)){
        croak("Not a Mouse meta attribute");
    }

    mg = mouse_mg_find(aTHX_ SvRV(attr), &mouse_xa_vtbl, 0x00);
    if(!mg){
        xa = mouse_build_xa(aTHX_ attr);
    }
    else{
        xa = (AV*)MOUSE_mg_obj(mg);

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
          value = mcall1(tc, mouse_coerce, value);
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

    ENTER;
    SAVETMPS;

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

    if(flags & MOUSEf_ATTR_IS_WEAK_REF){
        weaken_slot(object, MOUSE_xa_slot(xa));
    }

    FREETMPS;
    LEAVE;

    return value;
}

/* checks $isa->does($does) */
static void
mouse_check_isa_does_does(pTHX_ SV* const klass, SV* const name, SV* const isa, SV* const does){
    STRLEN len;
    const char* const pv = SvPV_const(isa, len); /* need strigify */
    bool does_ok;
    dSP;

    ENTER;
    SAVETMPS;

    SAVESPTR(ERRSV);
    ERRSV = sv_newmortal();

    PUSHMARK(SP);
    EXTEND(SP, 2);
    mPUSHp(pv, len);
    PUSHs(does);
    PUTBACK;

    call_method("does", G_EVAL | G_SCALAR);

    SPAGAIN;
    does_ok = sv_true(POPs);
    PUTBACK;

    FREETMPS;
    LEAVE;

    if(!does_ok){
        mouse_throw_error(klass, NULL,
            "Cannot have both an isa option and a does option"
            "because '%"SVf"' does not do '%"SVf"' on attribute (%"SVf")",
            isa, does, name
        );
    }
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
    INSTALL_SIMPLE_READER(Attribute, insertion_order);

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

    INSTALL_CLASS_HOLDER(Attribute, accessor_metaclass, "Mouse::Meta::Method::Accessor::XS");

void
_process_options(SV* klass, SV* name, HV* args)
CODE:
{
    /* TODO: initialize 'xa' here */
    SV** svp;
    SV* tc = NULL;

    /* 'required' requires eigher 'init_arg', 'builder', or 'default' */
    bool can_be_required = FALSE;
    bool has_default     = FALSE;
    bool has_builder     = FALSE;

    /* taken from Class::MOP::Attribute::new */

    must_defined(name, "an attribute name");

    svp = hv_fetchs(args, "init_arg", FALSE);
    if(!svp){
        (void)hv_stores(args, "init_arg", newSVsv(name));
        can_be_required = TRUE;
    }
    else{
        can_be_required = SvOK(*svp) ? TRUE : FALSE;
    }

    svp = hv_fetchs(args, "builder", FALSE);
    if(svp){
        if(!SvOK(*svp)){
            mouse_throw_error(klass, *svp,
                "builder must be a defined scalar value which is a method name");
        }
        can_be_required = TRUE;
        has_builder     = TRUE;
    }
    else if((svp = hv_fetchs(args, "default", FALSE))){
        if(SvROK(*svp) && SvTYPE(SvRV(*svp)) != SVt_PVCV) {
            mouse_throw_error(klass, *svp,
               "References are not allowed as default values, you must "
                "wrap the default of '%"SVf"' in a CODE reference "
                "(ex: sub { [] } and not [])", name);
        }
        can_be_required = TRUE;
        has_default     = TRUE;
    }

    svp = hv_fetchs(args, "required", FALSE);
    if( (svp && sv_true(*svp)) && !can_be_required){
        mouse_throw_error(klass, NULL,
            "You cannot have a required attribute (%"SVf") "
            "without a default, builder, or an init_arg", name);
    }

    /* taken from Mouse::Meta::Attribute->new and ->_process_args */

    svp = hv_fetchs(args, "is", FALSE);
    if(svp){
        const char* const is = SvOK(*svp) ? SvPV_nolen_const(*svp) : "undef";
        if(strEQ(is, "ro")){
            svp = hv_fetchs(args, "reader", TRUE);
            if(!sv_true(*svp)){
                sv_setsv(*svp, name);
            }
        }
        else if(strEQ(is, "rw")){
            if(hv_fetchs(args, "writer", FALSE)){
                svp = hv_fetchs(args, "reader", TRUE);
            }
            else{
                svp = hv_fetchs(args, "accessor", TRUE);
            }
            if(!SvOK(*svp)) {
                sv_setsv(*svp, name);
            }
        }
        else if(strEQ(is, "bare")){
            /* do nothing, but might complain later about missing methods */
        }
        else{
            mouse_throw_error(klass, NULL,
                "I do not understand this option (is => %s) on attribute (%"SVf")",
                is, name);
        }
    }

    svp = hv_fetchs(args, "isa", FALSE);
    if(svp){
        SPAGAIN;
        PUSHMARK(SP);
        XPUSHs(*svp);
        PUTBACK;

        call_pv("Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint",
            G_SCALAR);
        SPAGAIN;
        tc = newSVsv(POPs);
        PUTBACK;
    }

    if((svp = hv_fetchs(args, "does", FALSE))){
        /* check 'isa' does 'does' */
        if(tc){
            mouse_check_isa_does_does(aTHX_ klass, name, tc, *svp);
            /* nothing to do */
        }
        else{
            SPAGAIN;
            PUSHMARK(SP);
            XPUSHs(*svp);
            PUTBACK;

            call_pv("Mouse::Util::TypeConstraints::find_or_create_does_type_constraint",
                G_SCALAR);
            SPAGAIN;
            tc = newSVsv(POPs);
            PUTBACK;
        }
    }
    if(tc){
        (void)hv_stores(args, "type_constraint", tc);
    }

    svp = hv_fetchs(args, "coerce", FALSE);
    if(svp){
        if(!tc){
            mouse_throw_error(klass, NULL,
                "You cannot have coercion without specifying a type constraint "
                "on attribute (%"SVf")", name);
        }
        svp = hv_fetchs(args, "weak_ref", FALSE);
        if(svp && sv_true(*svp)){
            mouse_throw_error(klass, NULL,
                "You cannot have a weak reference to a coerced value on "
                "attribute (%"SVf")", name);
        }
    }

    svp = hv_fetchs(args, "lazy_build", FALSE);
    if(svp){
        SV* clearer;
        SV* predicate;
        if(has_default){
            mouse_throw_error(klass, NULL,
                "You can not use lazy_build and default for the same "
                "attribute (%"SVf")", name);
        }

        svp = hv_fetchs(args, "lazy", TRUE);
        sv_setiv(*svp, TRUE);

        svp = hv_fetchs(args, "builder", TRUE);
        if(!sv_true(*svp)){
            sv_setpvf(*svp, "_build_%"SVf, name);
        }
        has_builder = TRUE;

        clearer   = *hv_fetchs(args, "clearer",   TRUE);
        predicate = *hv_fetchs(args, "predicate", TRUE);

        if(SvPV_nolen_const(name)[0] == '_'){
            if(!sv_true(clearer)){
                sv_setpvf(clearer, "_clear%"SVf, name);
            }
            if(!sv_true(predicate)){
                sv_setpvf(predicate, "_has%"SVf, name);
            }
        }
        else{
            if(!sv_true(clearer)){
                sv_setpvf(clearer, "clear_%"SVf, name);
            }
            if(!sv_true(predicate)){
                sv_setpvf(predicate, "has_%"SVf, name);
            }
        }
    }

    svp = hv_fetchs(args, "auto_deref", FALSE);
    if(svp && sv_true(*svp)){
        SV* const meth = sv_2mortal(newSVpvs_share("is_a_type_of"));
        if(!tc){
            mouse_throw_error(klass, NULL,
                "You cannot auto-dereference without specifying a type "
                "constraint on attribute (%"SVf")", name);
        }

        if(!(sv_true(mcall1(tc, meth, newSVpvs_flags("ArrayRef", SVs_TEMP)))
            || sv_true(mcall1(tc, meth, newSVpvs_flags("HashRef", SVs_TEMP))) )){
            mouse_throw_error(klass, NULL,
                "You cannot auto-dereference anything other than a ArrayRef "
                "or HashRef on attribute (%"SVf")", name);
        }
    }

    svp = hv_fetchs(args, "trigger", FALSE);
    if(svp){
        if(!IsCodeRef(*svp)){
            mouse_throw_error(klass, NULL,
                "Trigger must be a CODE ref on attribute (%"SVf")",
                name);
        }
    }


    svp = hv_fetchs(args, "lazy", FALSE);
    if(svp && sv_true(*svp)){
        if(!(has_default || has_builder)){
            mouse_throw_error(klass, NULL,
                "You cannot have a lazy attribute (%"SVf") without specifying "
                "a default value for it", name);
        }
    }
}

void
default(SV* self, SV* instance = NULL)
PPCODE:
{
    SV* value = get_slot(self, sv_2mortal(newSVpvs_share("default")));
    if(! value) {
        value = &PL_sv_undef;
    }
    else if (instance != NULL && IsCodeRef(value)) {
        PUSHMARK(SP);
        XPUSHs(instance);
        PUTBACK;
        call_sv_safe(value, G_SCALAR);
        SPAGAIN;
        value = POPs;
        PUTBACK;
    }
    ST(0) = value;
    XSRETURN(1);
}

