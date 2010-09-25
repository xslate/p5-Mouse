use strict;

rename 't-failing/060_compat/004_extends_nonmoose_that_isa_moose_with_metarole.t',
    't-failing/060_compat/004_entimwm.t' or warn $!;
rename 't/050_metaclasses/041_moose_nonmoose_moose_chain_init_meta.t',
    't/050_metaclasses/041_mnmcim.t' or warn $!;

rename 't/600_todo_tests/001_exception_reflects_failed_constraint.t',
    't/600_todo_tests/001_erfc.t' or warn $!;
