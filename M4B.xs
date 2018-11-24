#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <mp4v2/mp4v2.h>

struct nickaudiom4b {
    MP4FileHandle fh;
    MP4TrackId track_id;
    MP4SampleId sample_id;
    MP4SampleId last_sample_id;
    uint32_t sample_size;
    unsigned char *init_sample;
    uint32_t init_sample_len;
    uint8_t channels;
    uint32_t sample_rate;
    uint8_t frame_flag;
    uint8_t *aac_out;
    SV *scalar_out;
};

typedef struct nickaudiom4b NICKAUDIOM4B;

static const uint32_t sample_rates[] = {
    96000, 88200, 64000, 48000, 44100, 32000,
    24000, 22050, 16000, 12000, 11025, 8000
};

MODULE = Nick::Audio::M4B    PACKAGE = Nick::Audio::M4B

PROTOTYPES: DISABLE

static NICKAUDIOM4B *
NICKAUDIOM4B::new_xs( filename, scalar_out )
        const char *filename;
        SV *scalar_out;
    CODE:
        Newxz( RETVAL, 1, NICKAUDIOM4B );
        RETVAL -> fh = MP4Read( filename );
        if ( ! MP4_IS_VALID_FILE_HANDLE( RETVAL -> fh ) ) {
            croak( "Invalid file handle." );
        }
        RETVAL -> track_id = MP4_INVALID_TRACK_ID;
        RETVAL -> sample_id = 1;
        uint32_t tracks = MP4GetNumberOfTracks( RETVAL -> fh, NULL, 0 );
        uint32_t i;
        for ( i = 0; i < tracks; i++ ) {
            MP4TrackId track_id = MP4FindTrackId( RETVAL -> fh, i, NULL, 0 );
            const char* track_type
                = MP4GetTrackType( RETVAL -> fh, track_id );
            if ( MP4_IS_AUDIO_TRACK_TYPE(track_type) ) {
                const char* data_name
                    = MP4GetTrackMediaDataName( RETVAL -> fh, track_id );
                if (
                    data_name != NULL
                    && strcasecmp( data_name, "mp4a" ) == 0
                    && MP4_IS_AAC_AUDIO_TYPE(
                        MP4GetTrackEsdsObjectTypeId( RETVAL -> fh, track_id )
                    )
                ) {
                    RETVAL -> track_id = track_id;
                    break;
                }
            }
        }
        if ( ! MP4_IS_VALID_TRACK_ID( RETVAL -> track_id ) ) {
            croak( "Invalid track ID" );
        }
        RETVAL -> last_sample_id = MP4GetTrackNumberOfSamples(
            RETVAL -> fh, RETVAL -> track_id
        );
        RETVAL -> sample_size = MP4GetTrackMaxSampleSize(
            RETVAL -> fh, RETVAL -> track_id
        );
        unsigned char *sample;
        uint32_t sample_size = 0;
        if (
            ! MP4GetTrackESConfiguration(
                RETVAL -> fh, RETVAL -> track_id,
                &sample, &sample_size
            )
        ) {
            croak( "Failed to read AAC init sample." );
        }
        if (sample_size < 2) {
            croak( "Expecting init sample size of at least 2, got: %d.", sample_size );
        }
        RETVAL -> init_sample = sample;
        RETVAL -> init_sample_len = sample_size;
        uint16_t aac_header = (sample[0] << 8) + sample[1];
        //uint8_t object_type = (aac_header & 0xF800) >> 11;
        uint8_t sr_index = (aac_header & 0x0780) >> 7;
        RETVAL -> sample_rate = sr_index < 12 ? sample_rates[sr_index] : 0;
        RETVAL -> channels = (aac_header & 0x0078) >> 3;
        RETVAL -> frame_flag = (aac_header & 0x0004) >> 2;
        Newx( RETVAL -> aac_out, RETVAL -> sample_size, uint8_t );
        RETVAL -> scalar_out = SvREFCNT_inc(
            SvROK( scalar_out )
            ? SvRV( scalar_out )
            : scalar_out
        );
    OUTPUT:
        RETVAL

