#include "mouse.h"

/* keywords for methods/keys */
SV* mouse_package;
SV* mouse_namespace;
SV* mouse_methods;
SV* mouse_name;
SV* mouse_get_attribute;
SV* mouse_get_attribute_list;
SV* mouse_coerce;

#define MOUSE_xc_flags(a)       SvUVX(MOUSE_av_at((a), MOUSE_XC_FLAGS))
#define MOUSE_xc_gen(a)         MOUSE_av_at((a), MOUSE_XC_GEN)
#define MOUSE_xc_stash(a)       ( (HV*)MOUSE_av_at((a), MOUSE_XC_STASH) )
#define MOUSE_xc_attrall(a)     ( (AV*)MOUSE_av_at((a), MOUSE_XC_ATTRALL) )
#define MOUSE_xc_buildall(a)    ( (AV*)MOUSE_av_at((a), MOUSE_XC_BUILDALL) )
#define MOUSE_xc_demolishall(a) ( (AV*)MOUSE_av_at((a), MOUSE_XC_DEMOLISHALL) )

enum mouse_xc_flags_t {
    MOUSEf_XC_IS_IMMUTABLE   = 0x0001,
    MOUSEf_XC_IS_ANON        = 0x0002,
    MOUSEf_XC_HAS_BUILDARGS  = 0x0004,
    MOUSEf_XC_CONSTRUCTOR_IS_STRICT
                             = 0x0008,

    MOUSEf_XC_mask           = 0xFFFF /* not used */
};

/* Mouse XS Metaclass object */
enum mouse_xc_ix_t{
    MOUSE_XC_FLAGS,

    MOUSE_XC_GEN,          /* class generation */
    MOUSE_XC_STASH,        /* symbol table hash */

    MOUSE_XC_ATTRALL,      /* all the attributes */
    MOUSE_XC_BUILDALL,     /* all the BUILD methods */
    MOUSE_XC_DEMOLISHALL,  /* all the DEMOLISH methods */

    MOUSE_XC_last
};

enum mouse_modifier_t {
    MOUSE_M_BEFORE,
    MOUSE_M_AROUND,
    MOUSE_M_AFTER,
};

static MGVTBL mouse_xc_vtbl; /* for identity */

HV*
mouse_get_namespace(pTHX_ SV* const meta) {
    SV* const package = get_slot(meta, mouse_package);
    if(!(package && SvOK(package))){
        croak("No package name defined for metaclass");
    }
    return gv_stashsv(package, GV_ADDMULTI);
}

static AV*
mouse_calculate_all_attributes(pTHX_ SV* const metaclass) {
    SV* const avref = mcall0s(metaclass, "_calculate_all_attributes");
    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        croak("$meta->_calculate_all_attributes did not return an ARRAY reference");
    }
    return (AV*)SvRV(avref);
}

XS(XS_Mouse__Object_BUILDARGS); /* prototype */

static int
mouse_class_has_custom_buildargs(pTHX_ HV* const stash) {
    GV* const buildargs = gv_fetchmeth_autoload(stash, "BUILDARGS", sizeof("BUILDARGS")-1, 0);

    return buildargs && CvXSUB(GvCV(buildargs)) != XS_Mouse__Object_BUILDARGS;
}

