# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Write a little about what this script tests.
# 
#

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Test::Deep;
use JSON;
use HTML::Form;

use WebGUI::Test; # Must use this before any other WebGUI modules
use WebGUI::Session;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Tests

my $tests = 43;
plan tests => 1 + $tests;

#----------------------------------------------------------------------------
# figure out if the test can actually run

my $e;

my $loaded = use_ok('WebGUI::Shop::PayDriver');

my $storage;

SKIP: {

skip 'Unable to load module WebGUI::Shop::PayDriver', $tests unless $loaded;

#######################################################################
#
# definition
#
#######################################################################

my $definition;

eval { $definition = WebGUI::Shop::PayDriver->definition(); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'definition takes an exception to not giving it a session variable');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a session variable',
    ),
    'definition: requires a session variable',
);

$definition = WebGUI::Shop::PayDriver->definition($session);

cmp_deeply  (
    $definition,
    [ {
        name => 'Payment Driver',
        fields => {
            label           => {
                fieldType       => 'text',
                label           => ignore(),
                hoverHelp       => ignore(),
                defaultValue    => "Credit Card",
            },
            enabled         => {
                fieldType       => 'yesNo',
                label           => ignore(),
                hoverHelp       => ignore(),
                defaultValue    => 1,
            },
            groupToUse      => {
                fieldType       => 'group',
                label           => ignore(),
                hoverHelp       => ignore(),
                defaultValue    => 1,
            },
            receiptMessage  => {
                fieldType       => 'text',
                label           => ignore(),
                hoverHelp       => ignore(),
                defaultValue    => undef,
            },
        }
    } ],
    ,
    'Definition returns an array of hashrefs',
);

$definition = WebGUI::Shop::PayDriver->definition($session, [ { name => 'Red' }]);

cmp_deeply  (
    $definition,
    [
        {
            name    => 'Red',
        },
        {
            name    => 'Payment Driver',
            fields  => ignore(),
        }
    ],
    ,
    'New data is appended correctly',
);

#######################################################################
#
# create
#
#######################################################################

my $driver;

# Test incorrect for parameters

eval { $driver = WebGUI::Shop::PayDriver->create(); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'create takes exception to not giving it a session object');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a session variable',
    ),
    'create takes exception to not giving it a session object',
);

eval { $driver = WebGUI::Shop::PayDriver->create($session); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'create takes exception to not giving it a label');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a human readable label in the hashref of options',
    ),
    'create takes exception to not giving it a hashref of options',
);

eval { $driver = WebGUI::Shop::PayDriver->create($session, 'Very human readable label'); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'create takes exception to not giving it a hashref of options');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a hashref of options',
    ),
    'create takes exception to not giving it a hashref of options',
);

eval { $driver = WebGUI::Shop::PayDriver->create($session, 'Very human readable label', {}); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'create takes exception to not giving it an empty hashref of options');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a hashref of options',
    ),
    'create takes exception to not giving it an empty hashref of options',
);

# Test functionality

my $label = 'Human Readable Label';
my $options = {
    label           => 'Fast and harmless',
    enabled         => 1,
    group           => 3,
    receiptMessage  => 'Pannenkoeken zijn nog lekkerder met spek',
};

$driver = WebGUI::Shop::PayDriver->create( $session, $label, $options );

isa_ok  ($driver, 'WebGUI::Shop::PayDriver', 'create creates WebGUI::Shop::PayDriver object');

my $dbData = $session->db->quickHashRef('select * from payment_Gateway where paymentGatewayId=?', [ $driver->getId ]);

#diag        ($driver->getId);
cmp_deeply  (
    $dbData,
    {
        paymentGatewayId    => $driver->getId,
        className           => ref $driver,
        label               => $driver->label,
        options             => q|{"group":3,"receiptMessage":"Pannenkoeken zijn nog lekkerder met spek","label":"Fast and harmless","enabled":1}|,
    },
    'Correct data written to the db',
);




#######################################################################
#
# session
#
#######################################################################

isa_ok      ($driver->session,  'WebGUI::Session',          'session method returns a session object');
is          ($session->getId,   $driver->session->getId,    'session method returns OUR session object');

#######################################################################
#
# paymentGatewayId, getId
#
#######################################################################

like        ($driver->paymentGatewayId, $session->id->getValidator, 'got a valid GUID for paymentGatewayId');
is          ($driver->getId,            $driver->paymentGatewayId,  'getId returns the same thing as paymentGatewayId');

#######################################################################
#
# className
#
#######################################################################

is          ($driver->className, ref $driver, 'className property set correctly');

#######################################################################
#
# options
#
#######################################################################

cmp_deeply  ($driver->options, $options, 'options accessor works');

