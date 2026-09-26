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

# 该插件现在通过 registry 分发：构建期取回后作为 managed 插件内置，
# 或由用户从仓库安装。因此只在已安装时运行这些测试。
plan skip_all => 'LANraragi::Plugin::Managed::Metadata::ETagCN is not installed'
  unless eval { require LANraragi::Plugin::Managed::Metadata::ETagCN; 1 };
use_ok('LANraragi::Plugin::Managed::Metadata::ETagCN');

my %plugin_info = LANraragi::Plugin::Managed::Metadata::ETagCN::plugin_info();
is( $plugin_info{namespace}, 'etagcn', 'plugin namespace' );
is( $plugin_info{type},      'metadata', 'plugin type' );

# 参数改为 hash 式（按名字传递），并声明旧位置顺序用于配置迁移
is( scalar keys %{ $plugin_info{parameters} }, 9, 'plugin parameter count' );
is_deeply(
    [ sort keys %{ $plugin_info{parameters} } ],
    [ sort qw(lang savetitle usethumbs search_gid enablepanda jpntitle additionaltags expunged db_path) ],
    'plugin parameter names'
);
is_deeply(
    $plugin_info{to_named_params},
    [ qw(lang savetitle usethumbs search_gid enablepanda jpntitle additionaltags expunged db_path) ],
    'legacy positional order is declared for config migration'
);

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
    local *LANraragi::Plugin::Managed::Metadata::ETagCN::get_plugin_logger = sub {
        my $logger = get_logger_mock();
        $logger->mock( 'warn', sub {} );
        return $logger;
    };

    my @tags = ( 'language:english', 'artist:someone', 'color' );
    my $translated = LANraragi::Plugin::Managed::Metadata::ETagCN::translate_tag_to_cn( \@tags, $db_path );
    is_deeply( $translated, [ '语言:英语', '作者:someone', 'color' ], 'translates known tags and preserves unknown tags' );

    my @unchanged = ('language:english');
    my $without_db = LANraragi::Plugin::Managed::Metadata::ETagCN::translate_tag_to_cn( \@unchanged, '' );
    is_deeply( $without_db, \@unchanged, 'keeps tags when no translation database is configured' );
}

note('testing get_tags reads the named parameters it receives...');

{
    my ( @lookup_args, @tags_args );
    no warnings 'once', 'redefine';
    local *LANraragi::Plugin::Managed::Metadata::ETagCN::get_plugin_logger = sub {
        my $logger = get_logger_mock();
        $logger->mock( 'warn', sub {} );
        return $logger;
    };

    # Both helpers are stubbed so the parameter plumbing can be observed
    # without touching the network.
    local *LANraragi::Plugin::Managed::Metadata::ETagCN::lookup_gallery = sub {
        @lookup_args = @_;
        return ( "1234567", "abcdef" );
    };
    local *LANraragi::Plugin::Managed::Metadata::ETagCN::get_tags_from_EH = sub {
        @tags_args = @_;
        return ( "language:chinese", "JP Title" );
    };

    my %result = LANraragi::Plugin::Managed::Metadata::ETagCN::get_tags(
        "LANraragi::Plugin::Managed::Metadata::ETagCN",
        {   archive_title  => "Some Title",
            existing_tags  => "artist:someone",
            thumbnail_hash => "deadbeef",
            oneshot_param  => "",
            user_agent     => "UA",
        },
        {   lang           => "chinese",
            savetitle      => 1,
            usethumbs      => 1,
            search_gid     => 1,
            enablepanda    => 1,
            jpntitle       => 1,
            additionaltags => 1,
            expunged       => 1,
            db_path        => "/tmp/ehdb.json",
        }
    );

    # lookup_gallery($title, $tags, $thumbhash, $ua, $domain, $defaultlanguage, $usethumbs, $search_gid, $expunged)
    is( $lookup_args[4], "https://exhentai.org", 'enablepanda selects the exhentai domain' );
    is( $lookup_args[5], "chinese",             'lang reaches the search' );
    is( $lookup_args[6], 1,                     'usethumbs reaches the search' );
    is( $lookup_args[7], 1,                     'search_gid reaches the search' );
    is( $lookup_args[8], 1,                     'expunged reaches the search' );

    # get_tags_from_EH($ua, $gID, $gToken, $jpntitle, $additionaltags, $db_path)
    is( $tags_args[3], 1,                'jpntitle reaches the tag fetch' );
    is( $tags_args[4], 1,                'additionaltags reaches the tag fetch' );
    is( $tags_args[5], "/tmp/ehdb.json", 'db_path reaches the tag fetch' );

    is( $result{title}, "JP Title", 'savetitle writes the fetched title' );
    is(
        $result{tags},
        "language:chinese, source:exhentai.org/g/1234567/abcdef",
        'source tag is rebuilt from the resolved gallery using the enabled domain'
    );
}

unlink $db_path;
done_testing();
