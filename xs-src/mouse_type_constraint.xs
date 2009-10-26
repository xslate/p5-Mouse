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

int
mouse_tc_check(pTHX_ SV* const tc_code, SV* const sv) {
    if(SvIOK(tc_code)){ /* built-in type constraints */
        return mouse_builtin_tc_check(aTHX_ SvIVX(tc_code), sv);
    }
    else {
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

int
mouse_builtin_tc_check(pTHX_ mouse_tc const tc, SV* const sv) {
    switch(tc){
    case MOUSE_TC_ANY:        return mouse_tc_Any(aTHX_ sv);
    case MOUSE_TC_ITEM:       return mouse_tc_Any(aTHX_ sv);
    case MOUSE_TC_UNDEF:      return mouse_tc_Undef(aTHX_ sv);
    case MOUSE_TC_DEFINED:    return mouse_tc_Defined(aTHX_ sv);
    case MOUSE_TC_BOOL:       return mouse_tc_Bool(aTHX_ sv);
    case MOUSE_TC_VALUE:      return mouse_tc_Value(aTHX_ sv);
    case MOUSE_TC_REF:        return mouse_tc_Ref(aTHX_ sv);
    case MOUSE_TC_STR:        return mouse_tc_Str(aTHX_ sv);
    case MOUSE_TC_NUM:        return mouse_tc_Num(aTHX_ sv);
    case MOUSE_TC_INT:        return mouse_tc_Int(aTHX_ sv);
    case MOUSE_TC_SCALAR_REF: return mouse_tc_ScalarRef(aTHX_ sv);
    case MOUSE_TC_ARRAY_REF:  return mouse_tc_ArrayRef(aTHX_ sv);
    case MOUSE_TC_HASH_REF:   return mouse_tc_HashRef(aTHX_ sv);
    case MOUSE_TC_CODE_REF:   return mouse_tc_CodeRef(aTHX_ sv);
    case MOUSE_TC_GLOB_REF:   return mouse_tc_GlobRef(aTHX_ sv);
    case MOUSE_TC_FILEHANDLE: return mouse_tc_FileHandle(aTHX_ sv);
    case MOUSE_TC_REGEXP_REF: return mouse_tc_RegexpRef(aTHX_ sv);
    case MOUSE_TC_OBJECT:     return mouse_tc_Object(aTHX_ sv);
    case MOUSE_TC_CLASS_NAME: return mouse_tc_ClassName(aTHX_ sv);
    case MOUSE_TC_ROLE_NAME:  return mouse_tc_RoleName(aTHX_ sv);
    default:
        /* custom type constraints */
        NOOP;
    }

    croak("Custom type constraint is not yet implemented");
    return FALSE; /* not reached */
}


/*
    The following type check functions return an integer, not a bool, to keep them simple,
    so if you assign these return value to bool variable, you must use "expr ? TRUE : FALSE".
*/

int
mouse_tc_Any(pTHX_ SV* const sv PERL_UNUSED_DECL) {
    assert(sv);
    return TRUE;
}

int
mouse_tc_Bool(pTHX_ SV* const sv) {
    assert(sv);
    if(SvOK(sv)){
        if(SvIOKp(sv)){
            return SvIVX(sv) == 1 || SvIVX(sv) == 0;
        }
        else if(SvNOKp(sv)){
            return SvNVX(sv) == 1.0 || SvNVX(sv) == 0.0;
        }
        else if(SvPOKp(sv)){ /* "" or "1" or "0" */
            return SvCUR(sv) == 0
                || ( SvCUR(sv) == 1 && ( SvPVX(sv)[0] == '1' || SvPVX(sv)[0] == '0' ) );
        }
        else{
            return FALSE;
        }
    }
    else{
        return TRUE;
    }
}

int
mouse_tc_Undef(pTHX_ SV* const sv) {
    assert(sv);
    return !SvOK(sv);
}

int
mouse_tc_Defined(pTHX_ SV* const sv) {
    assert(sv);
    return SvOK(sv);
}

int
mouse_tc_Value(pTHX_ SV* const sv) {
    assert(sv);
    return SvOK(sv) && !SvROK(sv);
}

int
mouse_tc_Num(pTHX_ SV* const sv) {
    assert(sv);
    return LooksLikeNumber(sv);
}

int
mouse_tc_Int(pTHX_ SV* const sv) {
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
mouse_tc_Str(pTHX_ SV* const sv) {
    assert(sv);
    return SvOK(sv) && !SvROK(sv) && !isGV(sv);
}

int
mouse_tc_ClassName(pTHX_ SV* const sv){ 
    assert(sv);
    return is_class_loaded(sv);
}

int
mouse_tc_RoleName(pTHX_ SV* const sv) {
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

        ok =  is_instance_of(meta, newSVpvs_flags("Mouse::Meta::Role", SVs_TEMP));

        FREETMPS;
        LEAVE;

        return ok;
    }
    return FALSE;
}

int
mouse_tc_Ref(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv);
}

int
mouse_tc_ScalarRef(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && (SvTYPE(SvRV(sv)) <= SVt_PVLV && !isGV(SvRV(sv)));
}

int
mouse_tc_ArrayRef(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVAV;
}

int
mouse_tc_HashRef(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVHV;
}

int
mouse_tc_CodeRef(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv)  && !SvOBJECT(SvRV(sv))&& SvTYPE(SvRV(sv)) == SVt_PVCV;
}

int
mouse_tc_RegexpRef(pTHX_ SV* const sv) {
    assert(sv);
    return SvRXOK(sv);
}

int
mouse_tc_GlobRef(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && !SvOBJECT(SvRV(sv)) && isGV(SvRV(sv));
}

int
mouse_tc_FileHandle(pTHX_ SV* const sv) {
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

    return is_instance_of(sv, newSVpvs_flags("IO::Handle", SVs_TEMP));
}

