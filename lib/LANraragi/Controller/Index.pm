package LANraragi::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use utf8;
use URI::Escape;
use Redis;
use Encode;
use Digest::SHA qw(sha256_hex);
use File::Basename;

use LANraragi::Utils::Generic qw(generate_themes_header get_authenticator);
use LANraragi::Utils::Path    qw(get_archive_path);

# This endpoint is technically superseded by /api/search/random, but it's still useful in the Reader.
sub random_archive {
    my $self          = shift;
    my $archive       = "";
    my $archiveexists = 0;

    my $redis = $self->LRR_CONF->get_redis;

    # We get a random archive ID.
    # We check for the length to (sort-of) avoid not getting an archive ID.
    # TODO: This will loop infinitely if there are zero archives in store.
    until ($archiveexists) {
        $archive = $redis->randomkey();

        $self->LRR_LOGGER->debug("Found key $archive");

        #We got a key, but does the matching archive still exist on the server?
        if (   length($archive) == 40
            && $redis->type($archive) eq "hash"
            && $redis->hexists( $archive, "file" ) ) {
            my $arclocation = get_archive_path( $redis, $archive );
            if ( -e $arclocation ) { $archiveexists = 1; }
        }
    }

    $redis->quit();

    #We redirect to the reader, with the key as parameter.
    $self->redirect_to( '/reader?id=' . $archive );
}

# Render the index template with a few prefilled arguments.
# Most of the work is done in JS these days.
sub index {

    my $self = shift;

    # Checking if the user still has the default password enabled.
    #
    # This used to run a bcrypt verification on every single index page load,
    # which costs ~0.6s per request at bcrypt's default cost. Cache the answer
    # in Redis under a digest of the stored hash (it can only change when the
    # password changes), and skip the check entirely when password protection is
    # disabled, since the result is false either way.
    my $passcheck = 0;
    if ( $self->LRR_CONF->enable_pass ) {
        my $hash = $self->LRR_CONF->get_password;
        $hash =~ s/^\{CRYPT\}//;    # Convert RFC 2307 to bare hash

        my $redis  = $self->LRR_CONF->get_redis_config;
        my $digest = sha256_hex($hash);
        my $cached = $redis->get("LRR_DEFAULTPASS_CHECK");

        if ( defined $cached && $cached =~ /^\Q$digest\E:([01])$/ ) {
            $passcheck = $1;
        } else {
            $passcheck = get_authenticator->verify_password( "kamimamita", $hash ) ? 1 : 0;
            $redis->set( "LRR_DEFAULTPASS_CHECK", "$digest:$passcheck" );
        }
        $redis->quit();
    }

    my $userlogged = $self->LRR_CONF->enable_pass == 0 || $self->session('is_logged');

    # Get static category list to populate the right-click menu
    my @categories = LANraragi::Model::Category->get_static_category_list;

    $self->render(
        template     => "index",
        version      => $self->LRR_VERSION,
        title        => $self->LRR_CONF->get_htmltitle,
        descstr      => $self->LRR_DESC,
        userlogged   => $userlogged,
        categories   => \@categories,
        motd         => $self->LRR_CONF->get_motd,
        csshead      => generate_themes_header($self),
        usingdefpass => $passcheck
    );
}

1;
