/*
 * TypeConstraint stuff
 *  - Mouse::Util::TypeConstraints (including OptimizedConstraints)
 *  - Mouse::Meta::TypeConstraint
 */

#include "mouse.h"
#include "xs_version.h"

#define MY_CXT_KEY "Mouse::Util::TypeConstraints::_guts" XS_VERSION
typedef struct sui_cxt{
    GV* universal_isa;
    GV* universal_can;
    AV* tc_extra_args;
} my_cxt_t;
START_MY_CXT

typedef int (*check_fptr_t)(pTHX_ SV* const data, SV* const sv);

static
XSPROTO(XS_Mouse_constraint_check);

static MGVTBL mouse_util_type_constraints_vtbl; /* not used, only for identity */

/*
    NOTE: mouse_tc_check() handles GETMAGIC
*/
int
mouse_tc_check(pTHX_ SV* const tc_code, SV* const sv) {
    CV* const cv = (CV*)SvRV(tc_code);
    assert(SvTYPE(cv) == SVt_PVCV);

    if(CvXSUB(cv) == XS_Mouse_constraint_check){ /* built-in type constraints */
        MAGIC* const mg = MOUSE_get_magic(aTHX_ cv, &mouse_util_type_constraints_vtbl);
#ifndef MULTIPLICITY
        assert(CvXSUBANY(cv).any_ptr != NULL);
#endif
        assert(mg->mg_ptr            != NULL);

        SvGETMAGIC(sv);
        /* call the check function directly, skipping call_sv() */
        return CALL_FPTR((check_fptr_t)mg->mg_ptr)(aTHX_ mg->mg_obj, sv);
    }
    else { /* custom */
        int ok;
        dSP;
        dMY_CXT;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(sv);
        if( MY_CXT.tc_extra_args ) {
            AV* const av  = MY_CXT.tc_extra_args;
            I32 const len = AvFILLp(av) + 1;
            int i;
            for(i = 0; i < len; i++) {
                XPUSHs( AvARRAY(av)[i] );
            }
        }
        PUTBACK;

        call_sv(tc_code, G_SCALAR);

        SPAGAIN;
        ok = sv_true(POPs);
        PUTBACK;

        FREETMPS;
        LEAVE;

        return ok;
    }
}

/*
    The following type check functions return an integer, not a bool, to keep
    the code simple,
    so if you assign these return value to a bool variable, you must use
    "expr ? TRUE : FALSE".
*/

int
mouse_tc_Any(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv PERL_UNUSED_DECL) {
    assert(sv);
    return TRUE;
}

int
mouse_tc_Bool(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);

    if(sv_true(sv)){
        if(SvPOKp(sv)){ /* "1" */
            return SvCUR(sv) == 1 && SvPVX(sv)[0] == '1';
        }
        else if(SvIOKp(sv)){
            return SvIVX(sv) == 1;
        }
        else if(SvNOKp(sv)){
            return SvNVX(sv) == 1.0;
        }
        else{
            STRLEN len;
            char * ptr = SvPV(sv, len);
            if(len == 1 && ptr[0] == '1'){
                return TRUE;
            } else {
                return FALSE;
            }
        }
    }
    else{
        /* any false value is a boolean */
        return TRUE;
    }
}

int
mouse_tc_Undef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return !SvOK(sv);
}

int
mouse_tc_Defined(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvOK(sv);
}

int
mouse_tc_Value(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvOK(sv) && !SvROK(sv);
}

int
mouse_tc_Num(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return LooksLikeNumber(sv);
}

static int
S_nv_is_integer(pTHX_ NV const nv) {
    if(nv == (NV)(IV)nv){
        return TRUE;
    }
    else {
        char buf[64];  /* Must fit sprintf/Gconvert of longest NV */
        const char* p;
        PERL_UNUSED_RESULT(Gconvert(nv, NV_DIG, 0, buf));
        p = &buf[0];

        /* -?[0-9]+ */
        if(*p == '-') p++;

        while(*p){
            if(!isDIGIT(*p)){
                return FALSE;
            }
            p++;
        }
        return TRUE;
    }
}

