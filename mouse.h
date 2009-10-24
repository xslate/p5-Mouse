#ifndef MOUSE_H
#define MOUSE_H

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#define MOUSE_CALL_BOOT(name) STMT_START {        \
        EXTERN_C XS(CAT2(boot_, name));         \
        PUSHMARK(SP);                           \
        CALL_FPTR(CAT2(boot_, name))(aTHX_ cv); \
    } STMT_END


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

#define MOUSEf_DIE_ON_FAIL 0x01
MAGIC* mouse_mg_find(pTHX_ SV* const sv, const MGVTBL* const vtbl, I32 const flags);

#define dMOUSE_self      SV* const self = mouse_accessor_get_self(aTHX_ ax, items, cv)

/* mouse_instance.xs stuff */
SV*  mouse_instance_create     (pTHX_ HV* const stash);
SV*  mouse_instance_clone      (pTHX_ SV* const instance);
bool mouse_instance_has_slot   (pTHX_ SV* const instance, SV* const slot);
SV*  mouse_instance_get_slot   (pTHX_ SV* const instance, SV* const slot);
SV*  mouse_instance_set_slot   (pTHX_ SV* const instance, SV* const slot, SV* const value);
SV*  mouse_instance_delete_slot(pTHX_ SV* const instance, SV* const slot);
void mouse_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot);


/* mouse_simle_accessor.xs */
#define INSTALL_SIMPLE_READER(klass, name)                  INSTALL_SIMPLE_READER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_READER_WITH_KEY(klass, name, key)    (void)mouse_install_simple_accessor(aTHX_ "Mouse::Meta::" #klass "::" #name, #key, sizeof(#key)-1, mouse_xs_simple_reader)

#define INSTALL_SIMPLE_WRITER(klass, name)                  INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, key)    (void)mouse_install_simple_accessor(aTHX_ "Mouse::Meta::" #klass "::" #name, #key, sizeof(#key)-1, mouse_xs_simple_writer)

#define INSTALL_SIMPLE_PREDICATE(klass, name)                INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, key) (void)mouse_install_simple_accessor(aTHX_ "Mouse::Meta::" #klass "::" #name, #key, sizeof(#key)-1, mouse_xs_simple_predicate)

CV* mouse_install_simple_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl);

XS(mouse_xs_simple_reader);
XS(mouse_xs_simple_writer);
XS(mouse_xs_simple_predicate);

#endif /* !MOUSE_H */

