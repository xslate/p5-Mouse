#define  NEED_newSVpvn_flags_GLOBAL
#include "mouse.h"

SV* mouse_package;
SV* mouse_namespace;
SV* mouse_methods;
SV* mouse_name;

static SV* mouse_all_attrs_cache;
static SV* mouse_all_attrs_cache_gen;

#define MOUSE_xc_gen(a)         MOUSE_av_at((a), MOUSE_XC_GEN)
#define MOUSE_xc_attrall(a)     ( (AV*)MOUSE_av_at((a), MOUSE_XC_ATTRALL) )
#define MOUSE_xc_buildall(a)    ( (AV*)MOUSE_av_at((a), MOUSE_XC_BUILDALL) )
#define MOUSE_xc_demolishall(a) ( (AV*)MOUSE_av_at((a), MOUSE_XC_DEOLISHALL) )

/* Mouse XS Metaclass object */
enum mouse_xc_ix_t{
    MOUSE_XC_GEN,          /* class generation */
    MOUSE_XC_ATTRALL,      /* all the attributes */
    MOUSE_XC_BUILDALL,     /* all the BUILD methods */
    MOUSE_XC_DEMOLISHALL,  /* all the DEMOLISH methods */

    MOUSE_XC_last
};

static MGVTBL mouse_xc_vtbl; /* for identity */

static void
mouse_class_push_attribute_list(pTHX_ SV* const metaclass, AV* const attrall, HV* const seen){
    dSP;
    I32 n;

    /* $meta->get_attribute_list */
    PUSHMARK(SP);
    XPUSHs(metaclass);
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

        av_push(attrall, newSVsv( mcall1s(metaclass, "get_attribute", name) ));
    }
}

static void
mouse_class_update_xc(pTHX_ SV* const metaclass PERL_UNUSED_DECL, HV* const stash, AV* const xc) {
    AV* const linearized_isa = mro_get_linear_isa(stash);
    I32 const len            = AvFILLp(linearized_isa);
    I32 i;
    AV* const attrall     = newAV();
    AV* const buildall    = newAV();
    AV* const demolishall = newAV();
    HV* const seen        = newHV(); /* for attributes */

    ENTER;
    SAVETMPS;

    sv_2mortal((SV*)seen);

     /* old data will be delete at the end of the perl scope */
    av_delete(xc, MOUSE_XC_DEMOLISHALL, 0x00);
    av_delete(xc, MOUSE_XC_BUILDALL,    0x00);
    av_delete(xc, MOUSE_XC_ATTRALL,     0x00);

    SvREFCNT_inc_simple_void_NN(linearized_isa);
    sv_2mortal((SV*)linearized_isa);

    /* update */

    av_store(xc, MOUSE_XC_ATTRALL,     (SV*)attrall);
    av_store(xc, MOUSE_XC_BUILDALL,    (SV*)buildall);
    av_store(xc, MOUSE_XC_DEMOLISHALL, (SV*)demolishall);

    for(i = 0; i < len; i++){
        SV* const klass     = MOUSE_av_at(linearized_isa, i);
        SV* meta;
        GV* gv;

        gv = stash_fetchs(stash, "BUILD", FALSE);
        if(gv && GvCVu(gv)){
            av_push(buildall, newRV_inc((SV*)GvCV(gv)));
        }

        gv = stash_fetchs(stash, "DEMOLISH", FALSE);
        if(gv && GvCVu(gv)){
            av_push(demolishall, newRV_inc((SV*)GvCV(gv)));
        }

        /* ATTRIBUTES */
        meta = get_metaclass_by_name(klass);
        if(!SvOK(meta)){
            continue; /* skip non-Mouse classes */
        }

        mouse_class_push_attribute_list(aTHX_ meta, attrall, seen);
    }

    FREETMPS;
    LEAVE;

    sv_setuv(MOUSE_xc_gen(xc), mro_get_pkg_gen(stash));
}

AV*
mouse_get_xc(pTHX_ SV* const metaclass) {
    AV* xc;
    SV* gen;
    HV* stash;
    MAGIC* mg;

    if(!IsObject(metaclass)){
        croak("Not a Mouse metaclass");
    }

    mg = mouse_mg_find(aTHX_ SvRV(metaclass), &mouse_xc_vtbl, 0x00);
    if(!mg){
        SV* const package = get_slot(metaclass, mouse_package);

        stash = gv_stashsv(package, TRUE);
        xc    = newAV();

        mg = sv_magicext(SvRV(metaclass), (SV*)xc, PERL_MAGIC_ext, &mouse_xc_vtbl, (char*)stash, HEf_SVKEY);
        SvREFCNT_dec(xc); /* refcnt++ in sv_magicext */

        av_extend(xc, MOUSE_XC_last - 1);
        av_store(xc, MOUSE_XC_GEN, newSViv(0));
    }
    else{
        stash = (HV*)MOUSE_mg_ptr(mg);
        xc    = (AV*)MOUSE_mg_obj(mg);

        assert(stash);
        assert(SvTYPE(stash) == SVt_PVAV);

        assert(xc);
        assert(SvTYPE(xc) == SVt_PVAV);
    }

    gen = MOUSE_xc_gen(xc);
    if(SvUV(gen) != mro_get_pkg_gen(stash)){
        mouse_class_update_xc(aTHX_ metaclass, stash, xc);
    }

    return xc;
}

AV*
mouse_get_all_attributes(pTHX_ SV* const metaclass) {
    AV* const xc = mouse_get_xc(aTHX_ metaclass);
    return MOUSE_xc_attrall(xc);
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