int
mouse_tc_Object(pTHX_ SV* const sv) {
    assert(sv);
    return SvROK(sv) && SvOBJECT(SvRV(sv)) && !SvRXOK(sv);
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

static MGVTBL mouse_util_type_constraints_vtbl;

static const char*
canonicalize_package_name(const char* name){

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
lookup_isa(pTHX_ HV* const instance_stash, const char* const klass_pv){
    AV*  const linearized_isa = mro_get_linear_isa(instance_stash);
    SV**       svp            = AvARRAY(linearized_isa);
    SV** const end            = svp + AvFILLp(linearized_isa) + 1;

    while(svp != end){
        assert(SvPVX(*svp));
        if(strEQ(klass_pv, canonicalize_package_name(SvPVX(*svp)))){
            return TRUE;
        }
        svp++;
    }
    return FALSE;
}

static int
instance_isa(pTHX_ SV* const instance, const MAGIC* const mg){
    dMY_CXT;
    HV* const instance_stash = SvSTASH(SvRV(instance));
    GV* const instance_isa   = gv_fetchmeth_autoload(instance_stash, "isa", sizeof("isa")-1, 0);

    /* the instance has no own isa method */
    if(instance_isa == NULL || GvCV(instance_isa) == GvCV(MY_CXT.universal_isa)){
        return MG_klass_stash(mg) == instance_stash
            || lookup_isa(aTHX_ instance_stash, MG_klass_pv(mg));
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
        mPUSHp(MG_klass_pv(mg), MG_klass_len(mg));
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

XS(XS_isa_check); /* -W */
XS(XS_isa_check){
    dVAR;
    dXSARGS;
    SV* sv;

    assert(XSANY.any_ptr != NULL);

    if(items != 1){
        if(items < 1){
            croak("Not enough arguments for is-a predicate");
        }
        else{
            croak("Too many arguments for is-a predicate");
        }
    }

    sv = ST(0);
    SvGETMAGIC(sv);

    ST(0) = boolSV( SvROK(sv) && SvOBJECT(SvRV(sv)) && instance_isa(aTHX_ sv, (MAGIC*)XSANY.any_ptr) );
    XSRETURN(1);
}

XS(XS_isa_check_for_universal); /* -W */
XS(XS_isa_check_for_universal){
    dVAR;
    dXSARGS;
    SV* sv;
    PERL_UNUSED_VAR(cv);

    if(items != 1){
        if(items < 1){
            croak("Not enough arguments for is-a predicate");
        }
        else{
            croak("Too many arguments for is-a predicate");
        }
    }

    sv = ST(0);
    SvGETMAGIC(sv);

    ST(0) = boolSV( SvROK(sv) && SvOBJECT(SvRV(sv)) );
    XSRETURN(1);
}

static void
setup_my_cxt(pTHX_ pMY_CXT){
    MY_CXT.universal_isa = gv_fetchpvs("UNIVERSAL::isa", GV_ADD, SVt_PVCV);
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_isa);
}

MODULE = Mouse::Util::TypeConstraints    PACKAGE = Mouse::Util::TypeConstraints

PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    setup_my_cxt(aTHX_ aMY_CXT);
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

void
_generate_class_type_for(SV* klass, const char* predicate_name = NULL)
PPCODE:
{
    STRLEN klass_len;
    const char* klass_pv;
    HV* stash;
    CV* xsub;

    if(!SvOK(klass)){
        croak("You must define a class name for generate_for");
    }
    klass_pv = SvPV_const(klass, klass_len);
    klass_pv = canonicalize_package_name(klass_pv);

    if(strNE(klass_pv, "UNIVERSAL")){
        xsub = newXS(predicate_name, XS_isa_check, __FILE__);

        stash = gv_stashpvn(klass_pv, klass_len, GV_ADD);

        CvXSUBANY(xsub).any_ptr = sv_magicext(
            (SV*)xsub,
            (SV*)stash, /* mg_obj */
            PERL_MAGIC_ext,
            &mouse_util_type_constraints_vtbl,
            klass_pv,   /* mg_ptr */
            klass_len   /* mg_len */
        );
    }
    else{
        xsub = newXS(predicate_name, XS_isa_check_for_universal, __FILE__);
    }

    if(predicate_name == NULL){ /* anonymous predicate */
        XPUSHs( newRV_noinc((SV*)xsub) );
    }
}

void
Item(SV* sv = &PL_sv_undef)
ALIAS:
    Any        = MOUSE_TC_ANY
    Item       = MOUSE_TC_ITEM
    Undef      = MOUSE_TC_UNDEF
    Defined    = MOUSE_TC_DEFINED
    Bool       = MOUSE_TC_BOOL
    Value      = MOUSE_TC_VALUE
    Ref        = MOUSE_TC_REF
    Str        = MOUSE_TC_STR
    Num        = MOUSE_TC_NUM
    Int        = MOUSE_TC_INT
    ScalarRef  = MOUSE_TC_SCALAR_REF
    ArrayRef   = MOUSE_TC_ARRAY_REF
    HashRef    = MOUSE_TC_HASH_REF
    CodeRef    = MOUSE_TC_CODE_REF
    GlobRef    = MOUSE_TC_GLOB_REF
    FileHandle = MOUSE_TC_FILEHANDLE
    RegexpRef  = MOUSE_TC_REGEXP_REF
    Object     = MOUSE_TC_OBJECT
    ClassName  = MOUSE_TC_CLASS_NAME
    RoleName   = MOUSE_TC_ROLE_NAME
CODE:
    SvGETMAGIC(sv);
    ST(0) = boolSV( mouse_builtin_tc_check(aTHX_ ix, sv) );
    XSRETURN(1);


