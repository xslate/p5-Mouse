#ifndef MOUSE_H
#define MOUSE_H

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define  NEED_newSVpvn_flags
#include "ppport.h"

/* for portability */
#ifndef newSVpvs_share
#define newSVpvs_share(s) Perl_newSVpvn_share(aTHX_ s, sizeof(s)-1, 0U)
#endif

#ifndef GvNAME_get
#define GvNAME_get GvNAME
#endif
#ifndef GvNAMELEN_get
#define GvNAMELEN_get GvNAMELEN
#endif

#ifndef mro_get_linear_isa
#define no_mro_get_linear_isa
#define mro_get_linear_isa(stash) mouse_mro_get_linear_isa(aTHX_ stash)
AV* mouse_mro_get_linear_isa(pTHX_ HV* const stash);
#endif /* !mro_get_linear_isa */

#ifndef mro_get_pkg_gen
#ifdef no_mro_get_linear_isa
#define mro_get_pkg_gen(stash) ((void)stash, PL_sub_generation)
#else
#define mro_get_pkg_gen(stash) (HvAUX(stash)->xhv_mro_meta ? HvAUX(stash)->xhv_mro_meta->pkg_gen : (U32)0)
#endif /* !no_mro_get_linear_isa */
#endif /* mro_get_package_gen */

#define MOUSE_CALL_BOOT(name) STMT_START {      \
        EXTERN_C XS(CAT2(boot_, name));         \
        PUSHMARK(SP);                           \
        CALL_FPTR(CAT2(boot_, name))(aTHX_ cv); \
    } STMT_END

extern SV* mouse_package;
extern SV* mouse_namespace;
extern SV* mouse_methods;
extern SV* mouse_name;

void
mouse_throw_error(SV* const metaobject, SV* const data /* not used */, const char* const fmt, ...)
#ifdef __attribute__format__
    __attribute__format__(__printf__, 3, 4);
#else
    ;
#endif

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

/* MOUSE_av_at(av, ix) is the safer version of AvARRAY(av)[ix] if perl is compiled with -DDEBUGGING */
#ifdef DEBUGGING
#define MOUSE_av_at(av, ix)  *mouse_av_at_safe(aTHX_ (av) , (ix))
SV** mouse_av_at_safe(pTHX_ AV* const mi, I32 const ix);
#else
#define MOUSE_av_at(av, ix)  AvARRAY(av)[ix]
#endif

#define dMOUSE_self  SV* const self = mouse_accessor_get_self(aTHX_ ax, items, cv)
SV* mouse_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv);

#define MOUSE_mg_obj(mg)     ((mg)->mg_obj)
#define MOUSE_mg_ptr(mg)     ((mg)->mg_ptr)
#define MOUSE_mg_flags(mg)   ((mg)->mg_private)
#define MOUSE_mg_virtual(mg) ((mg)->mg_virtual)

#define MOUSE_mg_slot(mg)   MOUSE_mg_obj(mg)
#define MOUSE_mg_xa(mg)    ((AV*)MOUSE_mg_ptr(mg))


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
XS(mouse_xs_simple_clearer);
XS(mouse_xs_simple_predicate);

CV* mouse_instantiate_xs_accessor(pTHX_ SV* const attr, XSUBADDR_t const accessor_impl);

XS(mouse_xs_accessor);
XS(mouse_xs_reader);
XS(mouse_xs_writer);

typedef enum mouse_tc{
     MOUSE_TC_ANY,
     MOUSE_TC_ITEM,
     MOUSE_TC_UNDEF,
     MOUSE_TC_DEFINED,
     MOUSE_TC_BOOL,
     MOUSE_TC_VALUE,
     MOUSE_TC_REF,
     MOUSE_TC_STR,
     MOUSE_TC_NUM,
     MOUSE_TC_INT,
     MOUSE_TC_SCALAR_REF,
     MOUSE_TC_ARRAY_REF,
     MOUSE_TC_HASH_REF,
     MOUSE_TC_CODE_REF,
     MOUSE_TC_GLOB_REF,
     MOUSE_TC_FILEHANDLE,
     MOUSE_TC_REGEXP_REF,
     MOUSE_TC_OBJECT,
     MOUSE_TC_CLASS_NAME,
     MOUSE_TC_ROLE_NAME,

     MOUSE_TC_last
} mouse_tc;

/* type constraints */

int mouse_tc_check(pTHX_ SV* const tc, SV* const sv);
int mouse_builtin_tc_check(pTHX_ mouse_tc const tc, SV* const sv);

int mouse_tc_Any       (pTHX_ SV* const sv);
int mouse_tc_Bool      (pTHX_ SV* const sv);
int mouse_tc_Undef     (pTHX_ SV* const sv);
int mouse_tc_Defined   (pTHX_ SV* const sv);
int mouse_tc_Value     (pTHX_ SV* const sv);
int mouse_tc_Num       (pTHX_ SV* const sv);
int mouse_tc_Int       (pTHX_ SV* const sv);
int mouse_tc_Str       (pTHX_ SV* const sv);
int mouse_tc_ClassName (pTHX_ SV* const sv);
int mouse_tc_RoleName  (pTHX_ SV* const sv);
int mouse_tc_Ref       (pTHX_ SV* const sv);
int mouse_tc_ScalarRef (pTHX_ SV* const sv);
int mouse_tc_ArrayRef  (pTHX_ SV* const sv);
int mouse_tc_HashRef   (pTHX_ SV* const sv);
int mouse_tc_CodeRef   (pTHX_ SV* const sv);
int mouse_tc_RegexpRef (pTHX_ SV* const sv);
int mouse_tc_GlobRef   (pTHX_ SV* const sv);
int mouse_tc_FileHandle(pTHX_ SV* const sv);
int mouse_tc_Object    (pTHX_ SV* const sv);


#endif /* !MOUSE_H */

