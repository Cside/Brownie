package Brownie::Driver::SeleniumServer;

use strict;
use warnings;
use parent 'Brownie::Driver';
use Selenium::Remote::Driver;
use Alien::SeleniumRC;
use Test::TCP;
use LWP::UserAgent;
use Scalar::Util qw(blessed);
use URI;
use File::Slurp qw(write_file);
use MIME::Base64 qw(decode_base64);

use Brownie::XPath;
use Brownie::Node::SeleniumServer;

our $NodeClass = 'Brownie::Node::SeleniumServer';

sub new {
    my ($class, %args) = @_;

    if ($ENV{SELENIUM_REMOTE_SERVER_HOST} && $ENV{SELENIUM_REMOTE_SERVER_PORT}) {
       $args{server_host} = $ENV{SELENIUM_REMOTE_SERVER_HOST};
       $args{server_port} = $ENV{SELENIUM_REMOTE_SERVER_PORT};
    }
    else {
        my $server = $class->_create_selenium_server;
        if ($server) {
            $args{server}      = $server;
            $args{server_host} = '127.0.0.1';
            $args{server_port} = $server->port,
        }
    }

    $args{browser_name} ||= ($ENV{SELENIUM_BROWSER_NAME} || 'firefox');

    return $class->SUPER::new(%args);
}

sub DESTROY {
    my $self = shift;

    delete $self->{browser};
    $self->_shutdown_selenium_server;
}

sub server_host  { shift->{server_host}  }
sub server_port  { shift->{server_port}  }
sub browser_name { shift->{browser_name} }

sub _create_selenium_server {
    my $class = shift;

    my $server = Test::TCP->new(
        code => sub {
            my $port = shift;
            Alien::SeleniumRC::start("-port $port");
        },
    );

    return $server;
}

sub _shutdown_selenium_server {
    my $self = shift;

    if ($self->{server}) {
        LWP::UserAgent->new->get($self->_selenium_shutdown_url);
        delete $self->{server};
    }
}

sub _selenium_shutdown_url {
    my $self = shift;

    my $base = 'http://%s:%s/selenium-server/driver/?cmd=shutDownSeleniumServer';
    return sprintf $base => $self->server_host, $self->server_port;
}

### Browser

sub browser {
    my $self = shift;

    $self->{browser} ||= Selenium::Remote::Driver->new(
        remote_server_addr => $self->server_host,
        port               => $self->server_port,
        browser_name       => $self->browser_name,
    );

    return $self->{browser};
}

### Navigation

sub visit {
    my ($self, $url) = @_;
    $self->browser->get("$url"); # stringify for URI
}

sub current_url {
    my $self = shift;
    return URI->new($self->browser->get_current_url);
}

sub current_path {
    my $self = shift;
    return $self->current_url->path;
}

### Pages

sub title {
    my $self = shift;
    return $self->browser->get_title;
}

sub source {
    my $self = shift;
    return $self->browser->get_page_source;
}

sub screenshot {
    my ($self, $file) = @_;
    my $image = decode_base64($self->browser->screenshot);
    write_file($file, { binmode => ':raw' }, $image);
}

### Finder

sub find {
    my ($self, $locator, %args) = @_;

    my $element;
    my $xpath = Brownie::XPath::to_xpath($locator);

    if (my $base = $args{base}) {
        my $node = (blessed($base) and $base->can('native')) ? $base->native : $base;
        $xpath = ".$xpath" unless $xpath =~ /^\./;
        $element = eval { $self->browser->find_child_element($node, $xpath) }; # abs2rel
    }
    else {
        $element = eval { $self->browser->find_element($xpath) };
    }

    return $element ? $NodeClass->new(driver => $self, native => $element) : undef;
}

sub all {
    my ($self, $locator, %args) = @_;

    my @elements = ();
    my $xpath = Brownie::XPath::to_xpath($locator);

    if (my $base = $args{base}) {
        my $node = (blessed($base) and $base->can('native')) ? $base->native : $base;
        $xpath = ".$xpath" unless $xpath =~ /^\./;
        @elements = eval { $self->browser->find_child_elements($node, $xpath) }; # abs2rel
    }
    else {
        @elements = eval { $self->browser->find_elements($xpath) };
    }

    return @elements ? map { $NodeClass->new(driver => $self, native => $_) } @elements : ();
}

### Scripting

sub execute_script {
    my ($self, $script) = @_;
    $self->browser->execute_script($script);
}

sub evaluate_script {
    my ($self, $script) = @_;
    return $self->browser->execute_script("return $script");
}

1;

=head1 NAME

Brownie::Driver::SeleniumServer - Selenium RemoteWebDriver bridge

=head1 SYNOPSIS

  # use default browser (firefox)
  my $driver = Brownie::Driver::SeleniumServer->new;

  # specify browser
  my $driver = Brownie::Driver::SeleniumServer->new(browser_name => 'chrome');

  $driver->visit($url);
  my $title = $driver->title;

=head1 METHODS

=head2 IMPLEMENTED

=over 4

=item * C<new( %args )>

  my $driver = Brownie::Driver::SeleniumServer->new(%args);

C<%args> are:

  * browser_name: selenium-server's browser name (default: "firefox")

You can also set selenium-server parameters using C<%ENV>:

  * SELENIUM_BROWSER_NAME

=item * C<browser>

=item * C<visit($url)>

=item * C<current_url>

=item * C<current_path>

=item * C<title>

=item * C<source>

=item * C<screenshot($filename)>

=item * C<execute_script($javascript)>

=item * C<evaluate_script($javascript)>

=item * C<find($locator)>

=item * C<all($locator)>

=back

=head2 NOT SUPPORTED

=over 4

=item * C<status_code>

=item * C<response_headers>

=back

=head1 TIPS

=head2 Use external selenium server

If you secify "SELENIUM_REMOTE_SERVER_HOST" and "SELENIUM_REMOTE_SERVER_PORT" enviromnent valiables, Brownie uses its server for selenium server.  By this, you can quicken the execution of your tests.

=head1 AUTHOR

NAKAGAWA Masaki E<lt>masaki@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Brownie::Driver>, L<Selenium::Remote::Driver>, L<Brownie::Node::SeleniumServer>

L<http://code.google.com/p/selenium/wiki/RemoteWebDriver>

L<http://code.google.com/p/selenium/wiki/RemoteWebDriverServer>

=cut
