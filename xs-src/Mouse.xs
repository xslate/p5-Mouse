#include "mouse.h"

SV* mouse_package;
SV* mouse_namespace;
SV* mouse_methods;
SV* mouse_name;

MODULE = Mouse  PACKAGE = Mouse

PROTOTYPES: DISABLE

BOOT:
    mouse_package   = newSVpvs_share("package");
    mouse_namespace = newSVpvs_share("namespace");
    mouse_methods   = newSVpvs_share("methods");
    mouse_name      = newSVpvs_share("name");

    MOUSE_CALL_BOOT(Mouse__Util);
    MOUSE_CALL_BOOT(Mouse__Util__TypeConstraints);
    MOUSE_CALL_BOOT(Mouse__Meta__Method__Accessor__XS);


MODULE = Mouse  PACKAGE = Mouse::Meta::Module

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Module, name, package);
    INSTALL_SIMPLE_READER_WITH_KEY(Module, _method_map, methods);
    INSTALL_SIMPLE_READER_WITH_KEY(Module, _attribute_map, attributes);

HV*
namespace(SV* self)
CODE:
{
    SV* const package = get_slot(self, mouse_package);
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
    SV* const package = get_slot(self, mouse_package); /* $self->{package} */
    SV* const methods = get_slot(self, mouse_methods); /* $self->{methods} */
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

    set_slot(methods, name, code); /* $self->{methods}{$name} = $code */

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


