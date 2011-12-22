use strict; use warnings; use warnings (FATAL => qw(misc numeric uninitialized)); # use autodie;

use Test::More;

# POSSIBLE MOOSE BUG #1. DURING A REBLESS, REGULAR TRIGGERS WILL FIRE FOR ANY ATTRIBUTES THAT HAVE
# AN UNDEFINED init_arg AND BEGAN THE REBLESS WITH A VALUE.

{ package Test1RegTrig; use Moose;

    our $FIRINGS;

    has foo => (init_arg => undef, is => 'rw', isa => 'Any', trigger => sub { $FIRINGS++ });
}

{ package Test1RegTrig::Extended; use Moose; extends 'Test1RegTrig'; }

TODO: {

    local $TODO = 'demo of possible Moose bug';

    my $obj = Test1RegTrig->new;

    $obj->foo('FOO');

    $Test1RegTrig::FIRINGS = 0;

    Test1RegTrig::Extended->meta->rebless_instance($obj);

    cmp_ok($Test1RegTrig::FIRINGS, '==', 0, 'regular trigger does NOT fire on attribute with existing value and undefined init_arg during rebless');
}

{ package Test1OmniTrig; use Moose; use MooseX::OmniTrigger;

    our $FIRINGS;

    has foo => (init_arg => undef, is => 'rw', isa => 'Any', omnitrigger => sub { $FIRINGS++ });
}

{ package Test1OmniTrig::Extended; use Moose; extends 'Test1OmniTrig'; }

{
    my $obj = Test1OmniTrig->new;

    $obj->foo('FOO');

    $Test1OmniTrig::FIRINGS = 0;

    Test1OmniTrig::Extended->meta->rebless_instance($obj);

    cmp_ok($Test1OmniTrig::FIRINGS, '==', 0, 'omnitrigger does NOT fire on attribute with existing value and undefined init_arg during rebless');
}

# POSSIBLE MOOSE BUG #2. (DEEP BREATH.) DURING CONSTRUCTION OR REBLESSING, GIVEN TWO ATTRIBUTES "X"
# AND "Y" THAT DON'T HAVE UNDEFINED init_argS AND ARE SUPPLIED WITH NEW VALUES VIA THE CONSTRUCTOR,
# AND GIVEN THAT X'S TRIGGER CLEARS Y'S VALUE, AND GIVEN THAT $Y->should_coerce IS FALSE, THEN (DEEP
# BREATH), WHEN X FIRES ON ACCOUNT OF ITS NEW VALUE NEAR THE END OF CONSTRUCTION/FIXUP (ASSUMING X
# FIRES BEFORE Y, WHICH IT MIGHT NOT), Y'S TRIGGER WILL RECEIVE AS ITS "NEW VALUE" ARGUMENT THE
# VALUE SUPPLIED VIA THE CONSTRUCTOR, EVEN THOUGH Y NO LONGER *HAS* A VALUE. (GASPING AND A LITTLE
# WEEPING.)

BEGIN { package _SortedAttributes;

    Moose::Exporter->setup_import_methods;

    my (undef, undef, $init_meta_method) = Moose::Exporter->build_import_methods(

        install => [qw(import unimport)],

        class_metaroles => {

            class => [qw(_SortedAttributes::MetaRole::Class)],
        },
    );

    sub init_meta { goto $init_meta_method }
}

BEGIN { package _SortedAttributes::MetaRole::Class;

    use Moose::Role;

    around get_all_attributes => sub {

        my ($orig_method, $self_aka_class) = (shift, shift);

        my @attributes = $self_aka_class->$orig_method(@_);

        return sort({ $a->name cmp $b->name } @attributes);
    };
}

{ package Test2RegTrig; use Moose; BEGIN { _SortedAttributes->import }

    our @NEWVALS;

    has X => (is => 'rw', isa => 'Any', trigger => sub { shift->clear_B });

    has Y => (is => 'rw', isa => 'Any', clearer => 'clear_B', trigger => sub {

        my ($self, $new, $old) = (shift, @_);

        push(@NEWVALS,

            [                     defined($new           ) ? $new            : 'UNDEF'          ],
            [exists($self->{Y}) ? defined(     $self->{Y}) ?      $self->{Y} : 'UNDEF' : 'NOVAL'],
        );
    });
}

{ package Test2RegTrig::Extended; use Moose; extends 'Test2RegTrig'; }

TODO: {

    local $TODO = 'demo of possible Moose bug';

    my $obj = Test2RegTrig->new({X => 'X', Y => 'Y'});

    is_deeply($Test2RegTrig::NEWVALS[0], $Test2RegTrig::NEWVALS[1], 'newval arg equals actual current value in regular trigger fired during construction');

    @Test2RegTrig::NEWVALS = ();

    Test2RegTrig::Extended->meta->rebless_instance($obj, X => 'FRELL', Y => 'YOTZ');

    is_deeply($Test2RegTrig::NEWVALS[0], $Test2RegTrig::NEWVALS[1], 'newval arg equals actual current value in regular trigger fired during rebless');
}

{ package Test2OmniTrig; use Moose; use MooseX::OmniTrigger;

    our @NEWVALS;

    has X => (is => 'rw', isa => 'Any', omnitrigger => sub { shift->clear_B });

    has Y => (is => 'rw', isa => 'Any', clearer => 'clear_B', omnitrigger => sub {

        my ($self, $attr_name, $new, $old) = (shift, @_);

        push(@NEWVALS,

            [@$new                    ? defined($new->[0]           ) ? $new->[0]            : 'UNDEF' : 'NOVAL'],
            [      exists($self->{Y}) ? defined(          $self->{Y}) ?           $self->{Y} : 'UNDEF' : 'NOVAL'],
        );
    });
}

{ package Test2OmniTrig::Extended; use Moose; extends 'Test2OmniTrig'; }

{
    @Test2OmniTrig::NEWVALS = ();

    my $obj = Test2OmniTrig->new({X => 'X', Y => 'Y'});

    is_deeply($Test2OmniTrig::NEWVALS[0], $Test2OmniTrig::NEWVALS[1], 'newval arg equals actual current value in omnitrigger fired during construction');

    @Test2OmniTrig::NEWVALS = ();

    Test2OmniTrig::Extended->meta->rebless_instance($obj, X => 'FRELL', Y => 'YOTZ');

    is_deeply($Test2OmniTrig::NEWVALS[0], $Test2OmniTrig::NEWVALS[1], 'newval arg equals actual current value in omnitrigger fired during rebless');
}

done_testing;