static AV*
mouse_class_update_xc(pTHX_ SV* const metaclass PERL_UNUSED_DECL, AV* const xc) {
    HV* const stash          = MOUSE_xc_stash(xc);
    AV* const linearized_isa = mro_get_linear_isa(stash);
    I32 const len            = AvFILLp(linearized_isa) + 1;
    I32 i;
    U32 flags             = 0x00;
    AV* const buildall    = newAV();
    AV* const demolishall = newAV();
    AV* attrall;

    ENTER;
    SAVETMPS;

     /* old data will be delete at the end of the perl scope */
    av_delete(xc, MOUSE_XC_DEMOLISHALL, 0x00);
    av_delete(xc, MOUSE_XC_BUILDALL,    0x00);
    av_delete(xc, MOUSE_XC_ATTRALL,     0x00);

    SvREFCNT_inc_simple_void_NN(linearized_isa);
    sv_2mortal((SV*)linearized_isa);

    /* update */

    av_store(xc, MOUSE_XC_BUILDALL,    (SV*)buildall);
    av_store(xc, MOUSE_XC_DEMOLISHALL, (SV*)demolishall);

    attrall = mouse_calculate_all_attributes(aTHX_ metaclass);
    SvREFCNT_inc_simple_void_NN(attrall);
    av_store(xc, MOUSE_XC_ATTRALL,     (SV*)attrall);

    if(predicate_calls(metaclass, "is_immutable")){
        flags |= MOUSEf_XC_IS_IMMUTABLE;
    }

    if(predicate_calls(metaclass, "is_anon_class")){
        flags |= MOUSEf_XC_IS_ANON;
    }

    if(mouse_class_has_custom_buildargs(aTHX_ stash)){
        flags |= MOUSEf_XC_HAS_BUILDARGS;
    }

    if(predicate_calls(metaclass, "strict_constructor")){
        flags |= MOUSEf_XC_CONSTRUCTOR_IS_STRICT;
    }

    av_store(xc, MOUSE_XC_FLAGS,       newSVuv(flags));

    for(i = 0; i < len; i++){
        SV* const klass = MOUSE_av_at(linearized_isa, i);
        HV* const st    = gv_stashsv(klass, TRUE);
        GV* gv;

        gv = stash_fetchs(st, "BUILD", FALSE);
        if(gv && GvCVu(gv)){
            av_unshift(buildall, 1);
            av_store(buildall, 0, newRV_inc((SV*)GvCV(gv)));
        }

        gv = stash_fetchs(st, "DEMOLISH", FALSE);
        if(gv && GvCVu(gv)){
            av_push(demolishall, newRV_inc((SV*)GvCV(gv)));
        }
    }

    FREETMPS;
    LEAVE;

    sv_setuv(MOUSE_xc_gen(xc), mro_get_pkg_gen(stash));
    return xc;
}

static AV*
mouse_get_xc_wo_check(pTHX_ SV* const metaclass) {
    AV* xc;
    MAGIC* mg;

    if(!IsObject(metaclass)){
        croak("Not a Mouse metaclass");
    }

    mg = mouse_mg_find(aTHX_ SvRV(metaclass), &mouse_xc_vtbl, 0x00);
    if(!mg){
        /* cache stash for performance */
        HV* const stash = mouse_get_namespace(aTHX_ metaclass);
        xc    = newAV();

        mg = sv_magicext(SvRV(metaclass), (SV*)xc, PERL_MAGIC_ext,
            &mouse_xc_vtbl, NULL, 0);
        SvREFCNT_dec(xc); /* refcnt++ in sv_magicext */

        av_extend(xc, MOUSE_XC_last - 1);

        av_store(xc, MOUSE_XC_GEN, newSVuv(0U));
        av_store(xc, MOUSE_XC_STASH, (SV*)stash);
        SvREFCNT_inc_simple_void_NN(stash);
    }
    else{
        xc    = (AV*)MOUSE_mg_obj(mg);

        assert(xc);
        assert(SvTYPE(xc) == SVt_PVAV);
    }
    return xc;
}

static int
mouse_xc_is_fresh(pTHX_ AV* const xc) {
    HV* const stash = MOUSE_xc_stash(xc);
    SV* const gen   = MOUSE_xc_gen(xc);
    if(SvUVX(gen) != 0U && MOUSE_xc_flags(xc) & MOUSEf_XC_IS_IMMUTABLE) {
        return TRUE;
    }
    return SvUVX(gen) == mro_get_pkg_gen(stash);
}

STATIC_INLINE AV*
mouse_get_xc(pTHX_ SV* const metaclass) {
    AV* const xc = mouse_get_xc_wo_check(aTHX_ metaclass);
    return mouse_xc_is_fresh(aTHX_ xc)
        ? xc
        : mouse_class_update_xc(aTHX_ metaclass, xc);
}

static AV*
mouse_get_xc_if_fresh(pTHX_ SV* const metaclass) {
    AV* const xc = mouse_get_xc_wo_check(aTHX_ metaclass);
    return mouse_xc_is_fresh(aTHX_ xc)
        ? xc
        : NULL;
}

