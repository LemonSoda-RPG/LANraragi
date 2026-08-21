package LANraragi::Plugin::Scripts::AddEhentaiMetadata;

use strict;
use warnings;
use utf8;

use LANraragi::Model::Archive;
use LANraragi::Utils::Database qw(set_tags);
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Plugins qw(use_plugin);

my $METADATA_PLUGIN = "etagcn";
my $NO_GALLERY_TAG  = "source:nogalleryinehentai";

# Meta-information about this script plugin.
sub plugin_info {

    return (
        name        => "Add E-Hentai_CN Metadata",
        type        => "script",
        namespace   => "addetagcnmetadata",
        author      => "CHUSHEN",
        version     => "1.3",
        description => "Uses the E-Hentai_CN metadata plugin to find Chinese tags for archives without a source tag. Unmatched archives can be retried later.",
        oneshot_arg => "Search archives tagged source:nogalleryinehentai again. True/False",
        parameters  => [
            { type => "int", desc => "Interval in seconds between requests. E-Hentai recommends at least 4 seconds." }
        ]
    );
}

# ETagCN returns this message when its search cannot find a gallery.
sub is_no_gallery_error {

    my ($error) = @_;

    return 0 unless defined $error;
    return $error =~ /No matching EH Gallery Found!|没有匹配的\s*E-Hentai\s*画廊/;
}

sub run_metadata_plugin {

    my ($arcid) = @_;

    my ( $plugin_info, $plugin_result );
    eval {
        ( $plugin_info, $plugin_result ) = use_plugin( $METADATA_PLUGIN, $arcid, undef );
    };

    if ($@) {
        $plugin_result = { error => $@ };
    }

    return $plugin_result || { error => "The E-Hentai_CN plugin returned no result." };
}

# Mandatory function to be implemented by a script plugin.
sub run_script {
    shift;

    my $lrr_info        = shift || {};
    my $logger          = get_plugin_logger();
    my $retry_unmatched = $lrr_info->{oneshot_param};
    my ($interval)      = @_;
    my $success         = 0;
    my $total           = 0;
    my @archives        = LANraragi::Model::Archive->generate_archive_list;

    $interval = 4 if !defined $interval || $interval < 0;

    for my $archive (@archives) {
        next if $archive->{tags} =~ /\bsource\b/;

        sleep($interval);
        $logger->info("Start E-Hentai_CN process: $archive->{title}");
        $total++;

        my $plugin_result = run_metadata_plugin( $archive->{arcid} );
        if ( exists $plugin_result->{error} ) {
            $logger->warn("E-Hentai_CN plugin returned an error: " . $plugin_result->{error});

            if ( is_no_gallery_error( $plugin_result->{error} ) ) {
                $plugin_result->{new_tags} = $NO_GALLERY_TAG;
                $logger->info("Add tag: $NO_GALLERY_TAG");
            } else {
                next;
            }
        }

        if ( exists $plugin_result->{new_tags} ) {
            $logger->debug("Add E-Hentai_CN tags: " . $plugin_result->{new_tags});
            set_tags( $archive->{arcid}, $plugin_result->{new_tags}, 1 );
            $success++;
        }
    }

    if ( defined $retry_unmatched && $retry_unmatched eq "True" ) {
        for my $archive ( grep { $_->{tags} =~ /\b\Q$NO_GALLERY_TAG\E\b/ } @archives ) {
            sleep($interval);
            $logger->info("Retry E-Hentai_CN process: $archive->{title}");
            $total++;

            my $plugin_result = run_metadata_plugin( $archive->{arcid} );
            if ( exists $plugin_result->{error} ) {
                $logger->warn("E-Hentai_CN plugin returned an error: " . $plugin_result->{error});
                next;
            }

            next unless exists $plugin_result->{new_tags};

            $logger->debug("Replace $NO_GALLERY_TAG with E-Hentai_CN tags: " . $plugin_result->{new_tags});
            my $new_tags = $archive->{tags};
            $new_tags =~ s/\b\Q$NO_GALLERY_TAG\E\b/$plugin_result->{new_tags}/g;
            set_tags( $archive->{arcid}, $new_tags, 0 );
            $success++;
        }
    }

    return ( modified => $success, total => $total );
}

1;