void
NICKAUDIOM4B::DESTROY()
    CODE:
        MP4Close( THIS -> fh, 0 );
        SvREFCNT_dec( THIS -> scalar_out );
        Safefree( THIS -> aac_out );
        Safefree( THIS );

AV *
NICKAUDIOM4B::get_chapters()
    PREINIT:
        MP4Chapter_t * chapters = 0;
        uint32_t chapter_count = 0;
    INIT:
        MP4ChapterType chapter_type = MP4GetChapters(
            THIS -> fh, &chapters, &chapter_count, MP4ChapterTypeAny
        );
        if ( chapter_count == 0 ) {
            MP4Free(chapters);
            XSRETURN_UNDEF;
        }
    CODE:
        RETVAL = newAV();
        sv_2mortal( (SV*)RETVAL );
        uint32_t i;
        MP4Duration start = 0;
        for ( i = 0; i < chapter_count; i++ ) {
            HV * hash;
            hash = (HV *)sv_2mortal( (SV *)newHV() );
            hv_store( hash, "start", 5, newSVuv( start ), 0 );
            hv_store( hash, "duration", 8, newSVuv( chapters[i].duration ), 0 );
            hv_store( hash, "title", 5, newSVpv( chapters[i].title, 0 ), 0 );
            av_push( RETVAL, newRV( (SV *)hash ) );
            start += chapters[i].duration;
        }
        MP4Free(chapters);
    OUTPUT:
        RETVAL

double
NICKAUDIOM4B::get_duration_in_msecs()
    CODE:
        RETVAL = MP4ConvertFromTrackDuration(
            THIS -> fh,
            THIS -> track_id,
            MP4GetTrackDuration(
                THIS -> fh, THIS -> track_id
            ),
            MP4_MSECS_TIME_SCALE
        );
    OUTPUT:
        RETVAL

MP4SampleId
NICKAUDIOM4B::get_last_sample_id()
    CODE:
        RETVAL = THIS -> last_sample_id;
    OUTPUT:
        RETVAL

U32
NICKAUDIOM4B::get_average_bps()
    CODE:
        RETVAL = MP4GetTrackBitRate(
            THIS -> fh,
            THIS -> track_id
        );
    OUTPUT:
        RETVAL

U32
NICKAUDIOM4B::get_sample_rate()
    CODE:
        RETVAL = THIS -> sample_rate;
    OUTPUT:
        RETVAL

U8
NICKAUDIOM4B::get_channels()
    CODE:
        RETVAL = THIS -> channels;
    OUTPUT:
        RETVAL

U16
NICKAUDIOM4B::get_samples_per_frame()
    CODE:
        RETVAL = THIS -> frame_flag == 0 ? 1024 : 960;
    OUTPUT:
        RETVAL

HV *
NICKAUDIOM4B::get_meta()
    INIT:
        RETVAL = newHV();
        sv_2mortal( (SV*)RETVAL );
        const MP4Tags * tags = MP4TagsAlloc();
    CODE:
        MP4TagsFetch( tags, THIS -> fh );
        if ( tags -> name ) {
            hv_store( RETVAL, "track", 5, newSVpv( tags -> name, 0 ), 0 );
        }
        if ( tags -> artist ) {
            hv_store( RETVAL, "artist", 6, newSVpv( tags -> artist, 0 ), 0 );
        }
        if ( tags -> album ) {
            hv_store( RETVAL, "album", 5, newSVpv( tags -> album, 0 ), 0 );
        }
        if ( tags -> description ) {
            hv_store( RETVAL, "description", 11, newSVpv( tags -> description, 0 ), 0 );
        }
        if ( tags -> comments ) {
            hv_store( RETVAL, "comment", 7, newSVpv( tags -> comments, 0 ), 0 );
        }
        if ( tags -> releaseDate ) {
            hv_store( RETVAL, "year", 4, newSVpv( tags -> releaseDate, 0 ), 0 );
        }
        if ( tags -> track ) {
            hv_store( RETVAL, "position", 8, newSVuv( tags -> track -> index ), 0 );
        }
        if ( tags -> composer ) {
            hv_store( RETVAL, "composer", 8, newSVpv( tags -> composer, 0 ), 0 );
        }
        if ( tags -> albumArtist ) {
            hv_store( RETVAL, "album_artist", 12, newSVpv( tags -> albumArtist, 0 ), 0 );
        }
        if ( tags -> grouping ) {
            hv_store( RETVAL, "grouping", 8, newSVpv( tags -> grouping, 0 ), 0 );
        }
        MP4TagsFree( tags );
    OUTPUT:
        RETVAL

