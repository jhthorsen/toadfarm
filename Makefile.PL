use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Toadfarm',
  ABSTRACT_FROM => 'lib/Toadfarm.pm',
  VERSION_FROM => 'lib/Toadfarm.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'Mojolicious' => '4.30',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Toadfarm',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Toadfarm',
      repository => 'git@github.com:jhthorsen/toadfarm.git',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  EXE_FILES => ['script/toadfarm'],
);
