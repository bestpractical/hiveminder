use warnings;
use strict;

use BTDT::Test tests => 32;
use BTDT::Test::IM;

setup_screenname('gooduser@example.com' => 'tester');

my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');

# permissions {{{
for my $type (qw/project milestone/) {
    im_like($type, qr/Nothing to see here/, "this error should improve :)");
}

my $bps = BTDT::Model::Group->new(current_user => $gooduser);
$bps->create(
    name        => 'Best Practical',
    description => 'The group with the project bits',
);

for my $type (qw/project milestone/) {
    im_like($type, qr/I don't understand/, "this error should improve :)");
}
# }}}

my $clean_garage = BTDT::Project->new(current_user => $gooduser);
my ($ok, $msg) = $clean_garage->create(
    summary => 'Clean garage',
    group   => $bps,
);
ok($ok, $msg);

my $clean_kitchen = BTDT::Project->new(current_user => $gooduser);
($ok, $msg) = $clean_kitchen->create(
    summary => 'Clean kitchen',
    group   => $bps,
);
ok($ok, $msg);

my ($sweep_floor) = create_tasks('sweep floor');
im_like("project of $sweep_floor is clean garage", qr/Moved task <$sweep_floor> into project 'Clean garage'/);

TODO: {
    local $TODO = "this doesn't check the right thing?";
    im_like("project of $sweep_floor is clean garage", qr/Task <$sweep_floor> is already in project 'Clean garage'/);
}

im_like("project of $sweep_floor is clean kitchen", qr/Moved task <$sweep_floor> into project 'Clean kitchen'/);

