use strict;
use warnings;

use Test::More tests => 18;
use Digest::MD5 'md5_base64';

BEGIN {
    use_ok( 'Nick::Audio::M4B' );
};

my $file = 'test.m4b';
my @md5 = (
    [ 171, '3xKi4RnMQFpXjBgZC7qMSA' ],
    [ 137, 'UYSjWBz1rJ7gsIPkaT8pyg' ],
    [ 143, 'L+Lv7KrqBrQ2otKpnayDfg' ],
    [ 140, 'K6GgKlcxxfQH7lU2JJQV8Q' ],
    [ 137, 'SOc2t0qlIdhmkFbXjKrgaA' ],
    [ 141, 'MJbRcIRmXytf8C4Rb5vm8Q' ],
    [ 144, 'j70GUTMJczl1EExCCM0Yjg' ],
    [ 138, '2DB1SuvNoP7hhOlqK4ExXA' ],
    [ 135, 'Zjwv9mqQsWTt37Jr/7onKg' ],
    [ 143, 'SgW22BLKzx9afOb5sl7YPA' ],
    [ 141, 'nfoSPosUWwFDU85+xYkYkg' ],
    [ 144, 'fXHaQQ7aQdZv1rdNltLddg' ],
    [ 140, 'HzLr4QF3NFpDrr5w0TryPg' ],
    [ 140, '3Ie6wk0VBWGItsrzkUdrBw' ],
    [ 137, '09Dmg6guQQOjaAktAZdatA' ],
    [ 143, '/jZFe3SMVypp0yEz6sHJGg' ],
    [ 136, '+iFLxYiYE1ROWpYERzg0Dw' ],
    [ 141, 'Uz6ig/qFAIdXBbZQFq5rIg' ],
    [ 141, '7fC7pGBXHvjHGKsuF0SjAA' ],
    [ 139, 'CW5jy5PStvFkbuohxKcC+Q' ],
    [ 144, 'NxNoHqBYnuIDeK+rzLq9FQ' ],
    [ 153, '1AogdTiMf9N5dIDwERG0wA' ],
    [ 208, 'Vdb/aNsUwIJV//zL952e8g' ]
);

my $buffer;
my $m4b = Nick::Audio::M4B -> new( $file, \$buffer );
ok( defined( $m4b ), "new($file)" )
    or done_testing(), exit( 1 );

is_deeply(
    $m4b -> get_chapters(), [
        {
            'start' => 0,
            'duration' => 500,
            'title' => 'chapter 1'
        },
        {
            'start' => 500,
            'duration' => 500,
            'title' => 'chapter 2'
        }
    ], 'get_chapters'
);

is( $m4b -> get_duration_in_msecs(), 1068, 'get_duration_in_msecs()' );

is( $m4b -> get_duration_in_secs(), 1.068, 'get_duration_in_secs()' );

is( $m4b -> get_last_sample_id(), 23, 'get_last_sample_id()' );

is( $m4b -> get_average_bps(), 24986, 'get_average_bps()' );

is( $m4b -> get_sample_rate(), 22050, 'get_sample_rate()' );

is( $m4b -> get_channels(), 1, 'get_channels()' );

is( $m4b -> get_samples_per_frame(), 1024, 'get_samples_per_frame()' );

is( $m4b -> get_audio_type(), 'AAC LC', 'get_audio_type()' );

is_deeply(
    $m4b -> get_meta(), {
        'track' => 'track title',
        'artist' => 'track artist',
        'album' => 'track album',
        'composer' => 'track composer',
        'comment' => 'track comment',
        'description' => 'track description',
        'year'  => '2016'
    }, 'get_meta'
);


my( $init_str, $init_len ) = $m4b -> get_init_sample();
is(
    sprintf( # "\x13\x88"
        ( '%02x' x $init_len ) . ' %d',
        unpack( 'C' . $init_len, $init_str ),
        $init_len
    ), '1388 2', 'get_init_sample()'
);

my( $bytes, @got );
while (
    $bytes = $m4b -> get_audio()
) {
    push @got => [ $bytes, md5_base64( $buffer ) ];
}
is_deeply( \@got, \@md5, 'get_audio()' );

$m4b -> set_position_to_sample_id( 11 );
is( $m4b -> get_position_in_msecs(), 464, 'get_position_in_msecs' );
is( $m4b -> get_position_in_secs(), .464, 'get_position_in_secs' );

$m4b -> set_position_to_sample_id( 0 );
is( $m4b -> get_position_as_sample_id(), 1, 'set_position_to_sample_id(0)' );

$m4b -> set_position_to_sample_id( 99 );
is( $m4b -> get_position_as_sample_id(), 23, 'set_position_to_sample_id(99)' );