static HV*
mouse_buildargs(pTHX_ SV* metaclass, SV* const klass, I32 ax, I32 items) {
    HV* args;

    /* shift @_ */
    ax++;
    items--;

    if(items == 1){
        SV* const args_ref = ST(0);
        if(!IsHashRef(args_ref)){
            if(!metaclass){ metaclass = get_metaclass(klass); }
            mouse_throw_error(metaclass, NULL, "Single parameters to new() must be a HASH ref");
        }
        args = newHVhv((HV*)SvRV(args_ref));
        sv_2mortal((SV*)args);
    }
    else{
        I32 i;

        if( (items % 2) != 0 ){
            if(!metaclass){ metaclass = get_metaclass(klass); }
            mouse_throw_error(metaclass, NULL, "Odd number of parameters to new()");
        }

        args = newHV_mortal();
        for(i = 0; i < items; i += 2){
            (void)hv_store_ent(args, ST(i), newSVsv(ST(i+1)), 0U);
        }

    }
    return args;
}

static void
mouse_report_unknown_args(pTHX_ SV* const meta, AV* const attrs, HV* const args) {
    HV* const attr_map = newHV_mortal();
    SV* const unknown  = newSVpvs_flags("", SVs_TEMP);
    I32 const len      = AvFILLp(attrs) + 1;
    I32 i;
    HE* he;

    for(i = 0; i < len; i++){
        SV* const attr = MOUSE_av_at(attrs, i);
        AV* const xa   = mouse_get_xa(aTHX_ attr);
        SV* const init_arg = MOUSE_xa_init_arg(xa);
        if(SvOK(init_arg)){
            (void)hv_store_ent(attr_map, init_arg, &PL_sv_undef, 0U);
        }
    }

    hv_iterinit(args);
    while((he = hv_iternext(args))){
        SV* const key = hv_iterkeysv(he);
        if(!hv_exists_ent(attr_map, key, 0U)){
            sv_catpvf(unknown, "%"SVf", ", key);
        }
    }

    if(SvCUR(unknown) > 0){
        SvCUR(unknown) -= 2; /* chop "," */
    }
    else{
        sv_setpvs(unknown, "(unknown)");
    }

    mouse_throw_error(meta, NULL,
        "Unknown attribute passed to the constructor of %"SVf": %"SVf,
        mcall0(meta, mouse_name), unknown);
}



