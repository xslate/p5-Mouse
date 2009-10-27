#include "mouse.h"

SV* mouse_package;
SV* mouse_namespace;
SV* mouse_methods;
SV* mouse_name;

MODULE = Mouse  PACKAGE = Mouse::Util

PROTOTYPES: DISABLE

BOOT:
    mouse_package   = newSVpvs_share("package");
    mouse_namespace = newSVpvs_share("namespace");
    mouse_methods   = newSVpvs_share("methods");
    mouse_name      = newSVpvs_share("name");

    MOUSE_CALL_BOOT(Mouse__Util__TypeConstraints);


bool
is_class_loaded(SV* sv = &PL_sv_undef)

void
get_code_info(CV* code)
PREINIT:
    GV* gv;
    HV* stash;
PPCODE:
    if((gv = CvGV(code)) && isGV(gv) && (stash = GvSTASH(gv))){
        EXTEND(SP, 2);
        mPUSHs(newSVpvn_share(HvNAME_get(stash), HvNAMELEN_get(stash), 0U));
        mPUSHs(newSVpvn_share(GvNAME_get(gv), GvNAMELEN_get(gv), 0U));
    }

SV*
get_code_package(CV* code)
PREINIT:
    HV* stash;
CODE:
    if(CvGV(code) && isGV(CvGV(code)) && (stash = GvSTASH(CvGV(code)))){
        RETVAL = newSVpvn_share(HvNAME_get(stash), HvNAMELEN_get(stash), 0U);
    }
    else{
        RETVAL = &PL_sv_no;
    }
OUTPUT:
    RETVAL

CV*
get_code_ref(SV* package, SV* name)
CODE:
{
    HV* stash;
    HE* he;

    if(!SvOK(package)){
        croak("You must define a package name");
    }
    if(!SvOK(name)){
        croak("You must define a subroutine name");
    }

    stash = gv_stashsv(package, FALSE);
    if(!stash){
        XSRETURN_UNDEF;
    }
    he = hv_fetch_ent(stash, name, FALSE, 0U);
    if(he){
        GV* const gv = (GV*)hv_iterval(stash, he);
        if(!isGV(gv)){ /* special constant or stub */
            STRLEN len;
            const char* const pv = SvPV_const(name, len);
            gv_init(gv, stash, pv, len, GV_ADDMULTI);
        }
        RETVAL = GvCVu(gv);
    }
    else{
        RETVAL = NULL;
    }

    if(!RETVAL){
        XSRETURN_UNDEF;
    }
}
OUTPUT:
    RETVAL


MODULE = Mouse  PACKAGE = Mouse::Meta::Module

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Module, name, package);
    INSTALL_SIMPLE_READER_WITH_KEY(Module, _method_map, methods);
    INSTALL_SIMPLE_READER_WITH_KEY(Module, _attribute_map, attributes);

HV*
namespace(SV* self)
CODE:
{
    SV* const package = mouse_instance_get_slot(aTHX_ self, mouse_package);
    if(!(package && SvOK(package))){
        croak("No package name defined");
    }
    RETVAL = gv_stashsv(package, GV_ADDMULTI);
}
OUTPUT:
    RETVAL

# ignore extra arguments for extensibility
void
add_method(SV* self, SV* name, SV* code, ...)
CODE:
{
    SV* const package = mouse_instance_get_slot(aTHX_ self, mouse_package); /* $self->{package} */
    SV* const methods = mouse_instance_get_slot(aTHX_ self, mouse_methods); /* $self->{methods} */
    GV* gv;
    SV* code_ref;

    if(!(package && SvOK(package))){
        croak("No package name defined");
    }

    SvGETMAGIC(name);
    SvGETMAGIC(code);

    if(!SvOK(name)){
        mouse_throw_error(self, NULL, "You must define a method name");
    }
    if(!SvROK(code)){
        mouse_throw_error(self, NULL, "You must define a CODE reference");
    }

    code_ref = code;
    if(SvTYPE(SvRV(code_ref)) != SVt_PVCV){
        SV*  sv = code_ref;  /* used in tryAMAGICunDEREF */
        SV** sp = &sv;       /* used in tryAMAGICunDEREF */
        tryAMAGICunDEREF(to_cv); /* try \&{$code} */
        if(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV){
            mouse_throw_error(self, NULL, "Not a CODE reference");
        }
        code_ref = sv;
    }

    /*  *{$package . '::' . $name} -> *gv */
    gv = gv_fetchpv(form("%"SVf"::%"SVf, package, name), GV_ADDMULTI, SVt_PVCV);
    if(GvCVu(gv)){ /* delete *slot{gv} to work around "redefine" warning */
        SvREFCNT_dec(GvCV(gv));
        GvCV(gv) = NULL;
    }
    sv_setsv_mg((SV*)gv, code_ref); /* *gv = $code_ref */

    mouse_instance_set_slot(aTHX_ methods, name, code); /* $self->{methods}{$name} = $code */

    /* TODO: name the CODE ref if it's anonymous */
    //code_entity = (CV*)SvRV(code_ref);
    //if(CvANON(code_entity)
    //    && CvGV(code_entity) /* a cv under construction has no gv */ ){

    //    CvGV(code_entity) = gv;
    //    CvANON_off(code_entity);
    //}
}

MODULE = Mouse  PACKAGE = Mouse::Meta::Class

BOOT:
    INSTALL_SIMPLE_READER(Class, roles);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Class, is_anon_class, anon_serial_id);

void
linearized_isa(SV* self)
PPCODE:
{
    SV* const stash_ref = mcall0(self, mouse_namespace); /* $self->namespace */
    AV* linearized_isa;
    I32 len;
    I32 i;
    if(!(SvROK(stash_ref) && SvTYPE(SvRV(stash_ref)) == SVt_PVHV)){
        croak("namespace() didn't return a HASH reference");
    }
    linearized_isa = mro_get_linear_isa((HV*)SvRV(stash_ref));
    len = AvFILLp(linearized_isa) + 1;
    EXTEND(SP, len);
    for(i = 0; i < len; i++){
        PUSHs(AvARRAY(linearized_isa)[i]);
    }
}

MODULE = Mouse  PACKAGE = Mouse::Meta::Role

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Role, get_roles, roles);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Role, is_anon_role, anon_serial_id);

MODULE = Mouse  PACKAGE = Mouse::Meta::Attribute

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

MODULE = Mouse  PACKAGE = Mouse::Meta::TypeConstraint

BOOT:
    INSTALL_SIMPLE_READER(TypeConstraint, name);
    INSTALL_SIMPLE_READER(TypeConstraint, parent);
    INSTALL_SIMPLE_READER(TypeConstraint, message);

    INSTALL_SIMPLE_READER_WITH_KEY(TypeConstraint, _compiled_type_constraint, compiled_type_constraint);
    INSTALL_SIMPLE_READER(TypeConstraint, _compiled_type_coercion); /* Mouse specific */

    INSTALL_SIMPLE_PREDICATE_WITH_KEY(TypeConstraint, has_coercion, _compiled_type_coercion);


MODULE = Mouse  PACKAGE = Mouse::Meta::Method::Accessor::XS

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

