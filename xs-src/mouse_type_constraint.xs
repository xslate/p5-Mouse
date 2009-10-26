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
mouse_tc_check(pTHX_ mouse_tc const tc, SV* const sv) {
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

