package Thing;
use strict;
use Spiffy ();
use base 'Spiffy';
our @EXPORT = qw(thing);

field volume => 11;

spiffy_constructor('thing');

1;