static void
mouse_class_initialize_object(pTHX_ SV* const meta, SV* const object, HV* const args, bool const is_cloning) {
    AV* const xc    = mouse_get_xc(aTHX_ meta);
    AV* const attrs = MOUSE_xc_attrall(xc);
    I32 const len   = AvFILLp(attrs) + 1;
    I32 i;
    AV* triggers_queue = NULL;
    I32 used = 0;

    assert(meta || object);
    assert(args);
    assert(SvTYPE(args) == SVt_PVHV);

    if(mg_find((SV*)args, PERL_MAGIC_tied)){
        croak("You cannot use tied HASH reference as initializing arguments");
    }

    /* for each attribute */
    for(i = 0; i < len; i++){
        SV* const attr = MOUSE_av_at(attrs, i);
        AV* const xa   = mouse_get_xa(aTHX_ attr);

        SV* const slot     = MOUSE_xa_slot(xa);
        U16 const flags    = (U16)MOUSE_xa_flags(xa);
        SV* const init_arg = MOUSE_xa_init_arg(xa);
        HE* he;

        if(SvOK(init_arg) && ( he = hv_fetch_ent(args, init_arg, FALSE, 0U) ) ){
            SV* value = HeVAL(he);
            if(flags & MOUSEf_ATTR_HAS_TC){
                value = mouse_xa_apply_type_constraint(aTHX_ xa, value, flags);
            }
            value = set_slot(object, slot, value);
            if(flags & MOUSEf_ATTR_IS_WEAK_REF){
                weaken_slot(object, slot);
            }
            if(flags & MOUSEf_ATTR_HAS_TRIGGER){
                AV* const pair = newAV();
                av_push(pair, newSVsv( mcall0s(attr, "trigger") ));
                av_push(pair, newSVsv(value));

                if(!triggers_queue) {
                    triggers_queue = newAV_mortal();
                }
                av_push(triggers_queue, (SV*)pair);
            }
            used++;
        }
        else { /* no init arg */
            if(flags & (MOUSEf_ATTR_HAS_DEFAULT | MOUSEf_ATTR_HAS_BUILDER)){
                /* skip if the object has the slot (it occurs on cloning/reblessing) */
                if(!(flags & MOUSEf_ATTR_IS_LAZY) && !has_slot(object, slot)){
                    mouse_xa_set_default(aTHX_ xa, object);
                }
            }
            else if(is_cloning) {
                if(flags & MOUSEf_ATTR_IS_WEAK_REF){
                    weaken_slot(object, slot);
                }
            }
            /* don't check "required" while cloning (or reblesseing) */
            else if(flags & MOUSEf_ATTR_IS_REQUIRED) {
                mouse_throw_error(attr, NULL, "Attribute (%"SVf") is required", slot);
            }
        }
    } /* for each attribute */

    if(MOUSE_xc_flags(xc) & MOUSEf_XC_CONSTRUCTOR_IS_STRICT
            && used < (I32)HvUSEDKEYS(args)){
        mouse_report_unknown_args(aTHX_ meta, attrs, args);
    }

    if(triggers_queue){
        I32 const len = AvFILLp(triggers_queue) + 1;
        for(i = 0; i < len; i++){
            AV* const pair    = (AV*)AvARRAY(triggers_queue)[i];
            SV* const trigger = AvARRAY(pair)[0];
            SV* const value   = AvARRAY(pair)[1];

            mcall1(object, trigger, value);
        }
    }

    if(MOUSE_xc_flags(xc) & MOUSEf_XC_IS_ANON){
        (void)set_slot(object, newSVpvs_flags("__METACLASS__", SVs_TEMP), meta);
    }
}

STATIC_INLINE SV*
mouse_initialize_metaclass(pTHX_ SV* const klass) {
    SV* const meta = get_metaclass(klass);
    if(LIKELY(SvOK(meta))){
        return meta;
    }
    return mcall1s(newSVpvs_flags("Mouse::Meta::Class", SVs_TEMP),
            "initialize", klass);
}

static void
mouse_buildall(pTHX_ AV* const xc, SV* const object, SV* const args) {
    AV* const buildall = MOUSE_xc_buildall(xc);
    I32 const len      = AvFILLp(buildall) + 1;
    I32 i;
    for(i = 0; i < len; i++){
        dSP;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(object);
        PUSHs(args);
        PUTBACK;

        call_sv_safe(AvARRAY(buildall)[i], G_VOID | G_DISCARD);
    }
}

static AV*
mouse_get_modifier_storage(pTHX_
        SV* const meta,
        enum mouse_modifier_t const m, SV* const name) {
    static const char* const keys[] = {
        "before",
        "around",
        "after",
    };
    SV* const key = sv_2mortal(Perl_newSVpvf(aTHX_ "%s_method_modifiers", keys[m]));
    SV* table;
    SV* storage_ref;

    must_defined(name, "a method name");

    table = get_slot(meta, key);

    if(!table){
        /* $meta->{$key} = {} */
        table = sv_2mortal(newRV_noinc((SV*)newHV()));
        set_slot(meta, key, table);
    }

    storage_ref = get_slot(table, name);

    if(!storage_ref){
        storage_ref = sv_2mortal(newRV_noinc((SV*)newAV()));
        set_slot(table, name, storage_ref);
    }
    else{
        if(!IsArrayRef(storage_ref)){
            croak("Modifier strorage for '%s' is not an ARRAY reference", keys[m]);
        }
    }

    return (AV*)SvRV(storage_ref);
}

static
XSPROTO(XS_Mouse_value_holder) {
    dVAR; dXSARGS;
    SV* const value = (SV*)XSANY.any_ptr;
    assert(value);
    PERL_UNUSED_VAR(items);
    ST(0) = value;
    XSRETURN(1);
}

