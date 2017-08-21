package ModacUnitTestCase;

use strict;
use warnings;

use Foswiki::Func;

use FoswikiFnTestCase();
our @ISA = qw(FoswikiFnTestCase);

sub new {
  my $class = shift;
  my $this  = $class->SUPER::new(@_);

  return $this;
}

1;