int
mouse_tc_Int(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    if(SvPOKp(sv)){
        int const num_type = grok_number(SvPVX(sv), SvCUR(sv), NULL);
        return num_type && !(num_type & IS_NUMBER_NOT_INT);
    }
    else if(SvIOKp(sv)){
        return TRUE;
    }
    else if(SvNOKp(sv)) {
        return S_nv_is_integer(aTHX_ SvNVX(sv));
    }
    return FALSE;
}

int
mouse_tc_Str(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvOK(sv) && !SvROK(sv) && !isGV(sv);
}

int
mouse_tc_ClassName(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv){
    assert(sv);
    return is_class_loaded(sv);
}

int
mouse_tc_RoleName(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    if(is_class_loaded(sv)){
        int ok;

        ENTER;
        SAVETMPS;

        ok = is_an_instance_of("Mouse::Meta::Role", get_metaclass(sv));

        FREETMPS;
        LEAVE;

        return ok;
    }
    return FALSE;
}

int
mouse_tc_Ref(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv);
}

int
mouse_tc_ScalarRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* sv) {
    assert(sv);
    if(SvROK(sv)){
         sv = SvRV(sv);
         return !SvOBJECT(sv) && (SvTYPE(sv) <= SVt_PVLV && !isGV(sv));
    }
    return FALSE;
}

int
mouse_tc_ArrayRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return IsArrayRef(sv);
}

int
mouse_tc_HashRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return IsHashRef(sv);
}

int
mouse_tc_CodeRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return IsCodeRef(sv);
}

int
mouse_tc_RegexpRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvRXOK(sv);
}

int
mouse_tc_GlobRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && isGV(SvRV(sv));
}

int
mouse_tc_FileHandle(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    GV* gv;
    assert(sv);

    /* see pp_fileno() in pp_sys.c and Scalar::Util::openhandle() */

    gv = (GV*)(SvROK(sv) ? SvRV(sv) : sv);
    if(isGV(gv) || SvTYPE(gv) == SVt_PVIO){
        IO* const io = isGV(gv) ? GvIO(gv) : (IO*)gv;

        if(io && ( IoIFP(io) || SvTIED_mg((SV*)io, PERL_MAGIC_tiedscalar) )){
            return TRUE;
        }
    }

    return is_an_instance_of("IO::Handle", sv);
}

int
mouse_tc_Object(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv) && SvOBJECT(SvRV(sv)) && !SvRXOK(sv);
}

/* Parameterized type constraints */

static int
mouse_parameterized_ArrayRef(pTHX_ SV* const param, SV* const sv) {
    if(IsArrayRef(sv)){
        AV* const av  = (AV*)SvRV(sv);
        I32 const len = av_len(av) + 1;
        I32 i;
        for(i = 0; i < len; i++){
            SV* const value = *av_fetch(av, i, TRUE);
            if(!mouse_tc_check(aTHX_ param, value)){
                return FALSE;
            }
        }
        return TRUE;
    }
    return FALSE;
}

static int
mouse_parameterized_HashRef(pTHX_ SV* const param, SV* const sv) {
    if(IsHashRef(sv)){
        HV* const hv  = (HV*)SvRV(sv);
        HE* he;

        hv_iterinit(hv);
        while((he = hv_iternext(hv))){
            SV* const value = hv_iterval(hv, he);
            if(!mouse_tc_check(aTHX_ param, value)){
                hv_iterinit(hv); /* reset */
                return FALSE;
            }
        }
        return TRUE;
    }
    return FALSE;
}

static int
mouse_parameterized_Maybe(pTHX_ SV* const param, SV* const sv) {
    if(SvOK(sv)){
        return mouse_tc_check(aTHX_ param, sv);
    }
    return TRUE;
}

static int
mouse_types_union_check(pTHX_ AV* const types, SV* const sv) {
    I32 const len = AvFILLp(types) + 1;
    I32 i;

    for(i = 0; i < len; i++){
        if(mouse_tc_check(aTHX_ AvARRAY(types)[i], sv)){
            return TRUE;
        }
    }

    return FALSE;
}

