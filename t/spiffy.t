use lib 'lib';

package Foo;
use strict;
use Spiffy '-base';

sub new {
    bless {}, shift;
}

package main;
use strict;
use Test::More tests => 2;

ok(Foo->new->is_spiffy);

my $plain_object = bless {}, 'Plain';
ok(not $plain_object->is_spiffy);
