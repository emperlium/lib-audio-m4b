# lib-audio-m4b

Uses the MP4v2 library to read M4B AAC audio files.

## Dependencies

You'll need the [MP4v2 library](https://code.google.com/archive/p/mp4v2/).

On Ubuntu distributions;

    sudo apt install libmp4v2-dev

## Installation

    perl Makefile.PL
    make test
    sudo make install

## Example

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

## Methods

### new()

Instantiates a new Nick::Audio::M4B object.

Takes a filename as the first argument.

The second argument (optional) is a scalar that'll be used to push decoded PCM to.

### get\_init\_sample()

Returns two values, the elementary stream configuration and it's length in bytes.

This can then be feed to FAAD.

### get\_audio()

Reads the next frame of AAC into the buffer.

Optional takes a parameter, which is a sample ID not to read beyond.

### get\_buffer\_out\_ref()

Scalar that'll be used to place AAC frames into.

### get\_meta()

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

### get\_chapters()

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

### get\_duration\_in\_msecs()

The length of the audio stream in milliseconds (float).

### get\_duration\_in\_secs()

The length of the audio stream in seconds (float).

### get\_position\_in\_msecs()

Returns the current position in milliseconds (float).

### get\_position\_in\_secs()

Returns the current position in seconds (float).

### get\_position\_as\_sample\_id()

Returns the current position as a sample ID.

### get\_sample\_id\_from\_msecs( msecs )

Given a position in milliseconds, returns the corresponding sample ID.

### set\_position\_to\_msecs()

Sets the current position to given milliseconds (float).

### set\_position\_to\_secs()

Sets the current position to given seconds (float).

### set\_position\_to\_sample\_id( sample\_id )

Sets the current position to given sample ID.

### get\_average\_bps()

Returns the average bits per second of the audio stream.

### get\_sample\_rate()

Returns the sample rate of the audio stream.

### get\_channels()

Returns the number of audio channels in the stream.

### get\_samples\_per\_frame()

Returns the number of samples in each frame.