DECL_BOOT(Mouse__Util);
DECL_BOOT(Mouse__Util__TypeConstraints);
DECL_BOOT(Mouse__Meta__Method__Accessor__XS);
DECL_BOOT(Mouse__Meta__Attribute);

MODULE = Mouse  PACKAGE = Mouse

PROTOTYPES: DISABLE

BOOT:
{
    mouse_package   = newSVpvs("package");
    mouse_namespace = newSVpvs("namespace");
    mouse_methods   = newSVpvs("methods");
    mouse_name      = newSVpvs("name");
    mouse_coerce    = newSVpvs("coerce");

    mouse_get_attribute      = newSVpvs("get_attribute");
    mouse_get_attribute_list = newSVpvs("get_attribute_list");

    CALL_BOOT(Mouse__Util);
    CALL_BOOT(Mouse__Util__TypeConstraints);
    CALL_BOOT(Mouse__Meta__Method__Accessor__XS);
    CALL_BOOT(Mouse__Meta__Attribute);
}

MODULE = Mouse  PACKAGE = Mouse::Meta::Module

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Module, name, package);
    INSTALL_SIMPLE_READER_WITH_KEY(Module, _method_map, methods);
    INSTALL_SIMPLE_READER_WITH_KEY(Module, _attribute_map, attributes);

HV*
namespace(SV* self)
CODE:
{
    RETVAL = mouse_get_namespace(aTHX_ self);
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

    must_defined(name, "a method name");
    must_ref    (code, "a CODE reference", SVt_NULL); /* any reftype is OK */

    code_ref = code;
    if(SvTYPE(SvRV(code_ref)) != SVt_PVCV){
        SV*  sv = code_ref;  /* used in tryAMAGICunDEREF */
        SV** sp = &sv;       /* used in tryAMAGICunDEREF */
        tryAMAGICunDEREF(to_cv); /* try \&{$code} */
        must_ref(code, "a CODE reference", SVt_PVCV);
        code_ref = sv;
    }

    /*  *{$package . '::' . $name} -> *gv */
    gv = gv_fetchpv(form("%"SVf"::%"SVf, package, name), GV_ADDMULTI, SVt_PVCV);
    mouse_install_sub(aTHX_ gv, code_ref);
    /* CvMETHOD_on((CV*)SvRV(code_ref)); */
    (void)set_slot(methods, name, code); /* $self->{methods}{$name} = $code */
}

MODULE = Mouse  PACKAGE = Mouse::Meta::Class

BOOT:
{
    CV* xsub;

    INSTALL_SIMPLE_READER(Class, roles);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Class, is_anon_class, anon_serial_id);
    INSTALL_SIMPLE_READER(Class, is_immutable);

    INSTALL_INHERITABLE_CLASS_ACCESSOR(strict_constructor);

    INSTALL_CLASS_HOLDER(Class, method_metaclass,     "Mouse::Meta::Method");
    INSTALL_CLASS_HOLDER(Class, attribute_metaclass,  "Mouse::Meta::Attribute");
    INSTALL_CLASS_HOLDER(Class, constructor_class,    "Mouse::Meta::Method::Constructor::XS");
    INSTALL_CLASS_HOLDER(Class, destructor_class,     "Mouse::Meta::Method::Destructor::XS");

    xsub = newXS("Mouse::Meta::Method::Constructor::XS::_generate_constructor",
        XS_Mouse_value_holder, file);
    CvXSUBANY(xsub).any_ptr
        = newRV_inc((SV*)get_cvs("Mouse::Object::new", GV_ADD));

    xsub = newXS("Mouse::Meta::Method::Destructor::XS::_generate_destructor",
        XS_Mouse_value_holder, file);
    CvXSUBANY(xsub).any_ptr
        = newRV_inc((SV*)get_cvs("Mouse::Object::DESTROY", GV_ADD));
}


void
linearized_isa(SV* self)
PPCODE:
{
    /* MOUSE_xc_stash() is not available because the xc system depends on
       linearized_isa() */
    HV* const stash          = mouse_get_namespace(aTHX_ self);
    AV* const linearized_isa = mro_get_linear_isa(stash);
    I32 const            len = AvFILLp(linearized_isa) + 1;
    I32 i;
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
    AV* const all_attrs = MOUSE_xc_attrall(xc);
    I32 const len       = AvFILLp(all_attrs) + 1;
    I32 i;

    EXTEND(SP, len);
    for(i = 0; i < len; i++){
        PUSHs( MOUSE_av_at(all_attrs, i) );
    }
}

