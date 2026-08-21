use strict;
use warnings;
use utf8;

use Test::More;

use LANraragi::Plugin::Scripts::AddEhentaiMetadata;

my @archives = (
    { arcid => "archive-success", title => "Success", tags => "artist:someone" },
    { arcid => "archive-missing", title => "Missing", tags => "" },
    { arcid => "archive-source", title => "Already tagged", tags => "source:e-hentai.org/g/1/token" },
    { arcid => "archive-retry", title => "Retry", tags => "source:nogalleryinehentai" },
);

my @plugin_calls;
my @tag_updates;
my $logger = bless {}, "LANraragi::Plugin::Scripts::AddEhentaiMetadata::TestLogger";

{
    no warnings qw(once redefine);

    local *LANraragi::Model::Archive::generate_archive_list = sub { return @archives; };
    local *LANraragi::Plugin::Scripts::AddEhentaiMetadata::get_plugin_logger = sub { return $logger; };
    local *LANraragi::Plugin::Scripts::AddEhentaiMetadata::use_plugin = sub {
        my ( $namespace, $arcid ) = @_;
        push @plugin_calls, [ $namespace, $arcid ];

        return ( {}, { new_tags => "language:中文, source:e-hentai.org/g/1/token" } )
          if $arcid eq "archive-success";
        return ( {}, { error => "没有匹配的 E-Hentai 画廊！" } )
          if $arcid eq "archive-missing";
        return ( {}, { new_tags => "language:重试, source:e-hentai.org/g/2/token" } )
          if $arcid eq "archive-retry";

        return ( {}, { error => "unexpected archive" } );
    };
    local *LANraragi::Plugin::Scripts::AddEhentaiMetadata::set_tags = sub {
        push @tag_updates, [ @_ ];
    };

    my %result = LANraragi::Plugin::Scripts::AddEhentaiMetadata::run_script(
        "LANraragi::Plugin::Scripts::AddEhentaiMetadata",
        { oneshot_param => "True" },
        0
    );

    is_deeply( \%result, { modified => 3, total => 3 }, "returns processed and modified counts" );
    is_deeply(
        \@plugin_calls,
        [
            [ "etagcn", "archive-success" ],
            [ "etagcn", "archive-missing" ],
            [ "etagcn", "archive-retry" ],
        ],
        "calls the configured ETagCN plugin and retries unmatched archives"
    );
    is_deeply(
        \@tag_updates,
        [
            [ "archive-success", "language:中文, source:e-hentai.org/g/1/token", 1 ],
            [ "archive-missing", "source:nogalleryinehentai", 1 ],
            [ "archive-retry", "language:重试, source:e-hentai.org/g/2/token", 0 ],
        ],
        "writes translated tags and replaces the retry marker"
    );
}

done_testing();

package LANraragi::Plugin::Scripts::AddEhentaiMetadata::TestLogger;

sub info  { return; }
sub warn  { return; }
sub debug { return; }
