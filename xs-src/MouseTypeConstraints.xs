/*
 *   full definition of built-in type constraints (ware in Moose::Util::TypeConstraints::OptimizedConstraints)
 */

#include "mouse.h"

#if PERL_BCDVERSION >= 0x5008005
#define LooksLikeNumber(sv) looks_like_number(sv)
#else
#define LooksLikeNumber(sv) ( SvPOKp(sv) ? looks_like_number(sv) : SvNIOKp(sv) )
#endif

#ifndef SvRXOK
#define SvRXOK(sv) (SvROK(sv) && SvMAGICAL(SvRV(sv)) && mg_find(SvRV(sv), PERL_MAGIC_qr))
#endif

typedef int (*check_fptr_t)(pTHX_ SV* const data, SV* const sv);

int
mouse_tc_check(pTHX_ SV* const tc_code, SV* const sv) {
    CV* const cv = (CV*)SvRV(tc_code);
    assert(SvTYPE(cv) == SVt_PVCV);

    if(CvXSUB(cv) == XS_Mouse_constraint_check){ /* built-in type constraints */
        MAGIC* const mg = (MAGIC*)CvXSUBANY(cv).any_ptr;

        assert(CvXSUBANY(cv).any_ptr != NULL);
        assert(mg->mg_ptr            != NULL);

        /* call the check function directly, skipping call_sv() */
        return CALL_FPTR((check_fptr_t)mg->mg_ptr)(aTHX_ mg->mg_obj, sv);
    }
    else { /* custom */
        int ok;
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(sv);
        PUTBACK;

        call_sv(tc_code, G_SCALAR);

        SPAGAIN;
        ok = SvTRUEx(POPs);
        PUTBACK;

        FREETMPS;
        LEAVE;

        return ok;
    }
}

/*
    The following type check functions return an integer, not a bool, to keep them simple,
    so if you assign these return value to bool variable, you must use "expr ? TRUE : FALSE".
*/

int
mouse_tc_Any(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv PERL_UNUSED_DECL) {
    assert(sv);
    return TRUE;
}

int
mouse_tc_Bool(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);

    if(SvTRUE(sv)){
        if(SvIOKp(sv)){
            return SvIVX(sv) == 1;
        }
        else if(SvNOKp(sv)){
            return SvNVX(sv) == 1.0;
        }
        else if(SvPOKp(sv)){ /* "1" */
            return SvCUR(sv) == 1 && SvPVX(sv)[0] == '1';
        }
        else{
            return FALSE;
        }
    }
    else{
        /* false must be boolean */
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

int
mouse_tc_Int(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    if(SvIOKp(sv)){
        return TRUE;
    }
    else if(SvNOKp(sv)){
        NV const nv = SvNVX(sv);
        return nv > 0 ? (nv == (NV)(UV)nv) : (nv == (NV)(IV)nv);
    }
    else if(SvPOKp(sv)){
        int const num_type = grok_number(SvPVX(sv), SvCUR(sv), NULL);
        if(num_type){
            return !(num_type & IS_NUMBER_NOT_INT);
        }
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
        SV* meta;
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(sv);
        PUTBACK;
        call_pv("Mouse::Util::get_metaclass_by_name", G_SCALAR);
        SPAGAIN;
        meta = POPs;
        PUTBACK;

        ok =  is_an_instance_of("Mouse::Meta::Role", meta);

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
mouse_tc_ScalarRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && (SvTYPE(SvRV(sv)) <= SVt_PVLV && !isGV(SvRV(sv)));
}

int
mouse_tc_ArrayRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVAV;
}

int
mouse_tc_HashRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVHV;
}

