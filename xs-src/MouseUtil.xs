#include "mouse.h"

#define MY_CXT_KEY "Mouse::Util::_guts" XS_VERSION
typedef struct {
    HV* metas;
} my_cxt_t;
START_MY_CXT

#define ISA_CACHE "::LINEALIZED_ISA_CACHE::"

#ifdef no_mro_get_linear_isa
AV*
mouse_mro_get_linear_isa(pTHX_ HV* const stash){
    GV* const cachegv = *(GV**)hv_fetchs(stash, ISA_CACHE, TRUE);
    AV* isa;
    SV* gen;
    CV* get_linear_isa;

    if(!isGV(cachegv))
        gv_init(cachegv, stash, ISA_CACHE, sizeof(ISA_CACHE)-1, TRUE);

    isa = GvAVn(cachegv);
    gen = GvSVn(cachegv);


    if(SvIOK(gen) && SvIVX(gen) == (IV)mro_get_pkg_gen(stash)){
        return isa; /* returns the cache if available */
    }
    else{
        SvREFCNT_dec(isa);
        GvAV(cachegv) = isa = newAV();
    }

    get_linear_isa = get_cv("Mouse::Util::get_linear_isa", TRUE);

    {
        SV* avref;
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        mXPUSHp(HvNAME_get(stash), HvNAMELEN_get(stash));
        PUTBACK;

        call_sv((SV*)get_linear_isa, G_SCALAR);

        SPAGAIN;
        avref = POPs;
        PUTBACK;

        if(IsArrayRef(avref)){
            AV* const av  = (AV*)SvRV(avref);
            I32 const len = AvFILLp(av) + 1;
            I32 i;

            for(i = 0; i < len; i++){
                HV* const stash = gv_stashsv(AvARRAY(av)[i], FALSE);
                if(stash)
                    av_push(isa, newSVpv(HvNAME(stash), 0));
            }
            SvREADONLY_on(isa);
        }
        else{
            Perl_croak(aTHX_ "Mouse:Util::get_linear_isa() didn't return an ARRAY reference");
        }

        FREETMPS;
        LEAVE;
    }

    sv_setiv(gen, (IV)mro_get_pkg_gen(stash));
    return isa;
}
#endif /* !no_mor_get_linear_isa */

#ifdef DEBUGGING
SV**
mouse_av_at_safe(pTHX_ AV* const av, I32 const ix){
    assert(av);
    assert(SvTYPE(av) == SVt_PVAV);
    assert(AvMAX(av) >= ix);
    return &AvARRAY(av)[ix];
}
#endif

void
mouse_throw_error(SV* const metaobject, SV* const data /* not used */, const char* const fmt, ...){
    dTHX;
    va_list args;
    SV* message;

    PERL_UNUSED_ARG(data); /* for moose-compat */

    assert(metaobject);
    assert(fmt);

    va_start(args, fmt);
    message = vnewSVpvf(fmt, &args);
    va_end(args);

    {
        dSP;
        PUSHMARK(SP);
        EXTEND(SP, 4);

        PUSHs(metaobject);
        mPUSHs(message);

        mPUSHs(newSVpvs("depth"));
        mPUSHi(-1);

        PUTBACK;

        call_method("throw_error", G_VOID);
        croak("throw_error() did not throw the error (%"SVf")", message);
    }
}

bool
mouse_is_class_loaded(pTHX_ SV * const klass){
    HV *stash;
    GV** gvp;
    HE* he;

    if (!(SvPOKp(klass) && SvCUR(klass))) { /* XXX: SvPOK does not work with magical scalars */
        return FALSE;
    }

    stash = gv_stashsv(klass, FALSE);
    if (!stash) {
        return FALSE;
    }

    if (( gvp = (GV**)hv_fetchs(stash, "VERSION", FALSE) )) {
        if(isGV(*gvp) && GvSV(*gvp) && SvOK(GvSV(*gvp))){
            return TRUE;
        }
    }

    if (( gvp = (GV**)hv_fetchs(stash, "ISA", FALSE) )) {
        if(isGV(*gvp) && GvAV(*gvp) && av_len(GvAV(*gvp)) != -1){
            return TRUE;
        }
    }

    hv_iterinit(stash);
    while(( he = hv_iternext(stash) )){
        GV* const gv = (GV*)HeVAL(he);

        if(isGV(gv)){
            if(GvCVu(gv)){
                return TRUE;
            }
        }
        else if(SvOK(gv)){
            return TRUE;
        }
    }
    return FALSE;
}


