#ifndef MOUSE_H
#define MOUSE_H

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#define is_class_loaded(sv) mouse_is_class_loaded(aTHX_ sv)
bool mouse_is_class_loaded(pTHX_ SV*);

#define is_instance_of(sv, klass) mouse_is_instance_of(aTHX_ sv, klass)
bool mouse_is_instance_of(pTHX_ SV* const sv, SV* const klass);

#define IsObject(sv) (SvROK(sv) && SvOBJECT(SvRV(sv)))

#define mcall0(invocant, m)        mouse_call0(aTHX_ (invocant), (m))
#define mcall1(invocant, m, arg1)  mouse_call1(aTHX_ (invocant), (m), (arg1))
#define mcall0s(invocant, m)       mcall0((invocant), newSVpvs_flags(m, SVs_TEMP))
#define mcall1s(invocant, m, arg1) mcall1((invocant), newSVpvs_flags(m, SVs_TEMP), (arg1))

SV* mouse_call0(pTHX_ SV *const self, SV *const method);
SV* mouse_call1(pTHX_ SV *const self, SV *const method, SV* const arg1);


#endif /* !MOUSE_H */

