package Spiffy;
use strict;
use 5.006_001;
use warnings;
use Carp;
our $VERSION = '0.16';
our @EXPORT = ();
our @EXPORT_OK = ();
our %EXPORT_TAGS = ();

my $class_map = {};
my $options_map = {};
my $stack_frame = 0; 

sub UNIVERSAL::is_spiffy {
    my $self = shift;
    $self->isa('Spiffy');
}

sub new {
    my $self = bless {}, shift;
    while (@_) {
        my $method = shift;
        $self->$method(shift);
    }
    return $self;    
}

sub import {
    no strict 'refs'; 
    no warnings;
    local(@EXPORT, @EXPORT_OK, %EXPORT_TAGS, *spiffy_constructor);
    my $self_package = shift;
    my ($args, @values) = do {
        local *boolean_arguments = sub { qw(-base -Base) };
        local *paired_arguments = sub { qw(-package) };
        $self_package->parse_arguments(@_);
    };
    my $caller_package = $args->{-package} || caller($stack_frame);
    if ($args->{-Base} or $args->{-base}) {
        push @{"${caller_package}::ISA"}, $self_package;
        spiffy_filter() if $args->{-Base};
        @EXPORT = qw(field const stub super);
        @EXPORT_OK = qw(WWW XXX YYY ZZZ);
        %EXPORT_TAGS = (XXX => [qw(WWW XXX YYY ZZZ)]);
        *spiffy_constructor = 
          $self_package->spiffy_constructor_maker($caller_package);
        push @EXPORT, 'spiffy_constructor'
          unless defined &{"$caller_package\::spiffy_constructor"};
    }
    require Exporter;
    for my $class (reverse $self_package->all_my_bases) {
        next unless $class->isa('Spiffy');
        for my $sub (@{"$class\::EXPORT"}) {
            $class_map->{$caller_package}{$sub} = $self_package;
            $options_map->{$caller_package}{$sub} = [@_];
        }
        my %exportable = map {($_, 1)} 
          @{"$class\::EXPORT"}, @{"$class\::EXPORT_OK"};
        my @export_values = grep {
            (my $v = $_) =~ s/^[\!\:]//;
            $exportable{$v} or ${"$class\::EXPORT_TAGS"}{$v};
        } @values;
        Exporter::export($class, $caller_package, @export_values);
    }
}

sub spiffy_filter {
    eval q{use Filter::Util::Call}; die $@ if $@;
    filter_add([1]);
}