SV*
mouse_call0 (pTHX_ SV* const self, SV* const method) {
    dSP;
    SV *ret;

    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(method, G_SCALAR | G_METHOD);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return ret;
}

SV*
mouse_call1 (pTHX_ SV* const self, SV* const method, SV* const arg1) {
    dSP;
    SV *ret;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(self);
    PUSHs(arg1);
    PUTBACK;

    call_sv(method, G_SCALAR | G_METHOD);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return ret;
}

int
mouse_predicate_call(pTHX_ SV* const self, SV* const method) {
    return sv_true( mcall0(self, method) );
}

SV*
mouse_get_metaclass(pTHX_ SV* metaclass_name){
    dMY_CXT;
    HE* he;

    assert(metaclass_name);
    assert(MY_CXT.metas);

    if(IsObject(metaclass_name)){
        HV* const stash = SvSTASH(SvRV(metaclass_name));

        metaclass_name = newSVpvn_share(HvNAME_get(stash), HvNAMELEN_get(stash), 0U);
        sv_2mortal(metaclass_name);
    }

    he = hv_fetch_ent(MY_CXT.metas, metaclass_name, FALSE, 0U);

    return he ? HeVAL(he) : &PL_sv_undef;
}

MAGIC*
mouse_mg_find(pTHX_ SV* const sv, const MGVTBL* const vtbl, I32 const flags){
    MAGIC* mg;

    assert(sv != NULL);
    for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
        if(mg->mg_virtual == vtbl){
            return mg;
        }
    }

    if(flags & MOUSEf_DIE_ON_FAIL){
        croak("mouse_mg_find: no MAGIC found for %"SVf, sv_2mortal(newRV_inc(sv)));
    }
    return NULL;
}

GV*
mouse_stash_fetch(pTHX_ HV* const stash, const char* const name, I32 const namelen, I32 const create) {
    GV** const gvp = (GV**)hv_fetch(stash, name, namelen, create);

    if(gvp){
        if(!isGV(*gvp)){
            gv_init(*gvp, stash, name, namelen, GV_ADDMULTI);
        }
        return *gvp;
    }
    else{
        return NULL;
    }
}

MODULE = Mouse::Util  PACKAGE = Mouse::Util

PROTOTYPES:   DISABLE
VERSIONCHECK: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.metas = NULL;
}

void
__register_metaclass_storage(HV* metas, bool cloning)
CODE:
{
    if(cloning){
        MY_CXT_CLONE;
        MY_CXT.metas = NULL;
    }
    {
        dMY_CXT;
        if(MY_CXT.metas) croak("Cannot set metaclass storage more than once");
        MY_CXT.metas = metas;
        SvREFCNT_inc_simple_void_NN(metas);
    }
}

bool
is_class_loaded(SV* sv)

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
    STRLEN name_len;
    const char* name_pv;
    GV* gv;

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

    name_pv = SvPV_const(name, name_len);
    gv = stash_fetch(stash, name_pv, name_len, FALSE);
    RETVAL = gv ? GvCVu(gv) : NULL;

    if(!RETVAL){
        XSRETURN_UNDEF;
    }
}
OUTPUT:
    RETVAL

void
generate_isa_predicate_for(SV* arg, SV* predicate_name = NULL)
ALIAS:
    generate_isa_predicate_for = 0
    generate_can_predicate_for = 1
PPCODE:
{
    const char* name_pv = NULL;
    CV* xsub;

    SvGETMAGIC(arg);

    if(!SvOK(arg)){
        croak("You must define %s", ix == 0 ? "a class name" : "method names");
    }

    if(predicate_name){
        SvGETMAGIC(predicate_name);
        if(!SvOK(predicate_name)){
            croak("You must define %s", "a predicate name");
        }
        name_pv = SvPV_nolen_const(predicate_name);
    }

    if(ix == 0){
        xsub = mouse_generate_isa_predicate_for(aTHX_ arg, name_pv);
    }
    else{
        xsub = mouse_generate_can_predicate_for(aTHX_ arg, name_pv);
    }

    if(predicate_name == NULL){ /* anonymous predicate */
        mXPUSHs( newRV_inc((SV*)xsub) );
    }
}
