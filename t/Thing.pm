package Thing;
use strict;
use Spiffy ();
use base 'Spiffy';
our @EXPORT = qw(thing);

attribute volume => 11;

spiffy_constructor('thing');

1;
