use warnings;
use strict;
use Config;

=head1 DESCRIPTION

Test parsing and reconstruction of LetMe phrases.

=cut

use BTDT::Test tests => 26;

use_ok('Jifty::LetMe');

my $u = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$u->create( email => 'mylongusername@example.com', password => 'sekkrit');
ok ($u->id, "Created the user");

my $letme = Jifty::LetMe->new(current_user => BTDT::CurrentUser->superuser);
isa_ok($letme, 'Jifty::Object');
for (qw(checksum_provided email path validated_current_user until)) {
    can_ok($letme, $_);
}

=for Comment


my $SAMPLE_KOREMUTAKE_TOKEN = "$SAMPLE_TOKEN/prabrykesubritejepuba";
my $SAMPLE_KOREMUTAKE_ENCODED_TOKEN = "$SAMPLE_ENCODED_TOKEN/prabrykesubritejepuba";

my $SAMPLE_HEX_TOKEN = "$SAMPLE_TOKEN/72be9665c9e7e2b1";
my $SAMPLE_HEX_ENCODED_TOKEN = "$SAMPLE_ENCODED_TOKEN/72be9665c9e7e2b1";

=cut

use charnames qw(:full);

$letme->email('mylongusername@example.com');
$letme->path('update_task');
my $args = {id => 23, owner => "user%40localhost", greek => "\N{GREEK SMALL LETTER SIGMA}"};
$letme->args($args);
$letme->until('20050101');

my $SAMPLE_TOKEN = 'mylongusername@example.com/update_task/greek/%cf%83/id/23/owner/user%2540localhost/until/20050101/';

my $koremutake_token = $SAMPLE_TOKEN . $letme->generate_koremutake_checksum;
my $hex_token = $SAMPLE_TOKEN . $letme->generate_checksum;

$letme = Jifty::LetMe->new(current_user => BTDT::CurrentUser->superuser);

SKIP: {
    skip "64-bit platforms have too much precision", 9 if $Config{use64bitint};
    ok($letme->from_token($koremutake_token)); 
    is($letme->email,'mylongusername@example.com');
    is($letme->path, 'update_task', "Yes, that's our token");
    is_deeply($letme->args, $args, "Yes, that's our token");
    is($letme->until,'20050101', "We have the right until");
    is($letme->generate_koremutake_checksum, $letme->checksum_provided);
    ok($letme->_correct_checksum_provided, "Yeah, it validated (private method)");
    ok($letme->validate, "Yeah, it validated ok");
    is($letme->validated_current_user->id, $u->id);
}

ok($letme->from_token($hex_token)); 
is($letme->email,'mylongusername@example.com');
is($letme->path, 'update_task', "Yes, that's our token");
is_deeply($letme->args, $args, "Yes, that's our token");
is($letme->until,'20050101', "We have the right until");
is($letme->generate_checksum, $letme->checksum_provided);
ok($letme->_correct_checksum_provided, "Yeah, it validated (private method)");
ok($letme->validate, "Yeah, it validated ok");
is($letme->validated_current_user->id, $u->id);

1;

