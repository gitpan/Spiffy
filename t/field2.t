use lib 't', 'lib';
use strict;
use warnings;

package Foo;
use Spiffy '-base';
field one => [];
field two => {};
field three => [1..4];
field four => {1..4};

package main;
use Test::More tests => 5;
use Spiffy 'id';

my $f1 = Foo->new;
my $f2 = Foo->new;
ok(id($f1->one) ne id($f2->one));
ok(id($f1->two) ne id($f2->two));
is(scalar(@{$f1->three}), 4);
ok(id($f1->three) eq id($f2->three));
ok(id($f1->four) eq id($f2->four));