static int
mouse_types_check(pTHX_ AV* const types, SV* const sv) {
    I32 const len = AvFILLp(types) + 1;
    I32 i;

    ENTER;
    SAVE_DEFSV;
    DEFSV_set(sv);

    for(i = 0; i < len; i++){
        if(!mouse_tc_check(aTHX_ AvARRAY(types)[i], sv)){
            LEAVE;
            return FALSE;
        }
    }

    LEAVE;

    return TRUE;
}

/*
 *  This class_type generator is taken from Scalar::Util::Instance
 */


#define MG_klass_stash(mg) ((HV*)(mg)->mg_obj)
#define MG_klass_pv(mg)    ((mg)->mg_ptr)
#define MG_klass_len(mg)   ((mg)->mg_len)

static const char*
mouse_canonicalize_package_name(const char* name){

    /* "::Foo" -> "Foo" */
    if(name[0] == ':' && name[1] == ':'){
        name += 2;
    }

    /* "main::main::main::Foo" -> "Foo" */
    while(strnEQ(name, "main::", sizeof("main::")-1)){
        name += sizeof("main::")-1;
    }

    return name;
}

static int
mouse_lookup_isa(pTHX_ HV* const instance_stash, const char* const klass_pv){
    AV*  const linearized_isa = mro_get_linear_isa(instance_stash);
    SV**       svp            = AvARRAY(linearized_isa);
    SV** const end            = svp + AvFILLp(linearized_isa) + 1;

    while(svp != end){
        assert(SvPVX(*svp));
        if(strEQ(klass_pv, mouse_canonicalize_package_name(SvPVX(*svp)))){
            return TRUE;
        }
        svp++;
    }
    return FALSE;
}

#define find_method_pvn(a, b, c) mouse_stash_find_method(aTHX_ a, b, c)
#define find_method_pvs(a, b)    mouse_stash_find_method(aTHX_ a, STR_WITH_LEN(b))

STATIC_INLINE GV*
mouse_stash_find_method(pTHX_ HV* const stash, const char* const name, I32 const namelen){
    GV** const gvp = (GV**)hv_fetch(stash, name, namelen, FALSE);
    if(gvp && isGV(*gvp) && GvCV(*gvp)){ /* shortcut */
        return *gvp;
    }

    return gv_fetchmeth(stash, name, namelen, 0);
}

int
mouse_is_an_instance_of(pTHX_ HV* const stash, SV* const instance){
    assert(stash);
    assert(SvTYPE(stash) == SVt_PVHV);

    if(IsObject(instance)){
        dMY_CXT;
        HV* const instance_stash = SvSTASH(SvRV(instance));
        GV* const myisa          = find_method_pvs(instance_stash, "isa");

        /* the instance has no own isa method */
        if(myisa == NULL || GvCV(myisa) == GvCV(MY_CXT.universal_isa)){
            return stash == instance_stash
                || mouse_lookup_isa(aTHX_ instance_stash, HvNAME_get(stash));
        }
        /* the instance has its own isa method */
        else {
            SV* package;
            int ok;

            ENTER;
            SAVETMPS;

            package = newSVpvn_share(HvNAME_get(stash), HvNAMELEN_get(stash), 0U);
            ok = sv_true(mcall1s(instance, "isa", sv_2mortal(package)));

            FREETMPS;
            LEAVE;

            return ok;
        }
    }
    return FALSE;
}

static int
mouse_is_an_instance_of_universal(pTHX_ SV* const data, SV* const sv){
    PERL_UNUSED_ARG(data);
    return SvROK(sv) && SvOBJECT(SvRV(sv));
}

static int
mouse_can_methods(pTHX_ AV* const methods, SV* const instance){
    if(IsObject(instance)){
        dMY_CXT;
        HV* const mystash      = SvSTASH(SvRV(instance));
        GV* const mycan        = find_method_pvs(mystash, "can");
        bool const use_builtin = (mycan == NULL || GvCV(mycan) == GvCV(MY_CXT.universal_can)) ? TRUE : FALSE;
        I32 const len           = AvFILLp(methods) + 1;
        I32 i;
        for(i = 0; i < len; i++){
            SV* const name = MOUSE_av_at(methods, i);

            if(use_builtin){
                if(!find_method_pvn(mystash, SvPVX(name), SvCUR(name))){
                    return FALSE;
                }
            }
            else{
                bool ok;

                ENTER;
                SAVETMPS;

                ok = sv_true(mcall1s(instance, "can", sv_mortalcopy(name)));

                FREETMPS;
                LEAVE;

                if(!ok){
                    return FALSE;
                }
            }
        }
        return TRUE;
    }
    return FALSE;
}

