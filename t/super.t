use lib 'lib';

package Foo;
use strict;
use Spiffy '-base';
attribute 'xxx';
attribute 'dog';

sub new {
    my $self = super;
    $self->xxx('XXX');
    return $self;
}

sub poodle {
    my $self = shift;
    my $count = shift;
    $self->dog("$count poodle");
}

package Bar;
use strict;
BEGIN { 'Foo'->import('-base') }

sub poodle {
    my $self = shift;
    super;
    $self->dog($self->dog . ' dogs');
}

package main;
use strict;
use Test::More tests => 2;

my $f = Bar->new;
is($f->{xxx}, 'XXX');

$f->poodle(3);
is($f->{dog}, '3 poodle dogs');
