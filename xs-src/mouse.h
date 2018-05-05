#ifndef MOUSE_H
#define MOUSE_H

#define NEED_mg_findext
#define NEED_gv_fetchpvn_flags
#define NEED_SvRX
#define NEED_newSVpvn_flags
#define PERL_EUPXS_ALWAYS_EXPORT

#include "xshelper.h"

#ifndef mro_get_linear_isa
#define no_mro_get_linear_isa
#define mro_get_linear_isa(stash) mouse_mro_get_linear_isa(aTHX_ stash)
AV* mouse_mro_get_linear_isa(pTHX_ HV* const stash);
#define mro_method_changed_in(stash) ((void)++PL_sub_generation)
#endif /* !mro_get_linear_isa */

#ifndef mro_get_pkg_gen
#ifdef no_mro_get_linear_isa
#define mro_get_pkg_gen(stash) ((void)stash, PL_sub_generation)
#else
#define mro_get_pkg_gen(stash) (HvAUX(stash)->xhv_mro_meta ? HvAUX(stash)->xhv_mro_meta->pkg_gen : (U32)0)
#endif /* !no_mro_get_linear_isa */
#endif /* mro_get_package_gen */

#ifndef GvCV_set
#define GvCV_set(gv, cv) (GvCV(gv) = (cv))
#endif

#ifndef PERL_STATIC_INLINE
#ifdef NOINLINE
#define PERL_STATIC_INLINE STATIC
#elif defined(_MSC_VER)
#define PERL_STATIC_INLINE STATIC __inline
#else
#define PERL_STATIC_INLINE STATIC inline
#endif
#endif

extern SV* mouse_package;
extern SV* mouse_methods;
extern SV* mouse_name;
extern SV* mouse_coerce;

void
mouse_throw_error(SV* const metaobject, SV* const data /* not used */, const char* const fmt, ...)
    __attribute__format__(__printf__, 3, 4);

#if (PERL_BCDVERSION < 0x5014000)
/* workaround RT #69939 */
I32
mouse_call_sv_safe(pTHX_ SV*, I32);
#else
#define mouse_call_sv_safe Perl_call_sv
#endif

#define call_sv_safe(sv, flags)     mouse_call_sv_safe(aTHX_ sv, flags)
#define call_method_safe(m, flags)  mouse_call_sv_safe(aTHX_ newSVpvn_flags(m, strlen(m), SVs_TEMP), flags | G_METHOD)
#define call_method_safes(m, flags) mouse_call_sv_safe(aTHX_ newSVpvs_flags(m, SVs_TEMP),            flags | G_METHOD)


#define is_class_loaded(sv) mouse_is_class_loaded(aTHX_ sv)
bool mouse_is_class_loaded(pTHX_ SV*);

#define is_an_instance_of(klass, sv) mouse_is_an_instance_of(aTHX_ gv_stashpvs(klass, GV_ADD), (sv))

#define IsObject(sv)   (SvROK(sv) && SvOBJECT(SvRV(sv)))
#define IsArrayRef(sv) (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVAV)
#define IsHashRef(sv)  (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVHV)
#define IsCodeRef(sv)  (SvROK(sv) && !SvOBJECT(SvRV(sv)) && SvTYPE(SvRV(sv)) == SVt_PVCV)

#define mcall0(invocant, m)          mouse_call0(aTHX_ (invocant), (m))
#define mcall1(invocant, m, arg1)    mouse_call1(aTHX_ (invocant), (m), (arg1))
#define predicate_call(invocant, m)  mouse_predicate_call(aTHX_ (invocant), (m))

#define mcall0s(invocant, m)          mcall0((invocant), sv_2mortal(newSVpvs_share(m)))
#define mcall1s(invocant, m, arg1)    mcall1((invocant), sv_2mortal(newSVpvs_share(m)), (arg1))
#define predicate_calls(invocant, m)  predicate_call((invocant), sv_2mortal(newSVpvs_share(m)))


