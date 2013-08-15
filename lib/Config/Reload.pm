package Config::Reload;
#ABSTRACT: Load config files, reload when files changed.

use v5.10;
use strict;

use Config::ZOMG '0.00200';

use Moo;
use Sub::Quote 'quote_sub';
use Digest::MD5 qw(md5_hex);
use Try::Tiny;

use parent 'Exporter';
our @EXPORT_OK = qw(files_hash);

=head1 SYNOPSIS

    my $config = Config::Reload->new(
        wait => 60,     # check at most every minute (default)
        ...             # passed to Config::ZOMG, e.g. file => $filename
    );

    my $config = $config->load;

    sleep(60);

    $config = $config->load;   # reloaded

=head1 DESCRIPTION

This Perl package loads config files via L<Config::ZOMG> which is based on
L<Config::Any>. Configuration is reloaded on file changes (based on file names
and last modification time).

This package is highly experimental and not fully covered by unit tests!

=cut

has wait    => (
    is      => 'rw',
    default => quote_sub q{ 60 },
);


has checked => ( is => 'rw' );
has loaded  => ( is => 'rw' );
has error   => ( is => 'rw' );

sub found {
    @{ $_[0]->_found };
}

has _md5    => ( is => 'rw' ); # caches $self->md5($self->found)
has _zomg   => ( is => 'rw', handles => [qw(find)] );
has _found  => ( is => 'rw', default => quote_sub q{ [ ] } );
has _config => ( is => 'rw' );

sub BUILD {
    my ($self, $given) = @_;

    # don't pass to Config::ZOMG
    delete $given->{$_} for qw(wait error checked);

    $self->_zomg( Config::ZOMG->new($given) );
}

sub load {
    my $self = shift;
    my $zomg = $self->_zomg;

    if ($self->_config) {
        if (time < $self->checked + $self->wait) {
            return $self->_config;
        }
        if ($self->_md5 eq files_hash( $zomg->find )) {
            $self->checked(time);
            return $self->_config;
        } else {
            $self->_config(undef);
        }
    }

    $self->checked(time);

    try {
        $self->error(undef);
        $self->_config( $zomg->reload ); # may die on error
        $self->loaded(time);

        # save files to prevent Config::ZOMG::Source::Loader::read
        # this may change in a later version of Config::ZOMG
        $self->_found([ $zomg->found ]);
        $self->_md5( files_hash( $self->found ) );
    } catch {
        $self->error($_);
        $self->loaded(undef);
        $self->_found( [] );
        $self->_md5( files_hash() );
        $self->_config( { } );
    };
    
    return $self->_config;
}

=method new

Returns a new C<Config::Reload> object.  All arguments but C<wait>, C<error>
and C<checked> are passed to the constructor of L<Config::ZOMG>.

=method load

Get the configuration, possibly (re)loading configuration files. Always returns
a hash reference, on error this C< { } >.

=method wait

Get or set the number of seconds to wait between checking. Set to 60 (one
minute) by default.

=method checked

Returns a timestamp of last time files had been checked.

=method loaded

Returns a timestamp of last time files had been loaded. Returns C<undef> before
first loading and on error.

=method found

Returns a list of files that configuration has been loaded from.  In contrast
to L<Config::ZOMG>, calling this method never triggers loading files, so an
empty list is returned before method C<load> has been called for the first
time.

=method find

Returns a list of files that configuration will be loaded from on next check.
Files will be reloaded only if C<files_hash> value of of C<find> differs from
the value of C<found>:

    use Config::Reload qw(files_hash);

    files_hash( $config->find ) ne files_hash( $config->found )

=method error

Returns an error message if loading failed. As long as an error is set, the
C<load> method returns an empty hash reference until the next attempt to reload
(typically the time span defind with C<wait>).  One can manually unset the
error with C<< $c->error(undef) >> to force reloading.

=head1 FUNCTIONS

=head2 files_hash( @files )

Returns a hexadecimal MD5 value based on names, -sizes and modification times
of a list of files. Internally used to compare C<find> and C<found>.

This function can be exported on request.

=cut

sub files_hash {
    md5_hex( map { my @s = stat($_); ($_, $s[9], $s[7]) } sort @_ );
}

=encoding utf8

=cut

1;
