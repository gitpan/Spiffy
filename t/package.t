use lib 'lib';
use strict;
use warnings;
use Test::More tests => 4;

package Foo;
use Spiffy -base => -package => 'Bar';

package main;
ok(not Foo->is_spiffy);
ok(Bar->is_spiffy);
ok(not defined &Foo::field);
ok(defined &Bar::field);
