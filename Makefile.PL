use inc::Module::Install;

name        'Spiffy';
all_from    'lib/Spiffy.pm';
license     'perl';

requires(qw(
    perl 5.6.1
    Filter::Util::Call 0
    Scalar::Util 0
));

&WriteAll;
