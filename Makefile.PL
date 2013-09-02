use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'Toadfarm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  EXE_FILES => [ 'script/toadfarm' ],
  VERSION_FROM => 'lib/Toadfarm.pm',
  PREREQ_PM => {
    'Mojolicious' => '3.91'
  },
  test => {
    TESTS => 't/*.t'
  },
  META_MERGE => {
    resources => {
      repository => 'https://github.com/jhthorsen/toadfarm',
    },
  },
);
