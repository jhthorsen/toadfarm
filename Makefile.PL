use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'Toadfarm',
  VERSION => '0.03',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  EXE_FILES => [ 'script/toadfarm' ],
  PREREQ_PM => {
    'Mojolicious' => '3.91'
  },
  test => {
    TESTS => 't/*.t'
  },
);
