package Spiffy;
use strict;
use 5.006_001;
use warnings;
use Carp;
our $VERSION = '0.15';

my $class_map = {};
my $options_map = {};
my $stack_frame = 0; 

sub UNIVERSAL::is_spiffy {
    my $self = shift;
    $self->isa('Spiffy');
}

sub new {
    bless {}, shift;
}

sub import {
    my $self_package = shift;
    my ($args, @values) = $self_package->parse_arguments(@_);
    my %export_map = map { ($_, 1) } @values;
    my $caller_package = $args->{package} || caller($stack_frame);
    no strict 'refs';
    if ($args->{-base}) {
        push @{"${caller_package}::ISA"}, $self_package;
        for my $sub (qw(import attribute field const stub super 
                        WWW XXX YYY ZZZ)
        ) {
            unless (defined $export_map{"!$sub"} or
                    defined &{"${caller_package}::$sub"}
                   ) {
                *{"${caller_package}::$sub"} = \&{"${self_package}::$sub"};
            }
        }
        unless (defined $export_map{'!spiffy_constructor'} or
                defined &{"${caller_package}::spiffy_constructor"}) {
            *{"${caller_package}::spiffy_constructor"} = 
              $self_package->spiffy_constructor_maker($caller_package);
        }
    }
    for my $class ($self_package->all_my_bases) {
        next unless $class->isa('Spiffy');
        for my $sub (@{"${class}::EXPORT"}) {
            unless (defined &{"${caller_package}::$sub"}) {
                *{"${caller_package}::$sub"} = \&{"${class}::$sub"};
                $class_map->{$caller_package}{$sub} = $self_package;
                $options_map->{$caller_package}{$sub} = [@_];
            }
        }
    }
}

sub base {
    push @_, '-base';
    goto &import;
}

sub all_my_bases {
    my $class = shift;
    my @bases = ($class);
    no strict 'refs';
    for my $base_class (@{"${class}::ISA"}) {
        push @bases, $base_class->all_my_bases;
    }
    my $used = {};
    my @x = grep {not $used->{$_}++} @bases;
}

{
    no warnings;
    *attribute = \&field;
}
sub field {
    my $package = caller;
    my ($args, @values) = do {
        no warnings;
        local *boolean_arguments = sub { (qw(-stub -const)) };
        local *paired_arguments = sub { (qw(-package)) };
        Spiffy->parse_arguments(@_);
    };
    my ($field, $default) = @values;
    $package = $args->{-package} if defined $args->{-package};
    no strict 'refs';
    return if defined &{"${package}::$field"};
    *{"${package}::$field"} = 
    defined $args->{-stub} ?
        sub { 
            require Carp;
            Carp::confess 
              "Method $field in package $package must be subclassed";
        }
    : defined $args->{-const} ? sub { $default }
    :
        sub {
            my $self = shift;
            unless (exists $self->{$field}) {
                $self->{$field} = 
                  ref($default) eq 'ARRAY' ? [] :
                  ref($default) eq 'HASH' ? {} : 
                  $default;
            }
            return $self->{$field} unless @_;
            $self->{$field} = shift;
        }
    ;
}

sub const { (-const => @_) }
sub stub { (-stub => @_) }

sub spiffy_constructor_maker {
    my $spiffy_package = shift;
    my $caller_package = shift;
    no strict 'refs';
    sub {
        my $name = shift;
        return if defined &{"${caller_package}::$name"};
        *{"${caller_package}::$name"} =
            sub {
                my $package = caller;
                my $class = $class_map->{$package}{$name}
                  or die "No class for ${package}::$name";
                my $defaults = $options_map->{$package}{$name};
                $class->new(@$defaults, @_);
            };
    }
}

sub parse_arguments {
    my $class = shift;
    my ($args, @values) = ({}, ());
    my %booleans = map { ($_, 1) } ($class->boolean_arguments, '-base');
    my %pairs = map { ($_, 1) } $class->paired_arguments;
    while (@_) {
        my $elem = shift;
        if (defined $elem and defined $booleans{$elem}) {
            $args->{$elem} = (@_ and $_[0] =~ /^[01]$/)
            ? shift
            : 1;
        }
        elsif (defined $elem and defined $pairs{$elem} and @_) {
            $args->{$elem} = shift;
        }
        else {
            push @values, $elem;
        }
    }
    return wantarray ? ($args, @values) : $args;        
}

sub boolean_arguments { () }
sub paired_arguments { () }

#===============================================================================
# It's super, man.
#===============================================================================
package DB;
sub super_args { my @dummy = caller(2); @DB::args }
package Spiffy;

