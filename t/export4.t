use lib 't';
use strict;
use warnings;

package A;
use Spiffy -base, qw(!field const :XXX);

package B;
use base 'A';

package C;
use Spiffy -XXX, -base;

package D;
use Spiffy -base;

package main;
use Test::More tests => 8;
ok(not defined &A::field);
ok(defined &B::field);
ok(defined &A::const);
ok(defined &B::const);
ok(defined &A::XXX);
ok(not defined &B::XXX);
ok(defined &C::XXX);
ok(defined &D::XXX);
