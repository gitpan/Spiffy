use lib 't', 'lib';
use strict;
use warnings;

package Foo;
use Spiffy -Base;
my $test1 = field test1 => [];
my $test2 = field test2 => {};
my $test3 = field test3 => [1..4];
my $test4 = field test4 => {1..4};
my $test5 = field test5 => -weaken;
my $test6 = field test6 => -init => '$self->setup(@_)';

package main;
use Test::More tests => 6;

my @expected = map { s/\r//g; $_ } split /\.\.\.\r?\n/, join '', <DATA>;

my $i = 1;
for my $expected (@expected) {
    is(eval '$test' . $i++, $expected);    
}

__DATA__
sub {
  my $self = shift;
  $self->{test1} = []
    unless exists $self->{test1};
  return $self->{test1} unless @_;
  $self->{test1} = shift;
  return $self->{test1};
}
...
sub {
  my $self = shift;
  $self->{test2} = {}
    unless exists $self->{test2};
  return $self->{test2} unless @_;
  $self->{test2} = shift;
  return $self->{test2};
}
...
sub {
  my $self = shift;
  $self->{test3} = [
          1,
          2,
          3,
          4
        ]

    unless exists $self->{test3};
  return $self->{test3} unless @_;
  $self->{test3} = shift;
  return $self->{test3};
}
...
sub {
  my $self = shift;
  $self->{test4} = {
          '1' => 2,
          '3' => 4
        }

    unless exists $self->{test4};
  return $self->{test4} unless @_;
  $self->{test4} = shift;
  return $self->{test4};
}
...
sub {
  my $self = shift;
  $self->{test5} = '-weaken'

    unless exists $self->{test5};
  return $self->{test5} unless @_;
  $self->{test5} = shift;
  return $self->{test5};
}
...
sub {
  my $self = shift;
  return $self->{test6} = do { $self->setup(@_) }
    unless @_ or defined $self->{test6};
  return $self->{test6} unless @_;
  $self->{test6} = shift;
  return $self->{test6};
}
