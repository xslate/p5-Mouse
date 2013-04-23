use strict;
use warnings;
use Test::More;

use Test::Spellunker;

my @stopwords;
for (<DATA>) {
    chomp;
    push @stopwords, $_, ucfirst($_)
        unless /\A (?: \# | \s* \z)/msx;    # skip comments, whitespace
}

add_stopwords(@stopwords);
all_pod_files_spelling_ok();

__DATA__
## personal names
Aankhen
Aran
autarch
chansen
chromatic's
Debolaz
Deltac
dexter
doy
ewilhelm
frodwith
Goulah
gphat
groditi
Hardison
jrockway
Kinyon's
Kogman
kolibrie
konobi
Lanyon
lbr
Luehrs
McWhirter
merlyn
mst
nothingmuch
Pearcey
perigrin
phaylon
Prather
Ragwitz
Reis
rafl
rindolf
rlb
Rockway
Roditi
Rolsky
Roszatycki
Roszatycki's
sartak
Sedlacek
Shlomi
SL
stevan
Stevan
SIGNES
tozt
Vilain
wreis
Yuval
Goro
gfx
Yappo
tokuhirom
wu

## proper names
AOP
CLOS
cpan
CPAN
OCaml
ohloh
SVN
CGI
FastCGI
DateTime
pm
XS

## Moose
AttributeHelpers
BankAccount
BinaryTree
BUILDALL
BUILDARGS
CheckingAccount
ClassName
ClassNames
LocalName
RemoteName
MethodName
OwnerClass
AttributeName
RoleName

clearers
composable
Debuggable
DEMOLISHALL
hardcode
immutabilization
immutabilize
introspectable
metaclass
Metaclass
METACLASS
metadata
MetaObject
metaprogrammer
metarole
metatraits
mixins
MooseX
MouseX
Num
OtherName
oose
ouse
PosInt
PositiveInt
ro
rw
RoleSummation
Str
TypeContraints
metaroles

## computerese
arity
Baz
canonicalizes
canonicalized
Changelog
codebase
committer
committers
compat
datetimes
dec
definedness
deinitialization
destructor
destructors
destructuring
dev
DWIM
DUCKTYPE
exportable
GitHub
hashrefs
reftype
hotspots
immutabilize
immutabilized
inline
inlines
invocant
irc
IRC
isa
JSON
kv
login
mul
transformability
redispatch
MISC
mro
subtype
subtypes
subclass
subclasses
coercion
coercions
accessors
metaclasses
unimport
builtin
4x
coderef
aliasing

# as in required-ness
ness
OO
OOP
ORM
overridable
parameterizable
parameterization
parameterize
parameterized
parameterizes
params
pluggable
prechecking
prepends
pu
rebase
rebased
rebasing
reblesses
refactored
refactoring
rethrows
runtime
serializer
stacktrace
startup
subclassable
subname
subtyping
TODO
unblessed
unexport
UNIMPORTING
Unported
unsets
unsettable


## compound
# half-assed

## things that should be in the dictionary, but are not
reinitializes

## misspelt on purpose
emali

## spellunker's bug?
<gfuji