void
new_object(SV* meta, ...)
CODE:
{
    AV* const xc   = mouse_get_xc(aTHX_ meta);
    HV* const args = mouse_buildargs(aTHX_ meta, NULL, ax, items);
    SV* object;

    object = mouse_instance_create(aTHX_ MOUSE_xc_stash(xc));
    mouse_class_initialize_object(aTHX_ meta, object, args, FALSE);
    mouse_buildall(aTHX_ xc, object, sv_2mortal(newRV_inc((SV*)args)));
    ST(0) = object; /* because object is mortal, we should return it as is */
    XSRETURN(1);
}

void
clone_object(SV* meta, SV* object, ...)
CODE:
{
    AV* const xc   = mouse_get_xc(aTHX_ meta);
    HV* const args = mouse_buildargs(aTHX_ meta, NULL, ax + 1, items - 1);
    SV* proto;

    if(!mouse_is_an_instance_of(aTHX_ MOUSE_xc_stash(xc), object)) {
        mouse_throw_error(meta, object,
            "You must pass an instance of the metaclass (%"SVf"), not (%"SVf")",
            mcall0(meta, mouse_name), object);
    }

    proto = mouse_instance_clone(aTHX_ object);
    mouse_class_initialize_object(aTHX_ meta, proto, args, TRUE);
    ST(0) = proto; /* because object is mortal, we should return it as is */
    XSRETURN(1);
}

void
_initialize_object(SV* meta, SV* object, HV* args, bool is_cloning = FALSE)
CODE:
{
    mouse_class_initialize_object(aTHX_ meta, object, args, is_cloning);
}

void
_invalidate_metaclass_cache(SV* meta)
CODE:
{
    AV* const xc = mouse_get_xc_if_fresh(aTHX_ meta);
    if(xc) {
        SV* const gen = MOUSE_xc_gen(xc);
        sv_setuv(gen, 0U);
    }
    delete_slot(meta, newSVpvs_flags("_mouse_cache_", SVs_TEMP));
}


MODULE = Mouse  PACKAGE = Mouse::Meta::Role

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Role, get_roles, roles);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(Role, is_anon_role, anon_serial_id);

    INSTALL_CLASS_HOLDER(Role, method_metaclass,  "Mouse::Meta::Role::Method");

void
add_before_modifier(SV* self, SV* name, SV* modifier)
CODE:
{
    av_push(mouse_get_modifier_storage(aTHX_ self, (enum mouse_modifier_t)ix, name), newSVsv(modifier));
}
ALIAS:
    add_before_method_modifier = MOUSE_M_BEFORE
    add_around_method_modifier = MOUSE_M_AROUND
    add_after_method_modifier  = MOUSE_M_AFTER

void
get_before_modifiers(SV* self, SV* name)
ALIAS:
    get_before_method_modifiers = MOUSE_M_BEFORE
    get_around_method_modifiers = MOUSE_M_AROUND
    get_after_method_modifiers  = MOUSE_M_AFTER
PPCODE:
{
    AV* const storage = mouse_get_modifier_storage(aTHX_ self,
                            (enum mouse_modifier_t)ix, name);
    I32 const len     = av_len(storage) + 1;
    if(GIMME_V == G_ARRAY) {
        I32 i;
        EXTEND(SP, len);
        for(i = 0; i < len; i++){
            PUSHs(*av_fetch(storage, i, TRUE));
        }
    }
    else{
        mPUSHi(len);
    }
}

void
add_metaclass_accessor(SV* self, SV* name)
CODE:
{
    SV* const klass = mcall0(self, mouse_name);
    const char* fq_name = form("%"SVf"::%"SVf, klass, name);
    STRLEN keylen;
    const char* const key = SvPV_const(name, keylen);
    mouse_simple_accessor_generate(aTHX_ fq_name, key, keylen,
        XS_Mouse_inheritable_class_accessor, NULL, 0);
}

