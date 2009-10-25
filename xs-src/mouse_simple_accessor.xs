#include "mouse.h"

static MGVTBL mouse_simple_accessor_vtbl;

/*
static MAGIC*
mouse_accessor_get_mg(pTHX_ CV* const xsub){
    return moose_mg_find(aTHX_ (SV*)xsub, &mouse_simple_accessor_vtbl, MOOSEf_DIE_ON_FAIL);
}
*/

CV*
mouse_install_simple_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl){
    CV* const xsub = newXS((char*)fq_name, accessor_impl, __FILE__);
    SV* const slot = newSVpvn_share(key, keylen, 0U);
    MAGIC* mg;

    if(!fq_name){
        /* anonymous xsubs need sv_2mortal */
        sv_2mortal((SV*)xsub);
    }

    mg = sv_magicext((SV*)xsub, slot, PERL_MAGIC_ext, &mouse_simple_accessor_vtbl, NULL, 0);
    SvREFCNT_dec(slot); /* sv_magicext() increases refcnt in mg_obj */

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}

SV*
mouse_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv) {
    SV* self;

    if(items < 1){
        croak("Too few arguments for %s", GvNAME(CvGV(cv)));
    }

    /* NOTE: If self has GETMAGIC, $self->accessor will invoke GETMAGIC
     *       before calling methods, so SvGETMAGIC(self) is not necessarily needed here.
     */

    self = ST(0);
    if(!IsObject(self)){
        croak("Cant call %s as a class method", GvNAME(CvGV(cv)));
    }
    return self;
}


XS(mouse_xs_simple_reader)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a reader for '%"SVf"'", slot);
    }

    value = mouse_instance_get_slot(aTHX_ self, slot);
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}


XS(mouse_xs_simple_writer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);

    if (items != 2) {
        croak("Expected exactly two argument for a writer for '%"SVf"'", slot);
    }

    ST(0) = mouse_instance_set_slot(aTHX_ self, slot, ST(1));
    XSRETURN(1);
}

XS(mouse_xs_simple_clearer)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);
    SV* value;

    if (items != 1) {
        croak("Expected exactly one argument for a clearer for '%"SVf"'", slot);
    }

    value = mouse_instance_delete_slot(aTHX_ self, slot);
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}

XS(mouse_xs_simple_predicate)
{
    dVAR; dXSARGS;
    dMOUSE_self;
    SV* const slot = MOUSE_mg_slot((MAGIC*)XSANY.any_ptr);

    if (items != 1) {
        croak("Expected exactly one argument for a predicate for '%"SVf"'", slot);
    }

    ST(0) = boolSV( mouse_instance_has_slot(aTHX_ self, slot) );
    XSRETURN(1);
}
