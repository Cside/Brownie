package Brownie::Session;

use strict;
use warnings;
use Carp ();
use Class::Load;
use Sub::Install;

use Brownie::Driver;
use Brownie::Node;
use Brownie::XPath;

sub new {
    my ($class, %args) = @_;

    my $driver_opts = delete $args{driver};
    $driver_opts ||= +{ name => 'Mechanize' };
    unless (ref $driver_opts) {
        $driver_opts = +{ name => $driver_opts };
    }

    $driver_opts->{class} ||= 'Brownie::Driver::' . $driver_opts->{name};
    $driver_opts->{args}  ||= {};

    Class::Load::load_class($driver_opts->{class});
    my $driver = $driver_opts->{class}->new(%{ $driver_opts->{args} });

    return bless { %args, scopes => [], driver => $driver }, $class;
}

sub DESTROY {
    my $self = shift;
    delete $self->{driver};
}

sub driver { shift->{driver} }
for my $method (Brownie::Driver->PROVIDED_METHODS) {
    Sub::Install::install_sub({
        code => sub { shift->driver->$method(@_) },
        as   => $method,
    });
}

sub current_node {
    my $self = shift;
    if (@{$self->{scopes}}) {
        return $self->{scopes}->[-1];
    }
    else {
        return $self->document;
    }
}

sub find { $_[0]->current_node->find_element($_[1]) }
sub all  { $_[0]->current_node->find_elements($_[1]) }

sub _do_safe_action {
    my $code = shift;
    my $ret = eval { $code->(); 1 } || 0;
    Carp::carp($@) if $@;
    return $ret;
}

sub click_link {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_link($locator);
    _do_safe_action(sub { $self->find($xpath)->click });
}

sub click_button {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_button($locator);
    _do_safe_action(sub { $self->find($xpath)->click });
}

sub click_link_or_button {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_link_or_button($locator);
    _do_safe_action(sub { $self->find($xpath)->click });
}
*click_on = \&click_link_or_button;

sub fill_in {
    my ($self, $locator, $value) = @_;
    my $xpath = Brownie::XPath::to_text_field($locator);
    _do_safe_action(sub { $self->find($xpath)->set($value) });
}

sub choose {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_radio($locator);
    _do_safe_action(sub { $self->find($xpath)->select });
}

sub check {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_checkbox($locator);
    _do_safe_action(sub { $self->find($xpath)->select });
}

sub uncheck {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_checkbox($locator);
    _do_safe_action(sub { $self->find($xpath)->unselect });
}

sub select {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_option($locator);
    _do_safe_action(sub { $self->find($xpath)->select });
}

sub unselect {
    my ($self, $locator) = @_;
    my $xpath = Brownie::XPath::to_option($locator);
    _do_safe_action(sub { $self->find($xpath)->unselect });
}

sub attach_file {
    my ($self, $locator, $filename) = @_;
    my $xpath = Brownie::XPath::to_file_field($locator);
    _do_safe_action(sub { $self->find($xpath)->set($filename) });
}

1;

=head1 NAME

Brownie::Session - browser session class

=head1 SYNOPSIS

  use Test::More;
  use Brownie::Session;

  my $session = Brownie::Session->new(
      driver => 'Mechanize',
      host   => 'http://app.local:8080',
  );

  # or use PSGI internal
  my $session = Brownie::Session->new(
      driver => 'Mechanize',
      app    => sub { ...(PSGI app)... },
  );

  # w/ driver args
  my $session = Brownie::Session->new(
      driver => {
          name => 'Selenium::RemoteDriver',
          args => { host => 'localhost', port => 4444 },
      },
      host   => 'http://example.com',
  );

  $session->visit('/');
  is $session->title => 'Some Title';

  $session->fill_in('User Name' => 'brownie');
  $session->fill_in('Email Address' => 'brownie@example.com');
  $session->click_button('Login');
  like $session->source => qr/Welcome (.+)/;

  $session->fill_in(q => 'Brownie');
  $session->click_link_or_button('Search');
  like $session->title => qr/Search result of Brownie/i;

  done_testing;

=head1 METHODS

=over 4

=item * C<new(%args)>

  my $session = Brownie::Session->new(%args);

C<%args> are:

=over 8

=item * C<driver>: loadable driver name or config

=item * C<host>: external target application

=item * C<app>: PSGI application

=back

=back

=head2 Driver Delegation

=over 4

=item * C<visit($url)>

Go to $url.

  $session->visit('http://example.com/');

=item * C<current_url>

Returns current page's URL.

  my $url = $session->current_url;

=item * C<current_path>

Returns current page's path of URL.

  my $path = $session->current_path;

=item * C<title>

Returns current page's <title> text.

  my $title = $session->title;

=item * C<source>

Returns current page's HTML source.

  my $source = $session->source;

=item * C<screenshot($filename)>

Takes current page's screenshot and saves to $filename as PNG.

  $session->screenshot($filename);

=item * C<execute_script($javascript)>

Executes snippet of JavaScript into current page.

  $session->execute_script('$("body").empty()');

=item * C<evaluate_script($javascript)>

Executes snipptes and returns result.

  my $result = $session->evaluate_script('1 + 2');

If specified DOM element, it returns WebElement object.

  my $node = $session->evaluate_script('document.getElementById("foo")');

=back

=head2 Node Action

=over 4

=item * C<click_link($locator)>

Finds and clicks specified link.

  $session->click_link($locator);

C<$locator>: id or text of link

=item * C<click_button($locator)>

Finds and clicks specified buttons.

  $session->click_button($locator);

C<$locator>: id or value of button

=item * C<click_on($locator)>

Finds and clicks specified links or buttons.

  $session->click_on($locator);

It combines C<click_link> and C<click_button>.

=item * C<fill_in($locator, $value)>

Sets a value to located field (input or textarea).

  $session->fill_in($locator, $value);

=item * C<choose($locator)>

Selects a radio button.

  $session->choose($locator);

=item * C<check($locator)>

Sets a checkbox to "checked"

  $session->check($locator);

=item * C<uncheck($locator)>

Unsets a checkbox from "checked"

  $session->check($locator);

=item * C<select($locator)>

Selects an option.

  $session->select($locator);

=item * C<unselect($locator)>

Unselects an option in multiple select.

  $session->unselect($locator);

=item * C<attach_file($locator, $filename)>

Sets a path to file upload field.

  $session->attach_file($locator, $filename);

=back

=head1 AUTHOR

NAKAGAWA Masaki E<lt>masaki@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Brownie::Driver>, L<Brownie::Node>

=cut
