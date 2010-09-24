package Role::Child;
use Mouse::Role;

with 'Role::Parent' => { -alias => { meth1 => 'aliased_meth1', } };

sub meth1 { }

1;
