
package Bar;
use Mouse;
use Mouse::Util::TypeConstraints;

type Baz => where { 1 };

subtype Bling => as Baz => where { 1 };

1;