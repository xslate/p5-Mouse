/*
----------------------------------------------------------------------------

    Devel::MRO/mro_compat.h - Provides mro functions for XS modules

    Copyright (c) 2008-2009, Goro Fuji (gfx) <gfuji(at)cpan.org>.

    This program is free software; you can redistribute it and/or
    modify it under the same terms as Perl itself.

----------------------------------------------------------------------------

Usage:
	#include "mro_compat.h"

Functions:
	AV*  mro_get_linear_isa(HV* stash)
	UV   mro_get_pkg_gen(HV* stash)
	void mro_method_changed_in(HV* stash)


    See "perldoc Devel::MRO" for details.
 */


#ifdef mro_get_linear_isa /* >= 5.10.0 */

/* NOTE:
	Because ActivePerl 5.10.0 does not provide Perl_mro_meta_init(), 
	which is used in HvMROMETA() macro, this mro_get_pkg_gen() refers
	to xhv_mro_meta directly.
*/
/* compatible with &mro::get_pkg_gen() */
#ifndef mro_get_pkg_gen
#define mro_get_pkg_gen(stash) (HvAUX(stash) ? HvAUX(stash)->xhv_mro_meta->pkg_gen : (U32)0)
#endif

#ifndef mro_get_cache_gen
#define mro_get_cache_gen(stash) (HvAUX(stash) ? HvAUX(stash)->xhv_mro_meta->cache_gen : (U32)0)
#endif

#ifndef mro_get_gen
#define mro_get_gen(stash) (HvAUX(stash) ? (HvAUX(stash)->xhv_mro_meta->pkg_gen + HvAUX(stash)->xhv_mro_meta->cache_gen) : (U32)0)
#endif

#else /* < 5.10.0  */
#define mro_get_linear_isa(stash) my_mro_get_linear_isa(aTHX_ stash)

#define mro_method_changed_in(stash) ((void)stash, (void)PL_sub_generation++)
#define mro_get_pkg_gen(stash)   ((void)stash, PL_sub_generation)
#define mro_get_cache_gen(stash) ((void)stash, (U32)0)
#define mro_get_gen(stash)       ((void)stash, PL_sub_generation)


#if defined(NEED_mro_get_linear_isa) && !defined(NEED_mro_get_linear_isa_GLOBAL)
static AV* my_mro_get_linear_isa(pTHX_ HV* const stash);
static
#else
extern AV* my_mro_get_linear_isa(pTHX_ HV* const stash);
#endif /* !NEED_mro_get_linear_isa */

#if defined(NEED_mro_get_linear_isa) || defined(NEED_mro_get_linear_isa_GLOBAL)
#define ISA_CACHE "::LINEALIZED_ISA_CACHE::"

/* call &mro::get_linear_isa, which is actually &MRO::Compat::__get_linear_isa */
AV*
my_mro_get_linear_isa(pTHX_ HV* const stash){
	GV* cachegv;
	AV* isa;  /* linearized ISA cache */
	SV* gen;  /* package generation */
	CV* get_linear_isa;

	assert(stash != NULL);
	assert(SvTYPE(stash) == SVt_PVHV);

	cachegv = *(GV**)hv_fetchs(stash, ISA_CACHE, TRUE);
	if(!isGV(cachegv))
		gv_init(cachegv, stash, ISA_CACHE, sizeof(ISA_CACHE)-1, GV_ADD);

	isa = GvAVn(cachegv);
#ifdef GvSVn
	gen = GvSVn(cachegv);
#else
	gen = GvSV(cachegv);
#endif

	if(SvIOK(gen) && SvIVX(gen) == (IV)mro_get_pkg_gen(stash)){
		return isa; /* returns the cache if available */
	}
	else{
		SvREADONLY_off(isa);
		av_clear(isa);
	}

	get_linear_isa = get_cv("mro::get_linear_isa", FALSE);
	if(!get_linear_isa){
		ENTER;
		SAVETMPS;

		Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT, newSVpvs("MRO::Compat"), NULL, NULL);
		get_linear_isa = get_cv("mro::get_linear_isa", TRUE);

		FREETMPS;
		LEAVE;
	}

	{
		SV* avref;
		dSP;

		ENTER;
		SAVETMPS;

		PUSHMARK(SP);
		mXPUSHp(HvNAME(stash), strlen(HvNAME(stash)));
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
				HV* const st = gv_stashsv(AvARRAY(av)[i], FALSE);
				if(st)
					av_push(isa, newSVpv(HvNAME(st), 0));
			}
			SvREADONLY_on(isa);
		}
		else{
			Perl_croak(aTHX_ "panic: mro::get_linear_isa() didn't return an ARRAY reference");
		}

		FREETMPS;
		LEAVE;
	}

	sv_setiv(gen, (IV)mro_get_pkg_gen(stash));
	return isa;
}
#undef ISA_CACHE

#endif /* !(defined(NEED_mro_get_linear_isa) || defined(NEED_mro_get_linear_isa_GLOBAL)) */

#endif /* end of the file */