MODULE = Mouse  PACKAGE = Mouse::Object

void
new(SV* klass, ...)
CODE:
{
    SV* const meta = mouse_initialize_metaclass(aTHX_ klass);
    AV* const xc   = mouse_get_xc(aTHX_ meta);
    UV const flags = MOUSE_xc_flags(xc);
    SV* args;
    SV* object;

    /* BUILDARGS */
    if(flags & MOUSEf_XC_HAS_BUILDARGS){
        I32 i;
        SPAGAIN;

        PUSHMARK(SP);
        EXTEND(SP, items);
        for(i = 0; i < items; i++){
            PUSHs(ST(i));
        }

        PUTBACK;
        call_method_safes("BUILDARGS", G_SCALAR);

        SPAGAIN;
        args = POPs;
        PUTBACK;

        if(!IsHashRef(args)){
            croak("BUILDARGS did not return a HASH reference");
        }
    }
    else{
        args = newRV_inc((SV*)mouse_buildargs(aTHX_ meta, klass, ax, items));
        sv_2mortal(args);
    }

    /* new_object */
    object = mouse_instance_create(aTHX_ MOUSE_xc_stash(xc));
    mouse_class_initialize_object(aTHX_ meta, object, (HV*)SvRV(args), FALSE);
    /* BUILDALL */
    mouse_buildall(aTHX_ xc, object, args);
    ST(0) = object; /* because object is mortal, we should return it as is */
    XSRETURN(1);
}

void
DESTROY(SV* object)
ALIAS:
    DESTROY     = 0
    DEMOLISHALL = 1
CODE:
{
    SV* const meta = get_metaclass(object);
    AV* xc;
    AV* demolishall;
    I32 len;
    I32 i;

    if(!IsObject(object)){
        croak("You must not call %s as a class method",
            ix == 0 ? "DESTROY" : "DEMOLISHALL");
    }

    if(SvOK(meta) && (xc = mouse_get_xc_if_fresh(aTHX_ meta))) {
        demolishall = MOUSE_xc_demolishall(xc);
    }
    else { /* The metaclass is already destroyed */
        AV* const linearized_isa = mro_get_linear_isa(SvSTASH(SvRV(object)));

        len = AvFILLp(linearized_isa) + 1;

        demolishall = newAV_mortal();
        for(i = 0; i < len; i++){
            SV* const klass = MOUSE_av_at(linearized_isa, i);
            HV* const st    = gv_stashsv(klass, TRUE);
            GV* const gv    = stash_fetchs(st, "DEMOLISH", FALSE);
            if(gv && GvCVu(gv)){
                av_push(demolishall, newRV_inc((SV*)GvCV(gv)));
            }
        }
    }

    len  = AvFILLp(demolishall) + 1;
    if(len > 0){
        SV* const in_global_destruction = boolSV(PL_dirty);
        SAVEI32(PL_statusvalue); /* local $? */
        PL_statusvalue = 0;

        SAVEGENERICSV(ERRSV); /* local $@ */
        ERRSV = newSV(0);

        EXTEND(SP, 2);

        for(i = 0; i < len; i++){
            SPAGAIN;

            PUSHMARK(SP);
            PUSHs(object);
            PUSHs(in_global_destruction);
            PUTBACK;

            call_sv(AvARRAY(demolishall)[i], G_VOID | G_EVAL | G_DISCARD);

            if(sv_true(ERRSV)){
                SV* const e = sv_mortalcopy(ERRSV);
                LEAVE;
                sv_setsv(ERRSV, e);
                croak(NULL); /* rethrow */
            }
        }
    }
}

HV*
BUILDARGS(SV* klass, ...)
CODE:
{
    RETVAL = mouse_buildargs(aTHX_ NULL, klass, ax, items);
}
OUTPUT:
    RETVAL


void
BUILDALL(SV* self, SV* args)
CODE:
{
    SV* const meta = get_metaclass(self);
    AV* const xc   = mouse_get_xc(aTHX_ meta);

    must_ref(args, "a HASH reference to BUILDALL", SVt_PVHV);
    mouse_buildall(aTHX_ xc, self, args);
}