#define get_metaclass(name) mouse_get_metaclass(aTHX_ name)

SV* mouse_call0(pTHX_ SV *const self, SV *const method);
SV* mouse_call1(pTHX_ SV *const self, SV *const method, SV* const arg1);
int mouse_predicate_call(pTHX_ SV* const self, SV* const method);

SV* mouse_get_metaclass(pTHX_ SV* metaclass_name);

GV* mouse_stash_fetch(pTHX_ HV* const stash, const char* const name, I32 const namelen, I32 const create);
#define stash_fetch(s, n, l, c) mouse_stash_fetch(aTHX_ (s), (n), (l), (c))
#define stash_fetchs(s, n, c)   mouse_stash_fetch(aTHX_ (s), STR_WITH_LEN(n), (c))

void mouse_install_sub(pTHX_ GV* const gv, SV* const code_ref);

void mouse_must_defined(pTHX_ SV* const value, const char* const name);
void mouse_must_ref(pTHX_ SV* const value, const char* const name, svtype const t);

#define must_defined(sv, name)   mouse_must_defined(aTHX_ sv, name)
#define must_ref(sv, name, svt)  mouse_must_ref(aTHX_ sv, name, svt)

#define MOUSEf_DIE_ON_FAIL 0x01
MAGIC* mouse_mg_find(pTHX_ SV* const sv, const MGVTBL* const vtbl, I32 const flags);

/* MOUSE_av_at(av, ix) is the safer version of AvARRAY(av)[ix] if perl is compiled with -DDEBUGGING */
#ifdef DEBUGGING
#define MOUSE_av_at(av, ix)  mouse_av_at_safe(aTHX_ (av) , (ix))
SV* mouse_av_at_safe(pTHX_ AV* const mi, I32 const ix);
#else
#define MOUSE_av_at(av, ix) \
    (AvARRAY(av)[ix] ? AvARRAY(av)[ix] : &PL_sv_undef)
#endif

#define MOUSE_mg_obj(mg)     ((mg)->mg_obj)
#define MOUSE_mg_ptr(mg)     ((mg)->mg_ptr)
#define MOUSE_mg_len(mg)     ((mg)->mg_len)
#define MOUSE_mg_flags(mg)   ((mg)->mg_private)
#define MOUSE_mg_virtual(mg) ((mg)->mg_virtual)

#define MOUSE_mg_slot(mg)   MOUSE_mg_obj(mg)
#define MOUSE_mg_xa(mg)    ((AV*)MOUSE_mg_ptr(mg))

PERL_STATIC_INLINE MAGIC *MOUSE_get_magic(pTHX_ CV *cv, MGVTBL *vtbl)
{
#ifndef MULTIPLICITY
    PERL_UNUSED_ARG(vtbl);
    return (MAGIC*)(CvXSUBANY(cv).any_ptr);
#else
    return mg_findext((SV*)cv, PERL_MAGIC_ext, vtbl);
#endif
}

/* mouse_instance.xs stuff */
SV*  mouse_instance_create     (pTHX_ HV* const stash);
SV*  mouse_instance_clone      (pTHX_ SV* const instance);
bool mouse_instance_has_slot   (pTHX_ SV* const instance, SV* const slot);
SV*  mouse_instance_get_slot   (pTHX_ SV* const instance, SV* const slot);
SV*  mouse_instance_set_slot   (pTHX_ SV* const instance, SV* const slot, SV* const value);
SV*  mouse_instance_delete_slot(pTHX_ SV* const instance, SV* const slot);
void mouse_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot);

#define has_slot(self, key)         mouse_instance_has_slot(aTHX_ self, key)
#define get_slot(self, key)         mouse_instance_get_slot(aTHX_ self, key)
#define set_slot(self, key, value)  mouse_instance_set_slot(aTHX_ self, key, value)
#define delete_slot(self, key)      mouse_instance_delete_slot(aTHX_ self, key)
#define weaken_slot(self, key)      mouse_instance_weaken_slot(aTHX_ self, key)

