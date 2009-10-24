#include "mouse.h"

MODULE = Mouse  PACKAGE = Mouse::Util

PROTOTYPES: DISABLE

bool
is_class_loaded(SV* sv = &PL_sv_undef)

void
get_code_info(CV* code)
PREINIT:
    GV* gv;
    HV* stash;
PPCODE:
    if((gv = CvGV(code)) && isGV(gv) && (stash = GvSTASH(gv))){
        EXTEND(SP, 2);
        mPUSHs(newSVpvn_share(HvNAME_get(stash), HvNAMELEN_get(stash), 0U));
        mPUSHs(newSVpvn_share(GvNAME_get(gv), GvNAMELEN_get(gv), 0U));
    }

SV*
get_code_package(CV* code)
PREINIT:
    HV* stash;
CODE:
    if(CvGV(code) && isGV(CvGV(code)) && (stash = GvSTASH(CvGV(code)))){
        RETVAL = newSVpvn_share(HvNAME_get(stash), HvNAMELEN_get(stash), 0U);
    }
    else{
        RETVAL = &PL_sv_no;
    }
OUTPUT:
    RETVAL

