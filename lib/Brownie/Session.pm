package Brownie::Session;

use strict;
use warnings;
use Class::Load;
use Sub::Install;
use Class::Method::Modifiers;

use Brownie::Driver;
use Brownie::Node;

sub new {
    my ($class, %args) = @_;

    $args{driver_name}  ||= 'Selenium';
    $args{driver_class} ||= 'Brownie::Driver::' . $args{driver_name};
    $args{driver_args}  ||= {};

    Class::Load::load_class($args{driver_class});
    my $driver = $args{driver_class}->new(%{$args{driver_args}});

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

sub current_node { shift->{scopes}->[-1] }

after 'visit' => sub {
    my $self = shift;
    # clear scopes
    $self->{scopes} = [ $self->document ];
};

sub _find {
    my ($self, $locator) = @_;
    $self->current_node->find_element($locator);
}

sub click_link {
    my ($self, $locator) = @_;

    my @xpath = (
        Brownie::to_xpath($locator),
        "//a[text()='$locator']",
        "//a[\@title='$locator']",
        "//a//img[\@alt='$locator']",
    );

    return $self->_click(@xpath);
}

sub click_button {
    my ($self, $locator) = @_;

    my $types = q/(@type='submit' or @type='button' or @type='image')/;
    my @xpath = (
        Brownie::to_xpath($locator),
        "//input[$types and \@value='$locator']",
        "//input[$types and \@title='$locator']",
        "//button[\@value='$locator']",
        "//button[\@title='$locator']",
        "//button[text()='$locator']",
        "//input[\@type='image' and \@alt='$locator']",
    );

    return $self->_click(@xpath);
}

sub click_on {
    my ($self, $locator) = @_;
    return $self->click_link($locator) || $self->click_button($locator);
}

sub _click {
    my ($self, @xpath) = @_;

    for my $xpath (@xpath) {
        if (my $element = $self->_find($xpath)) {
            $element->click;
            return 1;
        }
    }

    return 0;
}

sub fill_in {
    my ($self, $locator, %args) = @_;
}

sub choose {
    my ($self, $locator) = @_;
}

sub check {
    my ($self, $locator) = @_;
}

sub uncheck {
    my ($self, $locator) = @_;
}

sub select {
    my ($self, $value, %args) = @_;
}

sub attach_file {
    my ($self, $locator, $filename) = @_;
}

1;

=head1 NAME

Brownie::Session - browser session class

=head1 METHODS

=head2 Links and Buttons

=over 4

=item * C<click_link($locator)>

Finds and clicks specified link.

  $driver->click_link($locator);

C<$locator> are:

=over 8

=item * C<#id>

=item * C<//xpath>

=item * C<text() of E<lt>aE<gt>>

(e.g.) <a href="...">{locator}</a>

=item * C<@title of E<lt>aE<gt>>

(e.g.) <a title="{locator}">...</a>

=item * C<child E<lt>imgE<gt> @alt>

(e.g.) <a><img alt="{locator}"/></a>

=back

=item * C<click_button($locator)>

Finds and clicks specified buttons.

  $driver->click_button($locator);

C<$locator> are:

=over 8

=item * C<#id>

=item * C<//xpath>

=item * C<@value of E<lt>inputE<gt> / E<lt>buttonE<gt>>

(e.g.) <input value="{locator}"/>

=item * C<@title of E<lt>inputE<gt> / E<lt>buttonE<gt>>

(e.g.) <button title="{locator}">...</button>

=item * C<text() of E<lt>buttonE<gt>>

(e.g.) <button>{locator}</button>

=item * C<@alt of E<lt>input type="image"E<gt>>

(e.g.) <input type="image" alt="{locator}"/>

=back

=item * C<click_on($locator)>

Finds and clicks specified links or buttons.

  $driver->click_on($locator);

It combines C<click_link> and C<click_button>.

=back

=head2 Forms

=over 4

=item * C<fill_in($locator, -with => $value)>

=item * C<choose($locator)>

=item * C<check($locator)>

=item * C<uncheck($locator)>

=item * C<select($value, -from => $locator)>

=item * C<attach_file($locator, $filename)>

=back

=head1 AUTHOR

NAKAGAWA Masaki E<lt>masaki@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Brownie::Driver>, L<Brownie::Node>

=cut
