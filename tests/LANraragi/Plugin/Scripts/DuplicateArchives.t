use strict;
use warnings;
use utf8;

use Test::Deep;
use Test::MockObject;
use Test::More;

use LANraragi::Plugin::Scripts::DuplicateArchives;

my $redis_mock = Test::MockObject->new;
$redis_mock->mock( 'exists', sub { return $_[1] eq "LRR_FILEMAP" ? 1 : 0; } );
$redis_mock->mock(
    'hgetall',
    sub {
        return (
            "/content/a.zip"     => "same-id",
            "/content/b.cbz"     => "same-id",
            "/content/c.rar"     => "other-id",
            "/content/cover.jpg" => "image-id",
            "/content/readme.md" => "text-id"
        );
    }
);
$redis_mock->mock( 'quit', sub { return 1; } );

my @log_messages;
my $logger_mock = Test::MockObject->new;
$logger_mock->mock(
    'info',
    sub {
        shift;
        push @log_messages, shift;
        return;
    }
);

{
    no warnings 'once', 'redefine';
    local *LANraragi::Model::Config::get_redis_config = sub { return $redis_mock; };
    local *LANraragi::Plugin::Scripts::DuplicateArchives::get_plugin_logger = sub { return $logger_mock; };

    my %result = LANraragi::Plugin::Scripts::DuplicateArchives::run_script();

    cmp_deeply(
        \%result,
        {
            filemap_entries     => 5,
            images_skipped      => 1,
            nonarchives_skipped => 1,
            message             => "Duplicate Archive Finder finished. Found 1 duplicate archive groups. See Plugin Logs for details.",
            total               => 1,
            duplicate_groups    => [
                {
                    archive_id => "same-id",
                    count      => 2,
                    files      => [ "/content/a.zip", "/content/b.cbz" ]
                }
            ]
        },
        "duplicate archive groups are listed from the filemap"
    );

    cmp_deeply(
        \@log_messages,
        superbagof(
            "Duplicate Archive Finder started.",
            "Duplicate Archive Finder finished. Found 1 duplicate archive groups. See Plugin Logs for details."
        ),
        "plugin logs start and finish messages"
    );
}

done_testing();