#######################################################################
#
# getName
#
#######################################################################

is          ($driver->getName, 'Payment Driver', 'getName returns the human readable name of this driver');

#######################################################################
#
# get
#
#######################################################################

cmp_deeply  ($driver->get,              $driver->options,       'get works like the options method with no param passed');
is          ($driver->get('enabled'),   1,                      'get the enabled entry from the options');
is          ($driver->get('label'),     'Fast and harmless',    'get the label entry from the options');

my $optionsCopy = $driver->get;
$optionsCopy->{label} = 'And now for something completely different';
isnt        ($driver->get('label'),   'And now for something completely different', 
                'hashref returned by get() is a copy of the internal hashref');

#######################################################################
#
# getEditForm
#
#######################################################################

my $form = $driver->getEditForm;

isa_ok      ($form, 'WebGUI::HTMLForm', 'getEditForm returns an HTMLForm object');

my $html = $form->print;

##Any URL is fine, really
my @forms = HTML::Form->parse($html, 'http://www.webgui.org');
is          (scalar @forms, 1, 'getEditForm generates just 1 form');

my @inputs = $forms[0]->inputs;
is          (scalar @inputs, 7, 'getEditForm: the form has 7 controls');

my @interestingFeatures;
foreach my $input (@inputs) {
    my $name = $input->name;
    my $type = $input->type;
    push @interestingFeatures, { name => $name, type => $type };
}

cmp_deeply(
    \@interestingFeatures,
    [
        {
            name    => undef,
            type    => 'submit',
        },
        {
            name    => 'paymentGatewayId',
            type    => 'hidden',
        },
        {
            name    => 'className',
            type    => 'hidden',
        },
        {
            name    => 'label',
            type    => 'text',
        },
        {
            name    => 'enabled',
            type    => 'radio',
        },
        {
            name    => 'groupToUse',
            type    => 'option',
        },
        {
            name    => 'receiptMessage',
            type    => 'text',
        },
    ],
    'getEditForm made the correct form with all the elements'

);


#######################################################################
#
# new
#
#######################################################################

my $oldDriver;

eval { $oldDriver = WebGUI::Shop::PayDriver->new(); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'new takes exception to not giving it a session object');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a session variable',
    ),
    'new takes exception to not giving it a session object',
);

eval { $oldDriver = WebGUI::Shop::PayDriver->new($session); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'new takes exception to not giving it a paymentGatewayId');
cmp_deeply  (
    $e,
    methods(
        error => 'Must provide a paymentGatewayId',
    ),
    'new takes exception to not giving it a paymentGatewayId',
);

eval { $oldDriver = WebGUI::Shop::PayDriver->new($session, 'notEverAnId'); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::ObjectNotFound', 'new croaks unless the requested paymentGatewayId object exists in the db');
cmp_deeply  (
    $e,
    methods(
        error => 'paymentGatewayId not found in db',
        id    => 'notEverAnId',
    ),
    'new croaks unless the requested paymentGatewayId object exists in the db',
);

my $driverCopy = WebGUI::Shop::PayDriver->new($session, $driver->getId);

is          ($driver->getId,           $driverCopy->getId,     'same id');
is          ($driver->className,       $driverCopy->className, 'same className');
cmp_deeply  ($driver->options, $driverCopy->options,   'same options');

TODO: {
    local $TODO = 'tests for new';
    ok(0, 'Test broken options in the db');
}

#######################################################################
#
# set
#
#######################################################################

eval { $driver->set(); };
$e = Exception::Class->caught();
isa_ok      ($e, 'WebGUI::Error::InvalidParam', 'set takes exception to not giving it a hashref of options');
cmp_deeply  (
    $e,
    methods(
        error => 'set was not sent a hashref of options to store in the database',
    ),
    'set takes exception to not giving it a hashref of options',
);

my $newOptions = {
    label           => 'Yet another label',
    enabled         => 0,
    group           => 4,
    receiptMessage  => 'Dropjes!',
};

$driver->set($newOptions);
my $storedOptions = $session->db->quickScalar('select options from payment_Gateway where paymentGatewayId=?', [
    $driver->getId,
]);
cmp_deeply(
    $newOptions,
    from_json($storedOptions),
    ,
    'set() actually stores data',
);


#######################################################################
#
# delete
#
#######################################################################

$driver->delete;

my $count = $session->db->quickScalar('select count(*) from payment_Gateway where paymentGatewayId=?', [
    $driver->paymentGatewayId
]);

is          ($count, 0, 'delete deleted the object');

undef $driver;


}

#----------------------------------------------------------------------------
# Cleanup
END {
    #$session->db->write('delete from payment_Gateway');
}
