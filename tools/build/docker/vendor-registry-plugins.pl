#!/usr/bin/perl
# 把本 fork 通过自己的 registry 分发的插件，在构建期取回并放进镜像
# （以 managed 插件的形态，落到 Plugin/Managed/ 的对应路径）。
#
# 为什么不直接放进 Plugin/<Type>/（像上游那样内置）？
# 因为安装时会做 namespace 冲突检查，扫描整个 Plugin/ 目录：只要同名
# namespace 已作为内置插件存在，registry 里的同一个插件就永远装不上、
# 也升级不了。放进 Managed/ 则既能开箱可用，又留出 registry 更新的余地。
#
# 用法: vendor-registry-plugins.pl [目标目录]
# 环境变量:
#   OUGI_BASE     仓库基址（默认 LemonSoda-RPG/Ougi 的 main 分支）
#   OUGI_PLUGINS  要内置的 namespace 列表，逗号分隔

use strict;
use warnings;
use utf8;

use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use JSON::PP qw(decode_json);

my $target = $ARGV[0] // '/opt/lrr-vendor-plugins';
my $base   = $ENV{OUGI_BASE} // 'https://raw.githubusercontent.com/LemonSoda-RPG/Ougi/main';
my @wanted = split /,/, ( $ENV{OUGI_PLUGINS} // 'etagcn,addehentaimetatdata,duplicatearchives' );

my %TYPE_DIR = ( metadata => 'Metadata', download => 'Download', login => 'Login', script => 'Scripts' );

sub fetch {
    my ($url) = @_;

    # 用列表形式调用，不经过 shell，避免 URL 里的字符被解释
    open( my $fh, '-|', 'wget', '-qO-', $url ) or die "Cannot run wget for $url: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    die "Failed to fetch $url\n" unless defined $content && length $content;
    return $content;
}

# 够用的 SemVer 排序键（registry 的版本键都是 X.Y.Z 形式）
sub version_key {
    my ($v) = @_;
    my @parts = split /[.\-+]/, $v;
    return [ map { $_ + 0 } @parts[ 0 .. 2 ] ];
}

my $index = decode_json( fetch("$base/registry.json") );

for my $ns (@wanted) {
    my $entry = $index->{plugins}{$ns} or die "Plugin '$ns' is missing from the registry index\n";
    my $type_dir = $TYPE_DIR{ $entry->{type} } or die "Plugin '$ns' has unknown type '$entry->{type}'\n";

    my @versions = keys %{ $entry->{versions} };
    die "Plugin '$ns' has no versions\n" unless @versions;
    my ($version) = sort {
        my $a_key = version_key($a);
        my $b_key = version_key($b);
        $a_key->[0] <=> $b_key->[0] || $a_key->[1] <=> $b_key->[1] || $a_key->[2] <=> $b_key->[2];
    } @versions;

    my $meta    = $entry->{versions}{$version};
    my $content = fetch("$base/$meta->{artifact}");
    my $digest  = sha256_hex($content);
    die "Checksum mismatch for $ns $version (registry says $meta->{sha256}, downloaded $digest)\n"
      unless $digest eq $meta->{sha256};

    my $dest = "$target/$type_dir/" . basename( $meta->{artifact} );
    make_path( dirname($dest) );
    open( my $out, '>:raw', $dest ) or die "Cannot write $dest: $!\n";
    print {$out} $content;
    close $out;

    print "Vendored $ns $version -> $dest\n";
}

1;
