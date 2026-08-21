use strict;
use warnings;
use utf8;

use Encode qw(decode encode encode_utf8);
use Test::More;

use LANraragi::Utils::Redis qw(redis_decode);

sub mojibake_once {
    return decode( "ISO-8859-1", encode_utf8( $_[0] ) );
}

my $original = "语言:汉语 くらえチナビーム! 👓";
my $value    = $original;

for my $layer ( 1 .. 4 ) {
    $value = mojibake_once($value);
    is( redis_decode($value), $original, "repairs UTF-8 mojibake after $layer encoding layer" );
}

is( redis_decode($original), $original, "leaves valid Unicode unchanged" );

done_testing();
