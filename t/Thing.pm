package Thing;
use strict;
use Spiffy '-base';
our @EXPORT = qw(thing);

attribute volume => 11;

spiffy_constructor('thing');

1;
