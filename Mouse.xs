#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include "ppport.h"

MODULE = Mouse  PACKAGE = Mouse::Util

PROTOTYPES: DISABLE

BOOT:
	NOOP;

char *
blessed(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
    mg_get(sv);
    if(!sv_isobject(sv)) {
        XSRETURN_UNDEF;
    }
    RETVAL = (char*)sv_reftype(SvRV(sv),TRUE);
}
OUTPUT:
    RETVAL

char *
reftype(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!SvROK(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = (char*)sv_reftype(SvRV(sv),FALSE);
}
OUTPUT:
    RETVAL

int
looks_like_number(sv)
	SV *sv
PROTOTYPE: $
CODE:
#if (PERL_VERSION < 8) || (PERL_VERSION == 8 && PERL_SUBVERSION <5)
  if (SvPOK(sv) || SvPOKp(sv)) {
    RETVAL = looks_like_number(sv);
  }
  else {
    RETVAL = SvFLAGS(sv) & (SVf_NOK|SVp_NOK|SVf_IOK|SVp_IOK);
  }
#else
  RETVAL = looks_like_number(sv);
#endif
OUTPUT:
  RETVAL

void
weaken(sv)
	SV *sv
PROTOTYPE: $
CODE:
#ifdef SvWEAKREF
	sv_rvweaken(sv);
#else
	croak("weak references are not implemented in this release of perl");
#endif