int
mouse_tc_CodeRef(pTHX_ SV* const data PERL_UNUSED_DECL, SV* const sv) {
    assert(sv);
    return SvROK(sv)  && !SvOBJECT(SvRV(sv))&& SvTYPE(SvRV(sv)) == SVt_PVCV;
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
    if(mouse_tc_ArrayRef(aTHX_ NULL, sv)){
        AV* const av  = (AV*)SvRV(sv);
        I32 const len = av_len(av) + 1;
        I32 i;
        for(i = 0; i < len; i++){
            SV* const value = *av_fetch(av, i, TRUE);
            SvGETMAGIC(value);
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
    if(mouse_tc_HashRef(aTHX_ NULL, sv)){
        HV* const hv  = (HV*)SvRV(sv);
        HE* he;

        hv_iterinit(hv);
        while((he = hv_iternext(hv))){
            SV* const value = hv_iterval(hv, he);
            SvGETMAGIC(value);
            if(!mouse_tc_check(aTHX_ param, value)){
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

#define MY_CXT_KEY "Mouse::Util::TypeConstraints::_guts" XS_VERSION
typedef struct sui_cxt{
    GV* universal_isa;
} my_cxt_t;
START_MY_CXT

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

int
mouse_is_an_instance_of(pTHX_ HV* const stash, SV* const instance){
    assert(stash);
    assert(SvTYPE(stash) == SVt_PVHV);

    if(IsObject(instance)){
        dMY_CXT;
        HV* const instance_stash = SvSTASH(SvRV(instance));
        GV* const instance_isa   = gv_fetchmeth_autoload(instance_stash, "isa", sizeof("isa")-1, 0);

        /* the instance has no own isa method */
        if(instance_isa == NULL || GvCV(instance_isa) == GvCV(MY_CXT.universal_isa)){
            return stash == instance_stash
                || mouse_lookup_isa(aTHX_ instance_stash, HvNAME_get(stash));
        }
        /* the instance has its own isa method */
        else {
            int retval;
            dSP;

            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            EXTEND(SP, 2);
            PUSHs(instance);
            mPUSHp(HvNAME_get(stash), HvNAMELEN_get(stash));
            PUTBACK;

            call_sv((SV*)instance_isa, G_SCALAR);

            SPAGAIN;

            retval = SvTRUEx(POPs);

            PUTBACK;

            FREETMPS;
            LEAVE;

            return retval;
        }
    }
    return FALSE;
}

static int
mouse_is_an_instance_of_universal(pTHX_ SV* const data, SV* const sv){
    PERL_UNUSED_ARG(data);
    return SvROK(sv) && SvOBJECT(SvRV(sv));
}

static MGVTBL mouse_util_type_constraints_vtbl; /* not used, only for identity */

static CV*
mouse_tc_generate(pTHX_ const char* const name, check_fptr_t const fptr, SV* const param) {
    CV* xsub;

    xsub = newXS(name, XS_Mouse_constraint_check, __FILE__);
    CvXSUBANY(xsub).any_ptr = sv_magicext(
        (SV*)xsub,
        param,       /* mg_obj: refcnt will be increased */
        PERL_MAGIC_ext,
        &mouse_util_type_constraints_vtbl,
        (void*)fptr, /* mg_ptr */
        0            /* mg_len: 0 for static data */
    );

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
    void* fptr;

    klass_pv = mouse_canonicalize_package_name(klass_pv);

    if(strNE(klass_pv, "UNIVERSAL")){
        param = (SV*)gv_stashpvn(klass_pv, klass_len, GV_ADD);
        fptr = (void*)mouse_is_an_instance_of;

    }
    else{
        param = NULL;
        fptr = (void*)mouse_is_an_instance_of_universal;
    }

    return mouse_tc_generate(aTHX_ predicate_name, fptr, param);
}

XS(XS_Mouse_constraint_check) {
    dVAR;
    dXSARGS;
    MAGIC* const mg = (MAGIC*)XSANY.any_ptr;

    if(items < 1){
        croak("Too few arguments for type constraint check functions");
    }

    SvGETMAGIC( ST(0) );
    ST(0) = boolSV( CALL_FPTR((check_fptr_t)mg->mg_ptr)(aTHX_ mg->mg_obj, ST(0)) );
    XSRETURN(1);
}

static void
setup_my_cxt(pTHX_ pMY_CXT){
    MY_CXT.universal_isa = gv_fetchpvs("UNIVERSAL::isa", GV_ADD, SVt_PVCV);
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_isa);
}

#define DEFINE_TC(name) mouse_tc_generate(aTHX_ "Mouse::Util::TypeConstraints::" STRINGIFY(name), CAT2(mouse_tc_, name), NULL)

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
    if(!(SvROK(tc_code) && SvTYPE(SvRV(tc_code)) == SVt_PVCV)){
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

void
compile_type_constraint(SV* self)
CODE:
{
    AV* const checks = newAV();
    SV* check; /* check function */
    SV* parent;
    SV* types_ref;

    sv_2mortal((SV*)checks);

    for(parent = get_slots(self, "parent"); parent; parent = get_slots(parent, "parent")){
        check = get_slots(parent, "hand_optimized_type_constraint");
        if(check && SvOK(check)){
            if(!mouse_tc_CodeRef(aTHX_ NULL, check)){
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

        if(!mouse_tc_ArrayRef(aTHX_ NULL, types_ref)){
            croak("Not an ARRAY reference");
        }
        types = (AV*)SvRV(types_ref);
        len = av_len(types) + 1;

        union_checks = newAV();
        sv_2mortal((SV*)union_checks);

        for(i = 0; i < len; i++){
            SV* const tc = *av_fetch(types, i, TRUE);
            SV* const c  = get_slots(tc, "compiled_type_constraint");
            if(!(c && mouse_tc_CodeRef(aTHX_ NULL, c))){
                sv_dump(self);
                croak("'%"SVf"' has no compiled type constraint", self);
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
    set_slots(self, "compiled_type_constraint", check);
}

