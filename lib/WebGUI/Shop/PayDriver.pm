package WebGUI::Shop::PayDriver;

use strict;

use Class::InsideOut qw{ :std };
use Carp qw(croak);
use Tie::IxHash;
use WebGUI::International;
use WebGUI::HTMLForm;
use WebGUI::Exception::Shop;
use JSON;

=head1 NAME

Package WebGUI::Shop::PayDriver

=head1 DESCRIPTION

This package is the base class for all modules which implement a pyament driver.

=head1 SYNOPSIS

 use WebGUI::Shop::PayDriver;

 my $tax = WebGUI::Shop::PayDriver->new($session);

=head1 METHODS

These subroutines are available from this package:

=cut

readonly session            => my %session;
readonly className          => my %className;
readonly paymentGatewayId   => my %paymentGatewayId;
readonly options            => my %options;
readonly label              => my %label;

#-------------------------------------------------------------------

=head2 _buildObj (  )

Private method used to build objects, shared by new and create.

=cut

sub _buildObj {
    my ($class, $session, $requestedClass, $paymentGatewayId, $label, $options) = @_;
    my $self    = {};
    bless $self, $requestedClass;
    register $self;

    my $id                      = id $self;

    $session{ $id }             = $session;
    $paymentGatewayId{ $id }    = $paymentGatewayId;
    $label{ $id }               = $label;
    $options{ $id }             = $options;
    $className{ $id }           = $requestedClass;

    return $self;
}


#-------------------------------------------------------------------

=head2 className (  )

Accessor for the className of the object.  This is the name of the driver that is used
to do calculations.

=cut

#-------------------------------------------------------------------

=head2 create ( $session, $label, $options )

Constructor for new WebGUI::Shop::PayDriver objects.  Returns a WebGUI::Shop::PayDriver object.
To access driver objects that have already been configured, use C<new>.

=head3 $session

A WebGUI::Session object.

=head4 $label

A human readable label for this payment.

=head4 $options

A list of properties to assign to this PayDriver.  See C<definition> for details.

=cut

sub create {
    my $class   = shift;
    my $session = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide a session variable})
        unless ref $session eq 'WebGUI::Session';
    my $label   = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide a human readable label in the hashref of options})
        unless $label;
    my $options = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide a hashref of options})
        unless ref $options eq 'HASH' and scalar keys %{ $options };

    # Generate a unique id for this payment
    my $paymentGatewayId = $session->id->generate;

    # Build object
    my $self = WebGUI::Shop::PayDriver->_buildObj($session, $class, $paymentGatewayId, $label, $options);

    # and persist this instance in the db
    $session->db->write('insert into payment_Gateway (paymentGatewayId, label, className) VALUES (?,?,?)', [
        $paymentGatewayId, 
        $label,
        $class,
    ]);
    
    # Set the options via the set method because set() will automatically serialize the options hash
    $self->set($options);

    return $self;
}

#-------------------------------------------------------------------

=head2 definition ( $session )

This subroutine returns an arrayref of hashrefs, used to validate data put into
the object by the user, and to automatically generate the edit form to show
the user.

=cut

sub definition {
    my $class      = shift;
    my $session    = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide a session variable})
        unless ref $session eq 'WebGUI::Session';
    my $definition = shift || [];

    my $i18n = WebGUI::International->new($session, 'PayDriver');

    tie my %fields, 'Tie::IxHash';
    %fields = (
        label           => {
            fieldType       => 'text',
            label           => $i18n->echo('label'),
            hoverHelp       => $i18n->echo('label help'),
            defaultValue    => "Credit Card",
        },
        enabled         => {
            fieldType       => 'yesNo',
            label           => $i18n->echo('enabled'),
            hoverHelp       => $i18n->echo('enabled help'),
            defaultValue    => 1,
        },
        groupToUse      => {
            fieldType       => 'group',
            label           => $i18n->echo('who can use'),
            hoverHelp       => $i18n->echo('who can use help'),
            defaultValue    => 1,
        },
        receiptMessage  => {
            fieldType       => 'text',
            label           => $i18n->echo('receipt message'),
            hoverHelp       => $i18n->echo('receipt message help'),
            defaultValue    => undef,
        },
    );

    my %properties = (
        name    => 'Payment Driver',
        fields  => \%fields,
    );
    push @{ $definition }, \%properties;

    return $definition;
}

#-------------------------------------------------------------------

