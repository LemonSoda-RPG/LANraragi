use strict;
use warnings;
use utf8;

use Cwd qw(getcwd);
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Test::More;

my $PKG = 'LANraragi::Model::Plugins';
require_ok($PKG);

my $plugin = <<'PLUGIN';
package LANraragi::Plugin::Managed::Metadata::TestPlugin;

use strict;
use warnings;

sub plugin_info {
    return (
        name        => "Test Plugin",
        type        => "metadata",
        namespace   => "testplugin",
        author      => "tester",
        version     => "1.0.0",
        description => "Plugin used by the registry install tests"
    );
}

sub get_tags { return ( tags => "" ); }

1;
PLUGIN

my $plugmeta = {
    name     => "Test Plugin",
    version  => "1.0.0",
    artifact => "artifacts/testplugin/1.0.0/TestPlugin.pm",
    sha256   => sha256_hex($plugin),
};

sub with_scratch {
    my ($code) = @_;

    my $original = getcwd();
    my $tmp      = tempdir( CLEANUP => 1 );
    chdir $tmp or die "chdir $tmp: $!";
    my $result = $code->($tmp);
    chdir $original or die "chdir $original: $!";
    return $result;
}

sub seed_file {
    my ( $content, $name ) = @_;
    $name //= 'TestPlugin.pm';
    my $dir = "lib/LANraragi/Plugin/Managed/Metadata";
    make_path($dir);
    open( my $fh, '>:raw', "$dir/$name" ) or die $!;
    print {$fh} $content;
    close $fh;
    return getcwd() . "/$dir/$name";
}

note('validate_managed_plugin with a free install path');

with_scratch(
    sub {
        my ( $info, $err ) = LANraragi::Model::Plugins::validate_managed_plugin(
            $plugin, 'testplugin', $plugmeta, 'metadata', undef );
        is( $err, undef, 'free install path is accepted' );
        is( $info->{package}, 'LANraragi::Plugin::Managed::Metadata::TestPlugin', 'resolved package name' );
    }
);

note('validate_managed_plugin adopts a byte-identical file sitting at the install path');

with_scratch(
    sub {
        my $path = seed_file($plugin);
        my ( $info, $err ) = LANraragi::Model::Plugins::validate_managed_plugin(
            $plugin, 'testplugin', $plugmeta, 'metadata', undef );
        is( $err, undef, 'identical unregistered file is adopted instead of blocking the install' );
        is( $info->{install_path}, $path, 'install path is the existing file' );
    }
);

with_scratch(
    sub {
        my $path = seed_file($plugin);
        my ( $info, $err ) = LANraragi::Model::Plugins::validate_managed_plugin(
            $plugin, 'testplugin', $plugmeta, 'metadata', $path );
        is( $err, undef, 'an already-registered file at the same path is a normal upgrade' );
    }
);

note('validate_managed_plugin still refuses a different file at the install path');

with_scratch(
    sub {
        my $other = $plugin;
        $other =~ s/Plugin used by the registry install tests/Something else entirely/;
        seed_file($other);

        my ( $info, $err ) = LANraragi::Model::Plugins::validate_managed_plugin(
            $plugin, 'testplugin', $plugmeta, 'metadata', undef );
        is( $info, undef, 'no install info returned' );
        like( $err, qr/Install path is already occupied/, 'a differing file is still refused' );
    }
);

done_testing();
