use lib 't';
use strict;
use warnings;

package A;
use Spiffy '-base', qw(!field const :XXX);

package B;
use base 'A';

package main;
use Test::More tests => 6;
ok(not defined &A::field);
ok(defined &B::field);
ok(defined &A::const);
ok(defined &B::const);
ok(defined &A::XXX);
ok(not defined &B::XXX);