void
NICKAUDIOM4B::get_init_sample()
    PPCODE:
        PUSHs(
            sv_2mortal(
                newSVpvn(
                    THIS -> init_sample,
                    THIS -> init_sample_len
                )
            )
        );
        PUSHs(
            sv_2mortal(
                newSVuv(
                    THIS -> init_sample_len
                )
            )
        );

MP4SampleId
NICKAUDIOM4B::get_sample_id_from_msecs( msecs )
    double msecs;
    CODE:
        RETVAL = MP4GetSampleIdFromTime(
            THIS -> fh,
            THIS -> track_id,
            MP4ConvertToTrackTimestamp(
                THIS -> fh,
                THIS -> track_id,
                msecs,
                MP4_MSECS_TIME_SCALE
            ),
            false
        );
    OUTPUT:
        RETVAL

void
NICKAUDIOM4B::set_position_to_sample_id( sample_id )
    MP4SampleId sample_id;
    CODE:
        if ( sample_id < 1 ) {
            sample_id = 1;
        } else if ( sample_id > THIS -> last_sample_id ) {
            sample_id = THIS -> last_sample_id;
        }
        THIS -> sample_id = sample_id;

MP4SampleId
NICKAUDIOM4B::get_position_as_sample_id()
    CODE:
        RETVAL = THIS -> sample_id;
    OUTPUT:
        RETVAL

double
NICKAUDIOM4B::get_position_in_msecs()
    INIT:
        if (
            THIS -> sample_id > THIS -> last_sample_id
        ) {
            XSRETURN_UNDEF;
        }
    CODE:
        RETVAL = MP4ConvertFromTrackDuration(
            THIS -> fh,
            THIS -> track_id,
            MP4GetSampleTime(
                THIS -> fh, THIS -> track_id, THIS -> sample_id
            ),
            MP4_MSECS_TIME_SCALE
        );
    OUTPUT:
        RETVAL

SV *
NICKAUDIOM4B::get_buffer_out_ref()
    CODE:
        RETVAL = newRV_inc( THIS -> scalar_out );
    OUTPUT:
        RETVAL

U32
NICKAUDIOM4B::get_audio( last_sample_id = 0 )
    MP4SampleId last_sample_id;
    INIT:
        if (
            THIS -> sample_id > (
                last_sample_id > 0
                ? last_sample_id
                : THIS -> last_sample_id
            )
        ) {
            XSRETURN_UNDEF;
        }
    CODE:
        uint32_t this_size = THIS -> sample_size;
        if (
            ! MP4ReadSample(
                THIS -> fh,
                THIS -> track_id,
                THIS -> sample_id,
                &( THIS -> aac_out ),
                &this_size,
                NULL, NULL, NULL, NULL
            )
        ) {
            croak( "Failed to read sample ID %d.", THIS -> sample_id );
        }
        sv_setpvn( THIS -> scalar_out, THIS -> aac_out, this_size );
        THIS -> sample_id ++;
        RETVAL = this_size;
    OUTPUT:
        RETVAL
