#define  NEED_newSVpvn_flags_GLOBAL
#include "mouse.h"

SV* mouse_package;
SV* mouse_namespace;
SV* mouse_methods;
SV* mouse_name;
SV* mouse_get_attribute;
SV* mouse_get_attribute_list;

#define MOUSE_xc_flags(a)       SvUVX(MOUSE_av_at((a), MOUSE_XC_FLAGS))
#define MOUSE_xc_gen(a)         MOUSE_av_at((a), MOUSE_XC_GEN)
#define MOUSE_xc_stash(a)       ( (HV*)MOUSE_av_at((a), MOUSE_XC_STASH) )
#define MOUSE_xc_attrall(a)     ( (AV*)MOUSE_av_at((a), MOUSE_XC_ATTRALL) )
#define MOUSE_xc_buildall(a)    ( (AV*)MOUSE_av_at((a), MOUSE_XC_BUILDALL) )
#define MOUSE_xc_demolishall(a) ( (AV*)MOUSE_av_at((a), MOUSE_XC_DEOLISHALL) )

enum mouse_xc_flags_t {
    MOUSEf_XC_IS_IMMUTABLE   = 0x0001,
    MOUSEf_XC_IS_ANON        = 0x0002,
    MOUSEf_XC_HAS_BUILDARGS  = 0x0004,

    MOUSEf_XC_mask           = 0xFFFF /* not used */
};

/* Mouse XS Metaclass object */
enum mouse_xc_ix_t{
    MOUSE_XC_FLAGS,

    MOUSE_XC_GEN,          /* class generation */
    MOUSE_XC_STASH,        /* symbol table hash */

    MOUSE_XC_BUILDARGS,    /* Custom BUILDARGS */

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

    n = call_sv(mouse_get_attribute_list, G_ARRAY | G_METHOD);
    for(NOOP; n > 0; n--){
        SV* name;

        SPAGAIN;
        name = POPs;
        PUTBACK;

        if(hv_exists_ent(seen, name, 0U)){
            continue;
        }
        (void)hv_store_ent(seen, name, &PL_sv_undef, 0U);

        av_push(attrall, newSVsv( mcall1(metaclass, mouse_get_attribute, name) ));
    }
}

static int
mouse_class_has_custom_buildargs(pTHX_ HV* const stash) {
    XS(XS_Mouse__Object_BUILDARGS); /* prototype */

    GV* const buildargs = gv_fetchmeth_autoload(stash, "BUILDARGS", sizeof("BUILDARGS")-1, 0);

    return buildargs && CvXSUB(GvCV(buildargs)) == XS_Mouse__Object_BUILDARGS;
}

static void
mouse_class_update_xc(pTHX_ SV* const metaclass PERL_UNUSED_DECL, HV* const stash, AV* const xc) {
    AV* const linearized_isa = mro_get_linear_isa(stash);
    I32 const len            = AvFILLp(linearized_isa);
    I32 i;
    U32 flags             = 0x00;
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

    if(predicate_calls(metaclass, "is_immutable")){
        flags |= MOUSEf_XC_IS_IMMUTABLE;
    }

    if(predicate_calls(metaclass, "is_anon_class")){
        flags |= MOUSEf_XC_IS_ANON;
    }

    if(mouse_class_has_custom_buildargs(aTHX_ stash)){
        flags |= MOUSEf_XC_HAS_BUILDARGS;
    }

    av_store(xc, MOUSE_XC_FLAGS,       newSVuv(flags));
    av_store(xc, MOUSE_XC_ATTRALL,     (SV*)attrall);
    av_store(xc, MOUSE_XC_BUILDALL,    (SV*)buildall);
    av_store(xc, MOUSE_XC_DEMOLISHALL, (SV*)demolishall);

    for(i = 0; i < len; i++){
        SV* const klass = MOUSE_av_at(linearized_isa, i);
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
        meta = get_metaclass(klass);
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
        STRLEN len;
        const char* const pv = SvPV_const(package, len);

        stash = gv_stashpvn(pv, len, TRUE);
        xc    = newAV();

        mg = sv_magicext(SvRV(metaclass), (SV*)xc, PERL_MAGIC_ext, &mouse_xc_vtbl, pv, len);
        SvREFCNT_dec(xc); /* refcnt++ in sv_magicext */

        av_extend(xc, MOUSE_XC_last - 1);

        av_store(xc, MOUSE_XC_GEN, newSViv(0));
        av_store(xc, MOUSE_XC_STASH, (SV*)stash);

        SvREFCNT_inc_simple_void_NN(stash);
    }
    else{
        xc    = (AV*)MOUSE_mg_obj(mg);

        assert(xc);
        assert(SvTYPE(xc) == SVt_PVAV);
    }

    gen   = MOUSE_xc_gen(xc);
    stash = MOUSE_xc_stash(xc);

    if(SvUV(gen) != mro_get_pkg_gen(stash)){
        mouse_class_update_xc(aTHX_ metaclass, stash, xc);
    }

    return xc;
}

HV*
mouse_build_args(pTHX_ SV* metaclass, SV* const klass, I32 const start, I32 const items, I32 const ax) {
    HV* args;
    if((items - start) == 1){
        SV* const args_ref = ST(start);
        if(!IsHashRef(args_ref)){
            if(!metaclass){ metaclass = get_metaclass(klass); }
            mouse_throw_error(metaclass, NULL, "Single parameters to new() must be a HASH ref");
        }
        args = newHVhv((HV*)SvRV(args_ref));
        sv_2mortal((SV*)args);
    }
    else{
        I32 i;

        args = newHV_mortal();

        if( ((items - start) % 2) != 0 ){
            if(!metaclass){ metaclass = get_metaclass(klass); }
            mouse_throw_error(metaclass, NULL, "Odd number of parameters to new()");
        }

        for(i = start; i < items; i += 2){
            (void)hv_store_ent(args, ST(i), newSVsv(ST(i+1)), 0U);
        }

    }
    return args;
}

