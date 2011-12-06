#
# This file is part of Net-Mogade
#
# This software is copyright (c) 2011 by Gavin Mogan.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package Net::Mogade;

use strict;
use warnings;

# ABSTRACT: Perl Wrapper for the mogade.com leaderboard/scores service
our $VERSION = "0.01";

use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request::Common qw(GET POST);
use LWP::ConnCache;
use Digest::SHA1;
use Params::Validate qw(validate);

use Carp;
use JSON::Any;

use fields qw(
    base
    key
    secret
);

use constant {
    SCOPE_DAILY => 1,
    SCOPE_WEEKLY => 2,
    SCOPE_OVERALL => 3,
    SCOPE_YESTERDAY => 4,
};

our $connectionCacheLimit = 50;
our $json = JSON::Any->new(utf8=>1);

{
    my $cache;
    sub _getCache
    {
        $cache ||= LWP::ConnCache->new( total_capacity => $connectionCacheLimit );
        return $cache;
    }
}

sub new 
{
    my $self = shift;
    my %args = @_;
    unless (ref $self) {
        $self = fields::new($self);
    }
    @$self{keys %args} = values %args;
    $self->{base} ||= 'http://api2.mogade.com/api/gamma/';
    return $self;
}

sub _generateCgiWithSig
{
    my $self = shift;
    my %args = @_;

    my @array;
    foreach my $key (sort keys %args)
    {
        push @array, $key, $args{$key};
    }
    my $sig = join('|', @array, $self->{secret});

    push @array, 'sig', Digest::SHA1::sha1_hex($sig);
    return \@array;
}

sub _post
{
    my $self = shift;
    my $urlSegment = shift;
    my %args = @_;

    my $agent = LWP::UserAgent->new();
    $agent->agent("Net::Mogade/$Net::Mogade::VERSION");

    my @headers;
    if (1)
    {
        push @headers, Connection => "Keep-Alive";
        $agent->conn_cache(_getCache());
    }
    my $url = URI->new($self->{base} . $urlSegment);

    my $request = POST $url, $self->_generateCgiWithSig(%args), @headers;
    my $response = $agent->request($request);
    croak "HTTP Error trying to talk to $url: ", $response->content unless $response->is_success();
    return $response;
}

sub _get
{
    my $self = shift;
    my $urlSegment = shift;
    my %args = @_;
    
    my $agent = LWP::UserAgent->new();
    $agent->agent("Net::Mogade/$Net::Mogade::VERSION");

    my @headers;
    if (1)
    {
        push @headers, Connection => "Keep-Alive";
        $agent->conn_cache(_getCache());
    }
    my $url = URI->new($self->{base} . $urlSegment);
    $url->query_form($url->query_form(), %args);

    my $request = GET $url, @headers;
    my $response = $agent->request($request);
    croak "HTTP Error trying to talk to $url: ", $response->content unless $response->is_success();
    return $response;
}

sub ranks
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            lid => 1,
            userkey => 1,
            username => 1,
            scope => 0,
    });

    my $response = $self->_get("ranks", %args);
    return $json->jsonToObj($response->content);
}

sub scoreSave
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            lid => 1,
            points => 1,
            userkey => 1,
            username => 1,
            data => {
                type => Params::Validate::SCALAR,
                optional => 1,
                callbacks => {           # ... and smaller than 50 characters
                    'max 50 characters' => sub { length shift() <= 50 },
                },
            }
    });

    my $response = $self->_post("scores", %args, key => $self->{key});
    return $json->jsonToObj($response->content);
}

sub scoreGet
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            lid => 1,
            userkey => {
                type => Params::Validate::SCALAR,
                optional => 1,
                depends => ['username']
            },
            username => {
                type => Params::Validate::SCALAR,
                optional => 1,
                depends => ['userkey']
            },
            scope => 0,
            page => 0,
            records => 0,
    });

    my $response = $self->_get("scores", %args);
    return $json->jsonToObj($response->content);
}


## Achivements

sub achivementGrant
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            aid => 1,
            userkey => 1,
            username => 1,
    });

    my $response = $self->_post("achievements", %args, key => $self->{key});
    return $json->jsonToObj($response->content);
}


sub achivementGet
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            userkey => 1,
            username => 1,
    });

    my $response = $self->_get("achievements", %args, key => $self->{key});
    return $json->jsonToObj($response->content);
}

## Log Error
sub logError
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            subject => {
                type => Params::Validate::SCALAR,
                optional => 0,
                callbacks => {           # ... and smaller than 150 characters
                    'max 150 characters' => sub { length shift() <= 150 },
                },
            },
            details => {
                type => Params::Validate::SCALAR,
                optional => 1,
                callbacks => {           # ... and smaller than 2000 characters
                    'max 2000 characters' => sub { length shift() <= 2000 },
                },
            }
    });

    my $response = $self->_post("errors", %args, key => $self->{key});
    return 1;
}

## Log Start
sub logStart
{
    my $self = shift;
    my %args = @_;
    validate( @_, {
            userkey => 1,
    });

    my $response = $self->_post("stats", %args, key => $self->{key});
    return 1;
}

1;

__END__
=pod

=head1 NAME

Net::Mogade - Perl Wrapper for the mogade.com leaderboard/scores service

=head1 VERSION

version 0.001

=head1 AUTHOR

Gavin Mogan <gavin@kodekoan.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Gavin Mogan.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

