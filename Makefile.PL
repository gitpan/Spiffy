use inc::Module::Install;

name('Spiffy');
author('Brian Ingerson <ingy@cpan.org>');
abstract('Spiffy Perl Interface Framework For You');
version_from('lib/Spiffy.pm');
license('perl');

requires(qw(
    perl 5.6.1
    Filter::Util::Call 0
));

&WriteAll;