#define has_slots(self, key)        has_slot(self, sv_2mortal(newSVpvs_share(key)))
#define get_slots(self, key)        get_slot(self, sv_2mortal(newSVpvs_share(key)))
#define set_slots(self, key, value) set_slot(self, sv_2mortal(newSVpvs_share(key)), value)

/* mouse_simple_accessor.xs for meta object protocols */
#define INSTALL_SIMPLE_READER(klass, name) \
    INSTALL_SIMPLE_READER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_READER_WITH_KEY(klass, name, key) \
    (void)mouse_simple_accessor_generate(aTHX_ "Mouse::Meta::" #klass "::" \
    #name, #key, sizeof(#key)-1, XS_Mouse_simple_reader, NULL, 0)

#define INSTALL_CLASS_HOLDER_SV(klass, name, dsv) \
    (void)mouse_simple_accessor_generate(aTHX_ "Mouse::Meta::" #klass "::" \
    #name, #name, sizeof(#name)-1, XS_Mouse_simple_reader, (dsv), HEf_SVKEY)
#define INSTALL_CLASS_HOLDER(klass, name, ds) \
    INSTALL_CLASS_HOLDER_SV(klass, name, newSVpvs(ds))

#define INSTALL_SIMPLE_WRITER(klass, name) \
    NSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, key) \
    (void)mouse_simple_accessor_generate(aTHX_ "Mouse::Meta::" #klass "::" \
    #name, #key, sizeof(#key)-1, XS_Mouse_simple_writer, NULL, 0)

#define INSTALL_SIMPLE_PREDICATE(klass, name) \
    INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, key) \
    (void)mouse_simple_accessor_generate(aTHX_ "Mouse::Meta::" #klass "::" \
    #name, #key, sizeof(#key)-1, XS_Mouse_simple_predicate, NULL, 0)

/* generate inhertiable class accessors for Mouse::Meta::Class */
#define INSTALL_INHERITABLE_CLASS_ACCESSOR(name) \
    INSTALL_INHERITABLE_CLASS_ACCESSOR_WITH_KEY(name, name)
#define INSTALL_INHERITABLE_CLASS_ACCESSOR_WITH_KEY(name, key) \
    (void)mouse_simple_accessor_generate(aTHX_ "Mouse::Meta::Class::" #name,\
    #key, sizeof(#key)-1, XS_Mouse_inheritable_class_accessor, NULL, 0)

CV* mouse_simple_accessor_generate(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl, void* const dptr, I32 const dlen);

XS(XS_Mouse_simple_reader);
XS(XS_Mouse_simple_writer);
XS(XS_Mouse_simple_clearer);
XS(XS_Mouse_simple_predicate);

CV* mouse_accessor_generate(pTHX_ SV* const attr, XSUBADDR_t const accessor_impl);

XS(XS_Mouse_accessor);
XS(XS_Mouse_reader);
XS(XS_Mouse_writer);

XS(XS_Mouse_inheritable_class_accessor);

/* type constraints */

int mouse_tc_check(pTHX_ SV* const tc, SV* const sv);

int mouse_tc_Any       (pTHX_ SV*, SV* const sv);
int mouse_tc_Bool      (pTHX_ SV*, SV* const sv);
int mouse_tc_Undef     (pTHX_ SV*, SV* const sv);
int mouse_tc_Defined   (pTHX_ SV*, SV* const sv);
int mouse_tc_Value     (pTHX_ SV*, SV* const sv);
int mouse_tc_Num       (pTHX_ SV*, SV* const sv);
int mouse_tc_Int       (pTHX_ SV*, SV* const sv);
int mouse_tc_Str       (pTHX_ SV*, SV* const sv);
int mouse_tc_ClassName (pTHX_ SV*, SV* const sv);
int mouse_tc_RoleName  (pTHX_ SV*, SV* const sv);
int mouse_tc_Ref       (pTHX_ SV*, SV* const sv);
int mouse_tc_ScalarRef (pTHX_ SV*, SV* const sv);
int mouse_tc_ArrayRef  (pTHX_ SV*, SV* const sv);
int mouse_tc_HashRef   (pTHX_ SV*, SV* const sv);
int mouse_tc_CodeRef   (pTHX_ SV*, SV* const sv);
int mouse_tc_RegexpRef (pTHX_ SV*, SV* const sv);
int mouse_tc_GlobRef   (pTHX_ SV*, SV* const sv);
int mouse_tc_FileHandle(pTHX_ SV*, SV* const sv);
int mouse_tc_Object    (pTHX_ SV*, SV* const sv);

CV* mouse_generate_isa_predicate_for(pTHX_ SV* const klass, const char* const predicate_name);
CV* mouse_generate_can_predicate_for(pTHX_ SV* const klass, const char* const predicate_name);

int mouse_is_an_instance_of(pTHX_ HV* const stash, SV* const instance);

/* Mouse XS Attribute object */

AV* mouse_get_xa(pTHX_ SV* const attr);
SV* mouse_xa_apply_type_constraint(pTHX_ AV* const xa, SV* value, U16 const flags);
SV* mouse_xa_set_default(pTHX_ AV* const xa, SV* const object);

enum mouse_xa_ix_t{
    MOUSE_XA_SLOT,      /* for constructors, sync to mg_obj */
    MOUSE_XA_FLAGS,     /* for constructors, sync to mg_private */
    MOUSE_XA_ATTRIBUTE,
    MOUSE_XA_INIT_ARG,
    MOUSE_XA_TC,
    MOUSE_XA_TC_CODE,

    MOUSE_XA_last
};

#define MOUSE_xa_slot(m)      MOUSE_av_at(m, MOUSE_XA_SLOT)
#define MOUSE_xa_flags(m)     SvUVX( MOUSE_av_at(m, MOUSE_XA_FLAGS) )
#define MOUSE_xa_attribute(m) MOUSE_av_at(m, MOUSE_XA_ATTRIBUTE)
#define MOUSE_xa_init_arg(m)  MOUSE_av_at(m, MOUSE_XA_INIT_ARG)
#define MOUSE_xa_tc(m)        MOUSE_av_at(m, MOUSE_XA_TC)
#define MOUSE_xa_tc_code(m)   MOUSE_av_at(m, MOUSE_XA_TC_CODE)

enum mouse_xa_flags_t{
    MOUSEf_ATTR_HAS_TC          = 0x0001,
    MOUSEf_ATTR_HAS_DEFAULT     = 0x0002,
    MOUSEf_ATTR_HAS_BUILDER     = 0x0004,
    MOUSEf_ATTR_HAS_INITIALIZER = 0x0008, /* not used */
    MOUSEf_ATTR_HAS_TRIGGER     = 0x0010,

    MOUSEf_ATTR_IS_LAZY         = 0x0020,
    MOUSEf_ATTR_IS_WEAK_REF     = 0x0040,
    MOUSEf_ATTR_IS_REQUIRED     = 0x0080,

    MOUSEf_ATTR_SHOULD_COERCE   = 0x0100,

    MOUSEf_ATTR_SHOULD_AUTO_DEREF
                                = 0x0200,
    MOUSEf_TC_IS_ARRAYREF       = 0x0400,
    MOUSEf_TC_IS_HASHREF        = 0x0800,

    MOUSEf_OTHER1               = 0x1000,
    MOUSEf_OTHER2               = 0x2000,
    MOUSEf_OTHER3               = 0x4000,
    MOUSEf_OTHER4               = 0x8000,

    MOUSEf_MOUSE_MASK           = 0xFFFF /* not used */
};

/* Mouse::Meta::Class stuff */
HV* mouse_get_namespace(pTHX_ SV* const meta); /* $meta->namespace */
#endif /* !MOUSE_H */