sub filter {
    my $self = shift;
    return 0 unless $self->[0];
    my $status;
    while (($status = filter_read(4096)) > 0) { }
    if ($status == 0) {
        s/^(sub\s+\w+\s+\{)(.*\n)/${1}my \$self = shift;$2/mg;
        s/^(sub\s+\w+)\s*\(\s*\)(\s+\{.*\n)/${1}${2}/mg
    }
    $self->[0] = 0;
    1;
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

sub field {
    my $package = caller;
    my ($args, @values) = do {
        no warnings;
        local *paired_arguments = sub { (qw(-package)) };
        Spiffy->parse_arguments(@_);
    };
    my ($field, $default) = @values;
    $package = $args->{-package} if defined $args->{-package};
    no strict 'refs';
    return if defined &{"${package}::$field"};
    *{"${package}::$field"} = 
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
}

sub const {
    my $package = caller;
    my ($args, @values) = do {
        no warnings;
        local *paired_arguments = sub { (qw(-package)) };
        Spiffy->parse_arguments(@_);
    };
    my ($field, $default) = @values;
    $package = $args->{-package} if defined $args->{-package};
    no strict 'refs';
    return if defined &{"${package}::$field"};
    *{"${package}::$field"} = sub { $default }
}

sub stub {
    my $package = caller;
    my ($args, @values) = do {
        no warnings;
        local *paired_arguments = sub { (qw(-package)) };
        Spiffy->parse_arguments(@_);
    };
    my ($field, $default) = @values;
    $package = $args->{-package} if defined $args->{-package};
    no strict 'refs';
    return if defined &{"${package}::$field"};
    *{"${package}::$field"} = 
    sub { 
        require Carp;
        Carp::confess 
          "Method $field in package $package must be subclassed";
    }
}

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
    my %booleans = map { ($_, 1) } $class->boolean_arguments;
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
          if defined &{"${super_class}::$method"};
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
        import($base_class, '-base');
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
    @_;
}

sub XXX {
    die yaml_dump(@_);
}

sub YYY {
    print yaml_dump(@_);
    @_;
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

    package Keen;
    use Spiffy '-Base';
    field 'mirth';
    const mood => ':-)';
    
    sub happy {
        if ($self->mood eq ':-(') {
            $self->mirth(-1);
            print "Cheer up!";
        }
        super;
    }

=head1 DESCRIPTION

"Spiffy" is a framework and methodology for doing object oriented
programming in Perl. Spiffy combines the best parts of Exporter.pm,
base.pm, mixin.pm and SUPER.pm into one magic foundation class. It
attempts to fix all the nits and warts of traditional Perl OO, in
a clean, straightforward and (perhaps someday) standard way.

Spiffy borrows ideas from other OO languages like Python, Ruby,
Java and Perl 6. It also adds a few tricks of its own. 

The most striking difference between Spiffy and other Perl object
oriented base classes, is that it has the ability to export functions.
If you create a subclass of Spiffy, all the functions that Spiffy
exports will automatically be exported by your subclass, in addition to
any more functions that you want to export. And if someone creates a
subclass of your subclass, all of those functions will be exported
automatically, and so on.

To use Spiffy or any subclass of Spiffy as a base class of your class,
you specify the C<-base> argument to the C<use> command. 

    use MySpiffyBaseModule '-base';

You can also use the traditional C<use base 'MySpiffyBaseModule';>
syntax and everything will work exactly the same. The only caveat is
that Spiffy.pm must already be loaded. That's because Spiffy rewires
base.pm on the fly to do all the Spiffy magics.

In object oriented Perl almost every subroutine is a method. Each method
gets the object passed to it as its first argument. That means
practically every subroutine starts with the line:

     my $self = shift;

Spiffy provides a simple, optional filter mechanism to insert that line
for you, resulting in cleaner code. If you figure an average method has
10 lines of code, that's 10% of your code! To turn this option on, you
just use the C<-Base> option instead of the C<-base> option. If source
filtering makes you queazy, don't use the feature. I personally find it
addictive in my quest for writing squeaky clean, maintainable code.

A useful feature of Spiffy is that it exports two functions: C<field>
and C<const> that can be used to declare the attributes of your class,
and automatically generate accessor methods for them. The only
difference between the two functions is that C<const> attributes can not
be modified; thus the accessor is much faster.

One interesting aspect of OO programming is when a method calls the same
method from a parent class. This is generally known as calling a super
method. Perl's facility for doing this is butt ugly:

    sub cleanup {
        my $self = shift;
        $self->scrub;
        $self->SUPER::cleanup(@_);
    }

Spiffy makes it, er, super easy to call super methods. You just use
the C<super> function. You don't need to pass it any arguments
because it automatically passes them on for you. Here's the same
function with Spiffy:

    sub cleanup {
        $self->scrub;
        super;
    }

Spiffy has an interesting function that it exports called
C<spiffy_constructor>. This function will generate a shortcut function
that will call the class's "new" constructor. It is smart enough to know
which class to use. All the arguments you pass to the generated
function, get passed on to each invocation of the constructor. In
addition, all the arguments you passed in the use statement for that
class, also get passed to the constructor. The C<io()> function of
IO::All is a good example of using C<spiffy_constructor>.

Spiffy has a special method for parsing arguments called
C<parse_arguments>, that it also uses for parsing its own arguments. You
declare which arguments are boolean (singletons) and which ones are
paired, with two special methods called C<boolean_arguments> and
C<paired_arguments>. Parse arguments pulls out the booleans and pairs
and returns them in an anonymous hash, followed by a list of the
unmatched arguments.

Finally, Spiffy exports a few debugging functions C<WWW>, C<XXX>, C<YYY>
and C<ZZZ>. Each of them produces a YAML dump of its arguments. WWW
warns the output, XXX dies with the output, YYY prints the output, and
ZZZ confesses the output.

That's Spiffy!

=head1 Spiffy EXPORTING

Spiffy implements a completely new idea in Perl. Modules that act both
as object oriented classes, and that also export functions. But it
takes the concept of Exporter.pm one step further; it walks the entire
C<@ISA> path of a class and honors the export specifications of each
module. Since Spiffy calls on the Exporter module to do this, you can
use all the fancy interface features that Exporter has, including tags
and negation.

Spiffy considers all the arguments that don't begin with a dash to
comprise the export specification.

    package Vehicle;
    use Spiffy '-base';
    our $SERIAL_NUMBER = 0;
    our @EXPORT = qw($SERIAL_NUMBER);

    package Bicycle;
    use Vehicle '-base', '!field';

In this case, C<Bicycle->isa('Vehicle')> and also all the things
that C<Vehicle> and C<Spiffy> export, will go into C<Bicycle>,
except C<field>.

Exporting can be very helpful when you've designed a system with
hundreds of classes, and you want them all to have access to some
functions or constants or variables. Just export them in your main base
class and every subclass will get the functions they need.

=head1 Spiffy FILTERING

By using the C<-Base> flag instead of C<-base> you never need to write the
line:

    my $self = shift;

This statement is added to every subroutine in your class by using a source
filter. The magic is simple and fast, so there is litte performance penalty
for creating clean code on par with Ruby and Python.

    package Example;
    use Spiffy '-Base';

    sub crazy {
        $self->nuts;
    }
    sub wacky { }
    sub new() {
        bless [], shift;
    }

is exactly the same as:

    package Example;
    use Spiffy '-base';

    sub crazy {my $self = shift;
        $self->nuts;
    }
    sub wacky {my $self = shift; }
    sub new {
        bless [], shift;
    }

Note that the empty parens after the subroutine C<new> keep it from
having a $self added. Also not that the extra code is added to existing lines
to ensure that line numbers are not altered.

=head1 Spiffy DEBUGGING

The XXX function is very handy for debugging because you can insert it
almost anywhere, and it will dump your data in nice clean YAML. Take the
following statement:

    my @stuff = grep { /keen/ } $self->find($a, $b);

If you have a problem with this statement, you can debug it in any of the
following ways:

    XXX my @stuff = grep { /keen/ } $self->find($a, $b);
    my @stuff = XXX grep { /keen/ } $self->find($a, $b);
    my @stuff = grep { /keen/ } XXX $self->find($a, $b);
    my @stuff = grep { /keen/ } $self->find(XXX $a, $b);

XXX is easy to insert and remove. It is also a tradition to mark
uncertain areas of code with XXX. This will make the debugging dumpers
easy to spot if you forget to take them out.

WWW and YYY are nice because they dump their arguments and then return the
arguments. This way you can insert them into many places and still have the
code run as before. Use ZZZ when you need to die with both a YAML dump and a
full stack trace.

The debugging functions are not exported by default. To export all 4 functions
use the export tag C<:XXX>.

=head1 Spiffy FUNCTIONS

This section describes the functions the Spiffy exports. The C<field>,
C<const>, C<super> and C<spiffy_constructor> functions are only exported when
you use the C<-base> or C<-Base> options.

=over 4

=item * field

Defines accessor methods for a field of your class:

    package Example;
    use Spiffy '-Base';
    
    field 'foo';
    field bar => [];

    sub lalala {
        $self->foo(42);
        push @{$self->{bar}}, $self->foo;
    }

The first parameter passed to C<field> is the name of the attribute
being defined. Accessors can be given an optional default value.
This value will be returned if no value for the field has been set
in the object.

=item * const

    const bar => 42;

The C<const> function is similar to <field> except that it is immutable.
It also does not store data in the object. You probably always want to
give a C<const> a default value, otherwise the generated method will be
somewaht useless.

=item * stub

    stub 'cigar';

The C<stub> function generates a method that will die with an appropriate
message. The idea is that subclasses must implement these methods so that the
stub methods don't get called.

=item * super

This function is called without any arguments. It will call the same
method that it is in, higher up in the ISA tree, passing it all the same
arguments.

    sub foo {
        super;             # Same as $self->SUPER::foo(@_);
        $self->bar(42);
    }

    sub new() {
        my $self = super;
        $self->init;
        return $self;
    }

C<super> will simply do nothing if there is no super method.

=item * spiffy_constructor

This function generates a function that calls the C<new()> method for your
class. It passes all its arguments on to C<new>, as well as any arguments
passed to the C<use> statement of your class.

    package Example;
    use Spiffy '-base';
    our @EXPORT = qw(foo);
    
    spiffy_constructor 'foo';

The C<spiffy_constructor> function is only exported if you use the 
'-base' option.

=back

=head1 Spiffy METHODS

This section list all of the methods that any subclass of Spiffy
automatically inherits.

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

The proper way to use a Spiffy module as a base class is with the C<-base>
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

C<use base> is also very useful when your class is not an actual module (a
separate file) but just a package in some file that has already been loaded.
C<base> will work whether the class is a module or not, while the C<-base>
syntax cannot work that way, since C<use> always tries to load a module.

=head2 base.pm Caveats

To make Spiffy work with base.pm a dirty trick was played. Spiffy swaps
C<base::import> with its own version. If the base modules are not Spiffy,
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

=head1 Spiffy TODO LIST

Spiffy is a wonderful way to do OO programming in Perl, but it is still
a work in progress. New things will be added, and things that don't work
well, might be removed.

One thing I really want to add is B<mixins>. Mixins are good medicine for
multiple inheritance headaches. The syntax will use C<-mixin> instead of
C<-base>. But I still need to think on exactly how this should work, before
implementing it. If you are an OO guru and have good ideas about how this
should work, please send me an email.

=head1 AUTHOR

Brian Ingerson <INGY@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2004. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
