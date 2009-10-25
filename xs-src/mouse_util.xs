#include "mouse.h"

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
		SvREADONLY_off(isa);
		av_clear(isa);
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

		if(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV){
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
	return GvAV(cachegv);
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
