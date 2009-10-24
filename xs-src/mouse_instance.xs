#include "mouse.h"

#define CHECK_INSTANCE(instance) STMT_START{                          \
        if(!(SvROK(instance) && SvTYPE(SvRV(instance)) == SVt_PVHV)){ \
            croak("Invalid object for instance managers");            \
        }                                                             \
    } STMT_END

SV*
mouse_instance_create(pTHX_ HV* const stash) {
    assert(stash);
    return sv_bless( newRV_noinc((SV*)newHV()), stash );
}

SV*
mouse_instance_clone(pTHX_ SV* const instance) {
    HV* proto;
    assert(instance);

    CHECK_INSTANCE(instance);
    proto = newHVhv((HV*)SvRV(instance));
    return sv_bless( newRV_noinc((SV*)proto), SvSTASH(SvRV(instance)) );
}

bool
mouse_instance_has_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_exists_ent((HV*)SvRV(instance), slot, 0U);
}

SV*
mouse_instance_get_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    return he ? HeVAL(he) : NULL;
}

SV*
mouse_instance_set_slot(pTHX_ SV* const instance, SV* const slot, SV* const value) {
    HE* he;
    SV* sv;
    assert(instance);
    assert(slot);
    assert(value);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, TRUE, 0U);
    sv = HeVAL(he);
    sv_setsv_mg(sv, value);
    return sv;
}

SV*
mouse_instance_delete_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_delete_ent((HV*)SvRV(instance), slot, 0, 0U);
}

void
mouse_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    if(he){
        sv_rvweaken(HeVAL(he));
    }
}

