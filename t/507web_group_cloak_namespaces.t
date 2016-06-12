use lib qw(t/lib);
use GMSTest::Common 'approved_group';
use GMSTest::Database;
use Test::More;
use Test::MockModule;

# We don't want this right now.

my $mockModel = new Test::MockModule ('GMS::Web::Model::Atheme');
$mockModel->mock ('session' => sub { });

my $mock = Test::MockModule->new('GMS::Atheme::Client');
$mock->mock('new', sub { });
$mock->mock('notice_staff_chan', sub {});


need_database 'approved_group';

use ok 'Test::WWW::Mechanize::Catalyst' => 'GMS::Web';

my $ua = Test::WWW::Mechanize::Catalyst->new;

my $mockGroup = new Test::MockModule('GMS::Domain::Group');
$mockGroup->mock ('new',
    sub {
        my (undef, undef, $group) = @_;
        $group;
    });

my $mockSession = new Test::MockModule ('GMS::Web::Model::Atheme');

$mockSession->mock ('session', sub {
    });

$ua->get_ok("http://localhost/", "Check root page");

$ua->get_ok("http://localhost/login", "Check login page works");
$ua->content_contains("Login to GMS", "Check login page works");

$ua->submit_form(
    fields => {
        username => 'test01',
        password => 'tester01'
    }
);

$ua->content_contains("You are now logged in as test01", "Check we can log in");

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit cloak namespaces page works");

$ua->content_contains("example", "namespace is in the page");

my $schema = GMS::Schema->do_connect;

my $ns = $schema->resultset('CloakNamespace')->find({ namespace => 'example' });
ok($ns, "Check NS exists");

my $group = $schema->resultset('Group')->find({ group_name => 'group01' });
ok($group, "Check group exists");

is $group->cloak_namespaces, 2, "Group initially has 2 namespaces";

$ua->submit_form(
    fields => {
        status_1 => 'deleted',
        edit_1   => 1,
        namespace => ''
    }
);

$ua->content_contains("Successfully submitted the cloak namespace change request. Please wait for staff to approve the change", "Editing namespaces works");

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit cloak namespaces page works");

$ua->content_contains("At least one of the group's namespaces has a change request pending", "Pending change recognised");

$ua->content_contains("'deleted'  selected", 'Deleted option is selected, pending change status is shown');

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit cloak namespaces page works");

$ua->submit_form(
    fields => {
        namespace => 'example'
    }
);

$ua->content_contains("already taken", "Trying to add a currently active namespace to your group fails");

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit cloak namespaces page works");

$ua->submit_form(
    fields => {
        namespace => 'example1'
    }
);

$ua->content_contains("Successfully submitted the cloak namespace change request. Please wait for staff to approve the change", "Adding a new namespace succeeds");

is $group->cloak_namespaces, 3, "Group now has 3 cloak namespaces";
is $group->active_cloak_namespaces, 1, "Group still has one active namespace, since requested namespace isn't active";

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit cloak namespaces page works");

$ua->text_like(qr/Pending namespaces for.*example1/, 'Pending namespaces are shown');

$ua->submit_form(
    fields => {
        namespace => 'test'
    }
);
$ua->content_contains("Successfully submitted the cloak namespace change request. Please wait for staff to approve the change", "We can re-add previously deleted namespace");

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit channel namespaces page works");

$ua->submit_form(
    fields => {
        namespace => 'test'
    }
);


$ua->content_contains("That namespace is already taken", "Errors since we already requested reactivation");

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Edit channel namespaces page works");

$ua->submit_form(
    fields => {
        namespace => '.'
    }
);
$ua->content_contains("Cloak namespaces may not begin with a dot.", "Errors are shown");

my $group = $schema->resultset('Group')->find({ group_name => 'group01' });
my $admin = $schema->resultset('Account')->find({ accountname => 'admin01' });

$group->change( $admin, 'workflow_change', { status => 'pending_staff' });

$ua->get_ok("http://localhost/group/1/edit_cloak_namespaces", "Cloak namespace page works");
$ua->content_contains("The group is not active", "Can't assign cloak namespaces on inactive group");

done_testing;
