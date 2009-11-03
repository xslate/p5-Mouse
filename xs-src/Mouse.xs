#define  NEED_newSVpvn_flags_GLOBAL
#include "mouse.h"

SV* mouse_package;
SV* mouse_namespace;
SV* mouse_methods;
SV* mouse_name;

static SV* mouse_all_attrs_cache;
static SV* mouse_all_attrs_cache_gen;

AV*
mouse_get_all_attributes(pTHX_ SV* const metaclass){
    SV* const package = get_slot(metaclass, mouse_package);
    HV* const stash   = gv_stashsv(package, TRUE);
    UV const pkg_gen  = mro_get_pkg_gen(stash);
    SV* cache_gen     = get_slot(metaclass, mouse_all_attrs_cache_gen);

    if(!(cache_gen && pkg_gen == SvUV(cache_gen))){ /* update */
        CV* const get_metaclass  = get_cvs("Mouse::Util::get_metaclass_by_name", TRUE);
        AV* const all_attrs      = newAV();
        SV* const get_attribute  = newSVpvs_share("get_attribute");

        AV* const linearized_isa = mro_get_linear_isa(stash);
        I32 const len            = AvFILLp(linearized_isa);
        I32 i;
        HV* seen;

        /* warn("Update all_attrs_cache (cache_gen %d != pkg_gen %d)", (cache_gen ? (int)SvIV(cache_gen) : 0), (int)pkg_gen); //*/

        ENTER;
        SAVETMPS;

        sv_2mortal(get_attribute);

        set_slot(metaclass, mouse_all_attrs_cache, sv_2mortal(newRV_inc((SV*)all_attrs)));

        seen = newHV();
        sv_2mortal((SV*)seen);

        for(i = 0; i < len; i++){
            SV* const klass = MOUSE_av_at(linearized_isa, i);
            SV* meta;
            I32 n;
            dSP;

            PUSHMARK(SP);
            XPUSHs(klass);
            PUTBACK;

            call_sv((SV*)get_metaclass, G_SCALAR);

            SPAGAIN;
            meta = POPs;
            PUTBACK;

            if(!SvOK(meta)){
                continue; /* skip non-Mouse classes */
            }

            /* $meta->get_attribute_list */
            PUSHMARK(SP);
            XPUSHs(meta);
            PUTBACK;

            n = call_method("get_attribute_list", G_ARRAY);
            for(NOOP; n > 0; n--){
                SV* name;

                SPAGAIN;
                name = POPs;
                PUTBACK;

                if(hv_exists_ent(seen, name, 0U)){
                    continue;
                }
                (void)hv_store_ent(seen, name, &PL_sv_undef, 0U);

                av_push(all_attrs, newSVsv( mcall1(meta, get_attribute, name) ));
            }
        }

        if(!cache_gen){
            cache_gen = sv_newmortal();
        }
        sv_setuv(cache_gen, mro_get_pkg_gen(stash));
        set_slot(metaclass, mouse_all_attrs_cache_gen, cache_gen);

        FREETMPS;
        LEAVE;

        return all_attrs;
    }
    else {
        SV* const all_attrs_ref = get_slot(metaclass, mouse_all_attrs_cache);

        if(!IsArrayRef(all_attrs_ref)){
            croak("Not an ARRAY reference");
        }

        return (AV*)SvRV(all_attrs_ref);
    }
}

MODULE = Mouse  PACKAGE = Mouse

PROTOTYPES: DISABLE

BOOT:
    mouse_package   = newSVpvs_share("package");
    mouse_namespace = newSVpvs_share("namespace");
    mouse_methods   = newSVpvs_share("methods");
    mouse_name      = newSVpvs_share("name");

    mouse_all_attrs_cache      = newSVpvs_share("__all_attrs_cache");
    mouse_all_attrs_cache_gen  = newSVpvs_share("__all_attrs_cache_gen");

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

void
get_all_attributes(SV* self)
PPCODE:
{
    AV* const all_attrs = mouse_get_all_attributes(aTHX_ self);
    I32 const len       = AvFILLp(all_attrs) + 1;
    I32 i;

    EXTEND(SP, len);
    for(i = 0; i < len; i++){
        PUSHs( MOUSE_av_at(all_attrs, i) );
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

