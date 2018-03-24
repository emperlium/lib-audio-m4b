use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::M4B',
    VERSION_FROM        => 'lib/Nick/Audio/M4B.pm',
    AUTHOR              => 'Nick Peskett',
    LIBS                => [ '-lmp4v2' ],
    DEFINE              => '-DINCLUDE_MP4V2_MP4V2_H',
    TEST_REQUIRES       => {
        'Test::More' => 0,
        'Digest::MD5' => 0
    }
);
