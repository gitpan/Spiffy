package Thing;
use strict;
use Spiffy qw(spiffy_constructor);
use base 'Spiffy';
our @EXPORT = qw(thing);

field volume => 11;

spiffy_constructor('thing');

1;
