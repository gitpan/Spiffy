use lib 't', 'lib';
use strict;
no strict 'refs';
use warnings;

package A;
use Spiffy '-base';
field 'foo' => 17;

package X;
sub extra {99}

package BB;
use base 'X';
sub xxx {42}
sub yyy {}
sub _zzz {}

package C;
use base 'A';
use mixin 'BB';

package main;
use Test::More tests => 10;

ok(C->can('foo'));
is(C->foo, 17);
ok(C->can('extra'));
is(C->extra, 99);
ok(C->can('xxx'));
is(C->xxx, 42);
ok(not C->can('_zzz'));
is(@{C::ISA}, 1);
is(${C::ISA}[0], 'C-BB');
is(${"C-BB::ISA"}[0], 'A');