sub super {
    @_ = DB::super_args;
    my $class = ref $_[0] ? ref $_[0] : $_[0];
    (my $method = (caller(1))[3]) =~ s/.*:://;
    my $caller_class = caller;
    my @super_classes = grep {
        $_ ne $caller_class;
    } $class->all_my_bases;
    for my $super_class (@super_classes) {
        no strict 'refs';
        next if $super_class eq $class;
        goto &{"${super_class}::$method"}
          if $super_class->can($method);
    }
    return;
}

#===============================================================================
# This code deserves a spanking, because it is being very naughty.
# It is exchanging base.pm's import() for its own, so that people
# can use base.pm with Spiffy modules, without being the wiser.
#===============================================================================
my $real_base_import;

BEGIN {
    require base unless defined $INC{'base.pm'};
    $real_base_import = \&base::import;
    no warnings;
    *base::import = \&spiffy_base_import;
}

my $i = 0;
while (my $caller = caller($i++)) {
    next unless $caller eq 'base';
    croak 
    "Spiffy.pm must be loaded before calling 'use base' with a Spiffy module\n",
    "See the documentation of Spiffy.pm for details\n  ";
}

sub spiffy_base_import {
    my @base_classes = @_;
    shift @base_classes;
    no strict 'refs';
    goto &$real_base_import
      unless grep {
          eval "require $_" unless %{"$_\::"};
          $_->isa('Spiffy');
      } @base_classes;
    my $inheritor = caller(0);
    for my $base_class (@base_classes) {
        next if $inheritor->isa($base_class);
        croak "Can't mix Spiffy and non-Spiffy classes in 'use base'.\n", 
              "See the documentation of Spiffy.pm for details\n  "
          unless $base_class->isa('Spiffy');
        $stack_frame = 1; # tell import to use differnt caller
        import($base_class, $inheritor, '-base');
        $stack_frame = 0;
    }
}
# END of naughty code.

#===============================================================================
# Debugging support
#===============================================================================
sub yaml_dump {
    require YAML;
    {
        no warnings;
        $YAML::UseVersion = 0;
    }
    YAML::Dump(@_);
}

sub WWW {
    warn yaml_dump(@_);
}

sub XXX {
    die yaml_dump(@_);
}

sub YYY {
    print yaml_dump(@_);
}

sub ZZZ {
    require Carp;
    Carp::confess yaml_dump(@_);
}

1;
__END__

=head1 NAME

Spiffy - Spiffy Perl Interface Framework For You

=head1 SYNOPSIS

    use Spiffy '-base';
   
=head1 DESCRIPTION

"Spiffy" is a Perl module interface methodology and framework. It is a
base class for implementing other Perl modules using my favorite tricks.

Spiffy is different from other Perl object oriented base classes, in
that it has the ability to export functions. If you create a subclass of
Spiffy, all the functions that Spiffy exports will automatically be
exported by your subclass, in addition to any more functions that you
want to export. And if someone creates a subclass of your subclass, all
of those functions will be exported automatically, and so on.

Spiffy has an interesting function that it exports called
C<spiffy_constructor()>. This function will generate a function that
will call the class's "new()" constructor. It is smart enough to know
which class to use. All the arguments you pass to the generated
function, get passed on to the constructor. In addition, all the
arguments you passed in the use statement for that class, also get
passed to the constructor. The C<io()> function of IO::All is an
example.

Spiffy has an interesting way of parsing arguments that you pass to
C<spiffy_constructor> generated functions, and also to C<use>
statements. You declare which arguments are boolean (singletons) and
which ones are paired, with two special functions called
C<boolean_arguments> and C<paired_arguments>.

Spiffy also exports a function called C<field> that you can use to
declare the fields of your class. The C<field> function will generate
accessors for you. These fields can be given defaults values as well.

Perhaps this is all best described through an example. (These are meant
to be three separate files):

    use Something qw(-cool);
    foo;
    bar;
    my $thing = thing(-name => 'Jimmy');
    $thing->size(11);
    
    package Something;
    use Thing '-base';
    field size => 0;
    @EXPORT = qw(foo);
    sub foo { ... }
    sub paired_arguments {
        my $self = shift;
        ('-name', $self->SUPER::paired_arguments)
    }
    1;
   
    package Thing;
    use Spiffy '-base';
    @EXPORT = qw(bar thing);
    sub bar { ... }
    spiffy_constructor 'thing';
    sub boolean_arguments {
        my $self = shift;
        ('-cool', $self->SUPER::boolean_arguments)
    }
    1;

The top level program uses a module called C<Something>. C<Something>
exports 3 functions: C<foo>, C<bar> and C<thing>. The C<thing> function
returns a new C<Something> object. The C<new()> method for the
C<Something> class is called with the arguments C<<-name => 'Jimmy'>>,
and also with the arguments C<<-cool => 1>>. 

C<Something> is a subclass of C<Thing> and C<Thing> is a subclass of
C<Spiffy>. This is accomplished by importing the base classes with
the special parameter C<-base>. This is similar to using the
C<base.pm> module except that it does all the extra Spiffy magic.

