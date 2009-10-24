#include "mouse.h"

/* equivalent to "blessed($x) && $x->isa($klass)" */
bool
mouse_is_instance_of(pTHX_ SV* const sv, SV* const klass){
    assert(sv);
    assert(klass);

    if(IsObject(sv) && SvOK(klass)){
        bool ok;

        ENTER;
        SAVETMPS;

        ok = SvTRUEx(mcall1s(sv, "isa", klass));

        FREETMPS;
        LEAVE;

        return ok;
    }

    return FALSE;
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


SV *
mouse_call0 (pTHX_ SV *const self, SV *const method)
{
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

SV *
mouse_call1 (pTHX_ SV *const self, SV *const method, SV* const arg1)
{
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