static CV*
mouse_tc_generate(pTHX_ const char* const name, check_fptr_t const fptr, SV* const param) {
    CV* xsub;
    MAGIC* mg;

    xsub = newXS((const char*)name, XS_Mouse_constraint_check, __FILE__);
    mg = sv_magicext(
        (SV*)xsub,
        param,       /* mg_obj: refcnt will be increased */
        PERL_MAGIC_ext,
        &mouse_util_type_constraints_vtbl,
        (char*)fptr, /* mg_ptr */
        0            /* mg_len: 0 for static data */
    );
#ifndef MULTIPLICITY
    CvXSUBANY(xsub).any_ptr = (void*)mg;
#endif

    if(!name){
        sv_2mortal((SV*)xsub);
    }

    return xsub;
}

CV*
mouse_generate_isa_predicate_for(pTHX_ SV* const klass, const char* const predicate_name){
    STRLEN klass_len;
    const char* klass_pv = SvPV_const(klass, klass_len);
    SV*   param;
    check_fptr_t fptr;

    klass_pv = mouse_canonicalize_package_name(klass_pv);

    if(strNE(klass_pv, "UNIVERSAL")){
        param = (SV*)gv_stashpvn(klass_pv, klass_len, GV_ADD);
        fptr = (check_fptr_t)mouse_is_an_instance_of;

    }
    else{
        param = NULL;
        fptr = (check_fptr_t)mouse_is_an_instance_of_universal;
    }

    return mouse_tc_generate(aTHX_ predicate_name, fptr, param);
}

CV*
mouse_generate_can_predicate_for(pTHX_ SV* const methods, const char* const predicate_name){
    AV* av;
    AV* const param = newAV_mortal();
    I32 len;
    I32 i;

    must_ref(methods, "an ARRAY ref for method names", SVt_PVAV);
    av = (AV*)SvRV(methods);

    len = av_len(av) + 1;
    for(i = 0; i < len; i++){
        SV* const name = *av_fetch(av, i, TRUE);
        STRLEN pvlen;
        const char* const pv = SvPV_const(name, pvlen);

        av_push(param, newSVpvn_share(pv, pvlen, 0U));
    }

    return mouse_tc_generate(aTHX_ predicate_name, (check_fptr_t)mouse_can_methods, (SV*)param);
}

static
XSPROTO(XS_Mouse_constraint_check) {
    dVAR;
    dXSARGS;
    MAGIC* const mg = MOUSE_get_magic(aTHX_ cv, &mouse_util_type_constraints_vtbl);
    SV* sv;

    if(items < 1){
        croak("Too few arguments for type constraint check functions");
    }

    sv = ST(0);
    SvGETMAGIC(sv);
    ST(0) = boolSV( CALL_FPTR((check_fptr_t)mg->mg_ptr)(aTHX_ mg->mg_obj, sv) );
    XSRETURN(1);
}

static
XSPROTO(XS_Mouse_TypeConstraint_fallback) {
    dXSARGS;
    PERL_UNUSED_VAR(cv);
    PERL_UNUSED_VAR(items);
    XSRETURN_EMPTY;
}

static void
setup_my_cxt(pTHX_ pMY_CXT){
    MY_CXT.universal_isa = gv_fetchpvs("UNIVERSAL::isa", GV_ADD, SVt_PVCV);
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_isa);

    MY_CXT.universal_can = gv_fetchpvs("UNIVERSAL::can", GV_ADD, SVt_PVCV);
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_can);

    MY_CXT.tc_extra_args = NULL;
}

#define DEFINE_TC(name) mouse_tc_generate(aTHX_ "Mouse::Util::TypeConstraints::" STRINGIFY(name), CAT2(mouse_tc_, name), NULL)

#define MTC_CLASS "Mouse::Meta::TypeConstraint"

