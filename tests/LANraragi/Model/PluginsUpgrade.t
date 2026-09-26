use strict;
use warnings;
use utf8;

use Mojo::JSON qw(encode_json);
use Test::MockObject;
use Test::More;

my $PKG = 'LANraragi::Model::Plugins';
require_ok($PKG);

my $REGISTRY   = 'REG_1790412889';
my $OTHER_REG  = 'REG_1790412800';
my $MANAGED    = 'LANraragi/Plugin/Managed/Scripts/DuplicateArchives.pm';
my $BUILTIN    = 'LANraragi/Plugin/Scripts/FolderToCat.pm';
my $INDEX_KEY  = "REG_INDEX_1790412889";

my $logger = Test::MockObject->new;
$logger->mock( 'info',  sub { return } );
$logger->mock( 'warn',  sub { return } );
$logger->mock( 'debug', sub { return } );

# 每个场景重建一次 mock，避免相互影响
sub run_case {
    my (%plugin) = @_;

    my $index = {
        version      => 1,
        generated_at => "2026-09-26T00:00:00Z",
        plugins      => {
            duplicatearchives => {
                namespace => "duplicatearchives",
                type      => "script",
                versions  => {
                    "1.1.0" => { version => "1.1.0" },
                    "1.1.2" => { version => "1.1.2" },
                },
            },
        },
    };

    my $redis = Test::MockObject->new;
    $redis->mock( 'keys', sub { return ($REGISTRY) } );
    $redis->mock( 'get',  sub { return encode_json($index) } );
    $redis->mock(
        'hget',
        sub {
            my ( undef, $key, $field ) = @_;
            return undef unless $key eq 'LRR_PLUGIN_DUPLICATEARCHIVES';
            return $plugin{$field};
        }
    );

    my @installs;
    no warnings 'once', 'redefine';
    local *LANraragi::Model::Plugins::get_logger = sub { return $logger };
    local *LANraragi::Model::Plugins::install_plugin = sub {
        my ( $ns, undef, $registry, $version, $force ) = @_;
        push @installs, { ns => $ns, registry => $registry, version => $version, force => $force };
        return ( 200, {}, undef );
    };

    my @upgraded = LANraragi::Model::Plugins::upgrade_managed_plugins($redis);
    return ( \@upgraded, \@installs );
}

note('managed plugin that is behind gets upgraded to the published max version');

{
    my ( $upgraded, $installs ) = run_case(
        installed_path     => $MANAGED,
        installed_registry => $REGISTRY,
        installed_version  => '1.1.0',
    );
    is_deeply( $upgraded, [ 'duplicatearchives 1.1.0 -> 1.1.2' ], 'upgrade is reported' );
    is( scalar @$installs, 1, 'install_plugin called once' );
    is( $installs->[0]{version},  '1.1.2',      'installs the newer version' );
    is( $installs->[0]{registry}, $REGISTRY,    'from the registry it came from' );
    is( $installs->[0]{force},    1,            'forced, so a pinned copy can be replaced' );
}

note('an up-to-date plugin is left alone');

{
    my ( $upgraded, $installs ) = run_case(
        installed_path     => $MANAGED,
        installed_registry => $REGISTRY,
        installed_version  => '1.1.2',
    );
    is_deeply( $upgraded, [], 'nothing reported' );
    is( scalar @$installs, 0, 'install_plugin not called' );
}

note('a locally newer version is never downgraded by a stale index');

{
    my ( $upgraded, $installs ) = run_case(
        installed_path     => $MANAGED,
        installed_registry => $REGISTRY,
        installed_version  => '1.1.3',
    );
    is_deeply( $upgraded, [], 'nothing reported' );
    is( scalar @$installs, 0, 'install_plugin not called' );
}

note('built-in and side-loaded plugins are never touched');

for my $case (
    [ 'built-in path', { installed_path => $BUILTIN, installed_registry => $REGISTRY, installed_version => '1.1.0' } ],
    [ 'another registry', { installed_path => $MANAGED, installed_registry => $OTHER_REG, installed_version => '1.1.0' } ],
    [ 'not registry-installed', { installed_path => $MANAGED, installed_version => '1.1.0' } ],
    )
{
    # 注意用 hashref 再解引用：直接 my ($label, %plugin) = @$case 会把引用赋给 %plugin，
    # 结果是每个场景都在"什么都没装"的空状态下通过。
    my ( $label, $plugin ) = @$case;
    my ( $upgraded, $installs ) = run_case( %{$plugin} );
    is_deeply( $upgraded, [], "$label: nothing reported" );
    is( scalar @$installs, 0, "$label: install_plugin not called" );
}

done_testing();