That's Spiffy!

=head1 Spiffy FUNCTIONS

Spiffy defines a few functions that make it Spiffy.

=over 4

=item * field

Defines accessor methods for a field of your class:

    package Example;
    use Spiffy '-base';
    
    field 'foo';
    field const bar => 42;

The C<const> is not a parameter but another function. It tells C<field>
to generate an immutable accessor. The first parameter is the name of
the field. The second optional argument is the default value.

The C<field> function is only exported if you use the '-base' option.

=item * spiffy_constructor

This function generates a function that calls the C<new()> method for your
class. It passes all its arguments on to C<new>, as well as any arguments
passed to the C<use> statement of your class.

    package Example;
    use Spiffy '-base';
    @EXPORT = qw(foo);
    
    spiffy_constructor 'foo';

The C<spiffy_constructor> function is only exported if you use the 
'-base' option.

=back

=head1 Spiffy METHODS

The following subroutines are all methods rather than functions and should be
called as such. For example:

    $self->parse_arguments(@arguments);

=over 4

=item * is_spiffy

Returns true if an object is Spiffy. This method is UNIVERSAL so it can be
called on all objects.

=item * parse_arguments

This method takes a list of arguments and groups them into pairs. It
allows for boolean arguments which may or may not have a value
(defaulting to 1). The method returns a hash reference of all the pairs
as keys and values in the hash. Any arguments that cannot be paired, are
returned as a list. Here is an example:

    sub boolean_arguments { qw(-has_spots -is_yummy) }
    sub paired_arguments { qw(-name -size) }
    my ($pairs, @others) = $self->parse_arguments(
        'red', 'white',
        -name => 'Ingy',
        -has_spots =>
        -size => 'large',
        'black',
        -is_yummy => 0,
    );

After this call, C<$pairs> will contain:

    {
        -name => 'Ingy',
        -has_spots => 1,
        -size => 'large',
        -is_yummy => 0,
    }

and C<$others> will contain 'red', 'white', and 'black'.

=item * boolean_arguments

Returns the list of arguments that are recognized as being boolean. Override
this method to define your own list.

=item * paired_arguments

Returns the list of arguments that are recognized as being paired. Override
this method to define your own list.

=item * super

This function is called without any arguments. It will call the same method
that it is in, one level higher in the ISA tree, passing it all the same
arguments.

    sub foo {
        my self = shift;
        super;             # Same as $self->SUPER::foo(@_);
        $self->bar(42);
    }

=item * base

This function will call Spiffy::import at runtime, basically making the
calling package a subclass of whatever object or class base() was
called on.

    package XXX;
    BEGIN { require YYY; YYY->base }

is the same as:

    package XXX;
    use YYY '-base';

=item * XXX

The C<XXX> method will die with a YAML Dump of all the arguments passed
to it. Used for debugging.

=back

=head1 Spiffy ARGUMENTS

When you C<use> the Spiffy module or a subclass of it, you can pass it a
list of arguments. These arguments are parsed using the C<parse_arguments>
method described above. Any arguments that are pairs are passed on to
calls to a spiffy_constructor generated function. The special argument
C<-base>, is used to make the current package a subclass of the Spiffy
module being used.

Any non-paired parameters act like a normal import list; just like those
used with the Exporter module.

=head1 USING Spiffy WITH base.pm

The proper way to use a Spiffy module as a base class is with the <-base>
parameter to the C<use> statement. This differs from typical modules where you
would want to C<use base>.

    package Something;
    use Spiffy::Module '-base';
    use base 'NonSpiffy::Module';

Now it may be hard to keep track of what's Spiffy and what is not.
Therefore Spiffy has actually been made to work with base.pm. You can
say:

    package Something;
    use base 'Spiffy::Module';
    use base 'NonSpiffy::Module';

==head2 base.pm Caveats

To make Spiffy work with base.pm a dirty trick was played. Spiffy swaps
<base::import> with its own version. If the base modules are not Spiffy,
Spiffy calls the original base::import. If the base modules are Spiffy,
then Spiffy does its own thing.

There are two caveats.

=over 4

=item * Spiffy must be loaded first.

If Spiffy is not loaded and C<use base> is invoked on a Spiffy module,
Spiffy will die with a useful message telling the author to read this
documentation. That's because Spiffy needed to do the import swap
beforehand.

If you get this error, simply put a statement like this up front in
your code:

    use Spiffy ();

=item * No Mixing

C<base.pm> can take multiple arguments. And this works with Spiffy as
long as all the base classes are Spiffy, or they are all non-Spiffy. If
they are mixed, Spiffy will die. In this case just use separate C<use
base> statements.

=back

=head1 AUTHOR

Brian Ingerson <INGY@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2004. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