MODULE = Mouse::Util::TypeConstraints    PACKAGE = Mouse::Util::TypeConstraints

PROTOTYPES:   DISABLE
VERSIONCHECK: DISABLE

BOOT:
{
    MY_CXT_INIT;
    setup_my_cxt(aTHX_ aMY_CXT);

    /* setup built-in type constraints */
    DEFINE_TC(Any);
    DEFINE_TC(Undef);
    DEFINE_TC(Defined);
    DEFINE_TC(Bool);
    DEFINE_TC(Value);
    DEFINE_TC(Ref);
    DEFINE_TC(Str);
    DEFINE_TC(Num);
    DEFINE_TC(Int);
    DEFINE_TC(ScalarRef);
    DEFINE_TC(ArrayRef);
    DEFINE_TC(HashRef);
    DEFINE_TC(CodeRef);
    DEFINE_TC(GlobRef);
    DEFINE_TC(FileHandle);
    DEFINE_TC(RegexpRef);
    DEFINE_TC(Object);
    DEFINE_TC(ClassName);
    DEFINE_TC(RoleName);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    setup_my_cxt(aTHX_ aMY_CXT);
    PERL_UNUSED_VAR(items);
}

#endif /* !USE_ITHREADS */

#define MOUSE_TC_MAYBE     0
#define MOUSE_TC_ARRAY_REF 1
#define MOUSE_TC_HASH_REF  2

CV*
_parameterize_ArrayRef_for(SV* param)
ALIAS:
    _parameterize_ArrayRef_for = MOUSE_TC_ARRAY_REF
    _parameterize_HashRef_for  = MOUSE_TC_HASH_REF
    _parameterize_Maybe_for    = MOUSE_TC_MAYBE
CODE:
{
    check_fptr_t fptr;
    SV* const tc_code = mcall0s(param, "_compiled_type_constraint");
    if(!IsCodeRef(tc_code)){
        croak("_compiled_type_constraint didn't return a CODE reference");
    }

    switch(ix){
    case MOUSE_TC_ARRAY_REF:
        fptr = mouse_parameterized_ArrayRef;
        break;
    case MOUSE_TC_HASH_REF:
        fptr = mouse_parameterized_HashRef;
        break;
    default: /* Maybe type */
        fptr = mouse_parameterized_Maybe;
    }
    RETVAL = mouse_tc_generate(aTHX_ NULL, fptr, tc_code);
}
OUTPUT:
    RETVAL

MODULE = Mouse::Util::TypeConstraints    PACKAGE = Mouse::Meta::TypeConstraint

BOOT:
    INSTALL_SIMPLE_READER(TypeConstraint, name);
    INSTALL_SIMPLE_READER(TypeConstraint, parent);
    INSTALL_SIMPLE_READER(TypeConstraint, message);

    INSTALL_SIMPLE_READER(TypeConstraint, type_parameter);

    INSTALL_SIMPLE_READER_WITH_KEY(TypeConstraint, _compiled_type_constraint, compiled_type_constraint);

    INSTALL_SIMPLE_PREDICATE_WITH_KEY(TypeConstraint, has_coercion, _compiled_type_coercion);
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(TypeConstraint, __is_parameterized, type_parameter); /* Mouse specific */

    /* overload stuff */
    PL_amagic_generation++;
    (void)newXS( MTC_CLASS "::()",
        XS_Mouse_TypeConstraint_fallback, file);

    /* fallback => 1 */
    sv_setsv(
        get_sv( MTC_CLASS "::()", GV_ADD ),
        &PL_sv_yes
    );

    /* '""' => '_as_string' */
    {
        SV* const code_ref = sv_2mortal(newRV_inc(
            (SV*)get_cv( MTC_CLASS "::_as_string", GV_ADD )));
        sv_setsv_mg(
            (SV*)gv_fetchpvs( MTC_CLASS "::(\"\"", GV_ADDMULTI, SVt_PVCV ),
            code_ref );
    }

    /* '0+' => '_identity' */
    {
        SV* const code_ref = sv_2mortal(newRV_inc(
            (SV*)get_cv( MTC_CLASS "::_identity", GV_ADD )));
        sv_setsv_mg(
            (SV*)gv_fetchpvs( MTC_CLASS "::(0+", GV_ADDMULTI, SVt_PVCV ),
            code_ref );
    }

    /* '|' => '_unite' */
    {
        SV* const code_ref = sv_2mortal(newRV_inc(
            (SV*)get_cv( MTC_CLASS "::_unite", GV_ADD )));
        sv_setsv_mg(
            (SV*)gv_fetchpvs( MTC_CLASS "::(|", GV_ADDMULTI, SVt_PVCV ),
            code_ref );
    }