void
mouse_class_initialize_object(pTHX_ SV* const meta, SV* const object, HV* const args, bool const ignore_triggers) {
    AV* const xc    = mouse_get_xc(aTHX_ meta);
    AV* const attrs = MOUSE_xc_attrall(xc);
    I32 len         = AvFILLp(attrs) + 1;
    I32 i;
    AV* triggers_queue = NULL;

    ENTER;
    SAVETMPS;

    if(!ignore_triggers){
        triggers_queue = newAV_mortal();
    }

    for(i = 0; i < len; i++){
        SV* const attr = AvARRAY(attrs)[i];
        AV* const xa   = mouse_get_xa(aTHX_ AvARRAY(attrs)[i]);

        SV* const slot     = MOUSE_xa_slot(xa);
        U16 const flags    = (U16)MOUSE_xa_flags(xa);
        SV* const init_arg = MOUSE_xa_init_arg(xa);
        HE* he;

        if(SvOK(init_arg) && ( he = hv_fetch_ent(args, init_arg, FALSE, 0U) ) ){
            SV* value = HeVAL(he);
            if(flags & MOUSEf_ATTR_HAS_TC){
                value = mouse_xa_apply_type_constraint(aTHX_ xa, value, flags);
            }
            set_slot(object, slot, value);
            if(SvROK(value) && flags & MOUSEf_ATTR_IS_WEAK_REF){
                weaken_slot(object, slot);
            }
            if(flags & MOUSEf_ATTR_HAS_TRIGGER && triggers_queue){
                AV* const pair = newAV();
                av_push(pair, newSVsv( mcall0s(attr, "trigger") ));
                av_push(pair, newSVsv(value));

                av_push(triggers_queue, (SV*)pair);
            }
        }
        else { /* no init arg */
            if(flags & (MOUSEf_ATTR_HAS_DEFAULT | MOUSEf_ATTR_HAS_BUILDER)){
                if(!(flags & MOUSEf_ATTR_IS_LAZY)){
                    mouse_xa_set_default(aTHX_ xa, object);
                }
            }
            else if(flags & MOUSEf_ATTR_IS_REQUIRED) {
                mouse_throw_error(attr, NULL, "Attribute (%"SVf") is required", slot);
            }
        }
    } /* for each attributes */

    if(triggers_queue){
        len = AvFILLp(triggers_queue) + 1;
        for(i = 0; i < len; i++){
            AV* const pair    = (AV*)AvARRAY(triggers_queue)[i];
            SV* const trigger = AvARRAY(pair)[0];
            SV* const value   = AvARRAY(pair)[1];

            mcall1(object, trigger, value);
        }
    }

    if(MOUSE_xc_flags(xc) & MOUSEf_XC_IS_ANON){
        set_slot(object, newSVpvs_flags("__ANON__", SVs_TEMP), meta);
    }

    FREETMPS;
    LEAVE;
}

MODULE = Mouse  PACKAGE = Mouse

PROTOTYPES: DISABLE

BOOT:
    mouse_package   = newSVpvs_share("package");
    mouse_namespace = newSVpvs_share("namespace");
    mouse_methods   = newSVpvs_share("methods");
    mouse_name      = newSVpvs_share("name");

    mouse_get_attribute      = newSVpvs_share("get_attribute");
    mouse_get_attribute_list = newSVpvs_share("get_attribute_list");

    MOUSE_CALL_BOOT(Mouse__Util);
    MOUSE_CALL_BOOT(Mouse__Util__TypeConstraints);
    MOUSE_CALL_BOOT(Mouse__Meta__Method__Accessor__XS);
    MOUSE_CALL_BOOT(Mouse__Meta__Attribute);


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
    AV* const xc        = mouse_get_xc(aTHX_ self);
    AV* const all_attrs =  MOUSE_xc_attrall(xc);
    I32 const len       = AvFILLp(all_attrs) + 1;
    I32 i;

    EXTEND(SP, len);
    for(i = 0; i < len; i++){
        PUSHs( MOUSE_av_at(all_attrs, i) );
    }
}

SV*
new_object_(SV* meta, ...)
CODE:
{
    HV* const args = mouse_build_args(aTHX_ meta, NULL, 1, items, ax);
    AV* const xc   = mouse_get_xc(aTHX_ meta);

    RETVAL = mouse_instance_create(aTHX_ MOUSE_xc_stash(xc));
    mouse_class_initialize_object(aTHX_ meta, RETVAL, args, FALSE);
}


void
_initialize_object(SV* meta, SV* object, HV* args, bool ignore_triggers = FALSE)
CODE:
{
    mouse_class_initialize_object(aTHX_ meta, object, args, ignore_triggers);
}

MODULE = Mouse  PACKAGE = Mouse::Meta::Role

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Role, get_roles, roles);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Role, is_anon_role, anon_serial_id);

MODULE = Mouse  PACKAGE = Mouse::Object

HV*
BUILDARGS(SV* klass, ...)
CODE:
{
    RETVAL = mouse_build_args(aTHX_ NULL, klass, 1, items, ax);
}
OUTPUT:
    RETVAL
