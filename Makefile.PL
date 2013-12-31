use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Toadfarm',
  ABSTRACT_FROM => 'lib/Toadfarm.pm',
  VERSION_FROM => 'lib/Toadfarm.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'File::Which' => '1.00',
    'Mojolicious' => '4.63',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Toadfarm',
      bugtracker => 'https://github.com/jhthorsen/toadfarm/issues',
      repository => 'https://github.com/jhthorsen/toadfarm',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  EXE_FILES => ['script/toadfarm'],
);
