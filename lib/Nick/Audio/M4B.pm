package Nick::Audio::M4B;

use strict;
use warnings;

use XSLoader;
use Carp;

our $VERSION;

BEGIN {
    $VERSION = '0.01';
    XSLoader::load 'Nick::Audio::M4B' => $VERSION;
}

=pod

=head1 NAME

Nick::Audio::M4B - Uses the MP4v2 library to read M4B AAC audio files.

=head1 SYNOPSIS

Currently only supports the first AAC audio stream in a file.

    use Nick::Audio::M4B;
    use Nick::Audio::FAAD;

    my( $buff_in, $buff_out );
    my $m4b = Nick::Audio::M4B -> new( 'test.m4b', $buff_in );

    use FileHandle;
    my $sox = FileHandle -> new( sprintf
            "| sox -q -t raw -b 16 -e s -r %d -c %d - -t pulseaudio",
            $m4b -> get_sample_rate(),
            $m4b -> get_channels()
    ) or die $!;
    binmode $sox;

    my %aac_set = (
        'buffer_in' => \$buff_in,
        'buffer_out' => \$buff_out,
        'channels' => $m4b -> get_channels(),
        'gain' => -3
    );
    @aac_set{ qw( init_sample init_length ) } = $m4b -> get_init_sample();

    my $aac = Nick::Audio::FAAD -> new( %aac_set );
    while (
        $m4b -> get_audio()
    ) {
        $aac -> decode()
            and $sox -> print( $buff_out );
    }
    $sox -> close();

=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::M4B object.

Takes a filename as the first argument.

The second argument (optional) is a scalar that'll be used to push decoded PCM to.

=head2 get_init_sample()

Returns two values, the elementary stream configuration and it's length in bytes.

This can then be feed to FAAD.

=head2 get_audio()

Reads the next frame of AAC into the buffer.

Optional takes a parameter, which is a sample ID not to read beyond.

=head2 get_buffer_out_ref()

Scalar that'll be used to place AAC frames into.

=head2 get_meta()

Returns a hash with any meta data found in the file.

Only elements that exist will have keys in the hash.

For example;

    (
        'track' => 'track title',
        'artist' => 'track artist',
        'album_artist' => 'album artist',
        'album' => 'track album',
        'composer' => 'track composer',
        'comment' => 'track comment',
        'description' => 'track description',
        'year'  => '2018',
        'position'  => 3,
        'grouping' => 'speech'
    )

=head2 get_chapters()

Returns an array, with each element being a hash reference of a chapter.

The time values are in milliseconds.

For example;

    (
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
    )

=head2 get_duration_in_msecs()

The length of the audio stream in milliseconds (float).

=head2 get_duration_in_secs()

The length of the audio stream in seconds (float).

=head2 get_position_in_msecs()

Returns the current position in milliseconds (float).

=head2 get_position_in_secs()

Returns the current position in seconds (float).

=head2 get_position_as_sample_id()

Returns the current position as a sample ID.

=head2 get_sample_id_from_msecs( msecs )

Given a position in milliseconds, returns the corresponding sample ID.

=head2 set_position_to_msecs()

Sets the current position to given milliseconds (float).

=head2 set_position_to_secs()

Sets the current position to given seconds (float).

=head2 set_position_to_sample_id( sample_id )

Sets the current position to given sample ID.

=head2 get_average_bps()

Returns the average bits per second of the audio stream.

=head2 get_sample_rate()

Returns the sample rate of the audio stream.

=head2 get_channels()

Returns the number of audio channels in the stream.

=head2 get_samples_per_frame()

Returns the number of samples in each frame.

=cut

sub new {
    my( $class, $file ) = @_;
    -f $file or croak(
        'Missing M4B file: ' . $file
    );
    return $class -> new_xs( $file, $_[2] );
}

sub set_position_to_secs {
    $_[0] -> set_position_to_msecs( int $_[1] * 1000 );
}

sub set_position_to_msecs {
    my( $self, $msecs ) = @_;
    my $sample_id = $self -> get_sample_id_from_msecs( $msecs );
    defined( $sample_id )
        and $self -> set_position_to_sample_id( $sample_id );
}

sub get_duration_in_secs {
    return $_[0] -> get_duration_in_msecs() / 1000;
}

sub get_position_in_secs {
    return $_[0] -> get_position_in_msecs() / 1000;
}

1;