UV
_identity(SV* self, ...)
CODE:
{
    if(!SvROK(self)) {
        croak("Invalid object instance: '%"SVf"'", self);
    }
    RETVAL = PTR2UV(SvRV(self));
}
OUTPUT:
    RETVAL

void
compile_type_constraint(SV* self)
CODE:
{
    AV* const checks = newAV_mortal();
    SV* check; /* check function */
    SV* parent;
    SV* types_ref;

    for(parent = get_slots(self, "parent"); parent; parent = get_slots(parent, "parent")){
        check = get_slots(parent, "hand_optimized_type_constraint");
        if(check && SvOK(check)){
            if(!IsCodeRef(check)){
                croak("Not a CODE reference");
            }
            av_unshift(checks, 1);
            av_store(checks, 0, newSVsv(check));
            break; /* a hand optimized constraint must include all the parent */
        }

        check = get_slots(parent, "constraint");
        if(check && SvOK(check)){
            if(!mouse_tc_CodeRef(aTHX_ NULL, check)){
                croak("Not a CODE reference");
            }
            av_unshift(checks, 1);
            av_store(checks, 0, newSVsv(check));
        }
    }

    check = get_slots(self, "constraint");
    if(check && SvOK(check)){
        if(!mouse_tc_CodeRef(aTHX_ NULL, check)){
            croak("Not a CODE reference");
        }
        av_push(checks, newSVsv(check));
    }

    types_ref = get_slots(self, "type_constraints");
    if(types_ref && SvOK(types_ref)){ /* union type */
        AV* types;
        AV* union_checks;
        CV* union_check;
        I32 len;
        I32 i;

        if(!IsArrayRef(types_ref)){
            croak("Not an ARRAY reference");
        }
        types = (AV*)SvRV(types_ref);
        len = av_len(types) + 1;

        union_checks = newAV_mortal();

        for(i = 0; i < len; i++){
            SV* const tc = *av_fetch(types, i, TRUE);
            SV* const c  = get_slots(tc, "compiled_type_constraint");
            if(!(c && mouse_tc_CodeRef(aTHX_ NULL, c))){
                mouse_throw_error(self, c, "'%"SVf"' has no compiled type constraint", self);
            }
            av_push(union_checks, newSVsv(c));
        }

        union_check = mouse_tc_generate(aTHX_ NULL, (check_fptr_t)mouse_types_union_check, (SV*)union_checks);
        av_push(checks, newRV_inc((SV*)union_check));
    }

    if(AvFILLp(checks) < 0){
        check = newRV_inc((SV*)get_cv("Mouse::Util::TypeConstraints::Any", TRUE));
    }
    else{
        check = newRV_inc((SV*)mouse_tc_generate(aTHX_ NULL, (check_fptr_t)mouse_types_check, (SV*)checks));
    }
    (void)set_slots(self, "compiled_type_constraint", check);
}

bool
check(SV* self, SV* sv, ...)
CODE:
{
    SV* const check = get_slots(self, "compiled_type_constraint");
    if(!(check && IsCodeRef(check))){
        mouse_throw_error(self, check,
            "'%"SVf"' has no compiled type constraint", self);
    }
    if( items > 2 ) {
        int i;
        AV* av;
        dMY_CXT;
        SAVESPTR(MY_CXT.tc_extra_args);
        av = MY_CXT.tc_extra_args = newAV_mortal();
        av_extend(av, items - 3);
        for(i = 2; i < items; i++) {
            av_push(av, SvREFCNT_inc_NN( ST(i) ) );
        }
    }
    RETVAL = mouse_tc_check(aTHX_ check, sv) ? TRUE : FALSE;
}
OUTPUT:
    RETVAL