=head2 delete ( )

Removes this PayDriver object from the db.

=cut

sub delete {
    my $self = shift;

    $self->session->db->write('delete from payment_Gateway where paymentGatewayId=?', [
        $self->getId,
    ]);

    return;
}

#-------------------------------------------------------------------

=head2 get ( [ $param ] )

This is an enhanced accessor for the options property.  By default,
it returns all the options as a hashref.  If the name of a key
in the hash is passed, it will only return that value from the
options hash.

=head3 $param

An optional parameter.  If it matches the key of a hash, it will
return the value from the options hash.

=cut

sub get {
    my $self  = shift;
    my $param = shift;
    my $options = $self->options;
    if (defined $param) {
        return $options->{ $param };
    }
    else {
        return { %$options };
    }
}

#-------------------------------------------------------------------

=head2 getButton ( )

Returns the form that will take the user to check out.

=cut

sub getButton {
    my $self = shift;
}

#-------------------------------------------------------------------

=head2 getEditForm ( )

Returns the configuration form for the options of this plugin.

=cut

sub getEditForm {
    my $self = shift;
    
    my $definition = $self->definition($self->session);
    my $form = WebGUI::HTMLForm->new($self->session);
    $form->submit;
    $form->hidden(
        name  => 'paymentGatewayId',
        value => $self->getId,
    );
    $form->hidden(
        name  => 'className',
        value => $self->className,
    );
    $form->dynamicForm($definition, 'fields', $self);

    return $form;
}

#-------------------------------------------------------------------

=head2 getId ( )

Returns the paymentGatewayId. 

=cut

sub getId {
    my $self = shift;

    return $self->paymentGatewayId;
}

#-------------------------------------------------------------------

=head2 getName ( )

Return a human readable name for this driver. Never overridden in the
subclass, instead specified in definition with the name "name".

=cut

sub getName {
    my $self = shift;
    my $definition = $self->definition($self->session);
    return $definition->[0]->{name};
}

#-------------------------------------------------------------------

=head2 new ( $session, $paymentGatewayId )

Looks up an existing PayDriver in the db by paymentGatewayId and returns
that object.

=cut

sub new {
    my $class               = shift;
    my $session             = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide a session variable})
        unless ref $session eq 'WebGUI::Session';
    my $paymentGatewayId    = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide a paymentGatewayId})
        unless defined $paymentGatewayId;

    # Fetch the instance data from the db
    my $properties = $session->db->quickHashRef('select * from payment_Gateway where paymentGatewayId=?', [
        $paymentGatewayId,
    ]);
    WebGUI::Error::ObjectNotFound->throw(error => q{paymentGatewayId not found in db}, id => $paymentGatewayId)
        unless scalar keys %{ $properties };

    croak "Somehow, the options property of this object, $paymentGatewayId, got broken in the db"
        unless exists $properties->{options} and $properties->{options};

    #### TODO: Fix deprecated json sub
    my $options = from_json($properties->{options});

    my $self = WebGUI::Shop::PayDriver->_buildObj($session, $class, $paymentGatewayId, $properties->{ label }, $options);

    return $self;
}

#-------------------------------------------------------------------

=head2 options (  )

Accessor for the driver properties.  This returns a hashref
any driver specific properties.  To set the properties, use
the C<set> method.

=cut

#-------------------------------------------------------------------

=head2 session (  )

Accessor for the session object.  Returns the session object.

=cut

#-------------------------------------------------------------------

=head2 set ( $options )

Setter for user configurable options in the payment objects.

=head4 $options

A list of properties to assign to this PayDriver.  See C<definition> for details.  The options are
flattened into JSON and stored in the database as text.  There is no content checking performed.

=cut

#### TODO: decide on what set() sets. Ie. does it only set options, or also label?
sub set {
    my $self        = shift;
    my $properties  = shift;
    WebGUI::Error::InvalidParam->throw(error => 'set was not sent a hashref of options to store in the database')
        unless ref $properties eq 'HASH' and scalar keys %{ $properties };

    my $jsonOptions = to_json($properties);
    $self->session->db->write('update payment_Gateway set options=? where paymentGatewayId=?', [
        $jsonOptions,
        $self->paymentGatewayId
    ]);

    return;
}

#-------------------------------------------------------------------

=head2 paymentGatewayId (  )

Accessor for the unique identifier for this PayDriver.  The paymentGatewayId is 
a GUID.

=cut

1;
