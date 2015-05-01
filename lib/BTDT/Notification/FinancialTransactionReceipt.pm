use warnings;
use strict;

package BTDT::Notification::FinancialTransactionReceipt;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::FinancialTransactionReceipt

=head1 ARGUMENTS

C<transaction>

=cut

__PACKAGE__->mk_accessors(qw/transaction/);

=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    unless (UNIVERSAL::isa($self->transaction, "BTDT::Model::FinancialTransaction")) {
        $self->log->error((ref $self) . " called with invalid transaction argument");
        return;
    }

    $self->to( $self->transaction->user );
    $self->subject("Hiveminder Receipt: Thank you for your order!");

    $self->body(<<"END_BODY");
A receipt of your order is below.

Order #: @{[$self->transaction->order_id]}

  @{[$self->transaction->description]} x @{[$self->transaction->formatted_amount]}

Total: @{[$self->transaction->formatted_amount]}
 Paid: @{[$self->transaction->formatted_amount]}

Card type:   @{[$self->transaction->card_type]}
Card number: @{[$self->transaction->last_four]}
Expiration:  @{[$self->transaction->expiration]}

Address:
    @{[$self->transaction->first_name]} @{[$self->transaction->last_name]}
    @{[$self->transaction->address]}
    @{[$self->transaction->city]}@{[ $self->transaction->state ? ", ".$self->transaction->state : "" ]} @{[$self->transaction->zip]}
    @{[$self->transaction->country_name]}

You can also view your receipt online in your order history at:

@{[Jifty->web->url(path => "/account/orders/@{[$self->transaction->order_id]}")]}

Enjoy!

END_BODY

    $self->html_body(<<"    END_HTML");
<p>A receipt of your order is below.</p>

<p>Order #: @{[$self->transaction->order_id]}</p>

<p>@{[$self->transaction->description]} <b>x</b> @{[$self->transaction->formatted_amount]}</p>

<p>
  <b>Total: @{[$self->transaction->formatted_amount]}</b><br />
  <b>Paid: @{[$self->transaction->formatted_amount]}</b>
</p>

<p>
  <table cols="2">
    <tr><td align="right">Card type:</td><td>@{[$self->transaction->card_type]}</td></tr>
    <tr><td align="right">Card number:</td><td>@{[$self->transaction->last_four]}</td></tr>
    <tr><td align="right">Expiration:</td><td>@{[$self->transaction->expiration]}</td></tr>
    <tr>
      <td align="right" valign="top">Address:</td>
      <td>
        @{[$self->transaction->first_name]} @{[$self->transaction->last_name]}<br />
        @{[$self->transaction->address]}<br />
        @{[$self->transaction->city]}@{[ $self->transaction->state ? ", ".$self->transaction->state : "" ]} @{[$self->transaction->zip]}<br />
        @{[$self->transaction->country_name]}
      </td>
    </tr>
  </table>
</p>


<p>You can also <a href="@{[Jifty->web->url(path => "/account/orders/@{[$self->transaction->order_id]}")]}">view your receipt online</a> in your <a href="@{[Jifty->web->url(path => "/account/orders")]}">order history</a>.</p>

<p>Enjoy!</p>

    END_HTML

}

1;
