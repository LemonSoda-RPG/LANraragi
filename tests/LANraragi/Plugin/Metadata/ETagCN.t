use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use File::Temp qw(tempfile);
use Mojo::JSON qw(encode_json);
use Test::More;

my $cwd = getcwd();
require "$cwd/tests/mocks.pl";
setup_redis_mock();

use_ok('LANraragi::Plugin::Metadata::ETagCN');

my %plugin_info = LANraragi::Plugin::Metadata::ETagCN::plugin_info();
is( $plugin_info{namespace}, 'etagcn', 'plugin namespace' );
is( $plugin_info{type},      'metadata', 'plugin type' );
is( scalar @{ $plugin_info{parameters} }, 9, 'plugin parameter count' );

my ( $fh, $db_path ) = tempfile();
binmode $fh, ':raw';
print {$fh} encode_json(
    {
        data => [
            {
                namespace    => 'language',
                frontMatters => { name => '语言' },
                data         => { english => { name => '英语' } },
            },
            {
                namespace    => 'artist',
                frontMatters => { name => '作者' },
                data         => {},
            },
        ],
    }
);
close $fh;

{
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Metadata::ETagCN::get_plugin_logger = sub {
        my $logger = get_logger_mock();
        $logger->mock( 'warn', sub {} );
        return $logger;
    };

    my @tags = ( 'language:english', 'artist:someone', 'color' );
    my $translated = LANraragi::Plugin::Metadata::ETagCN::translate_tag_to_cn( \@tags, $db_path );
    is_deeply( $translated, [ '语言:英语', '作者:someone', 'color' ], 'translates known tags and preserves unknown tags' );

    my @unchanged = ('language:english');
    my $without_db = LANraragi::Plugin::Metadata::ETagCN::translate_tag_to_cn( \@unchanged, '' );
    is_deeply( $without_db, \@unchanged, 'keeps tags when no translation database is configured' );
}

unlink $db_path;
done_testing();
