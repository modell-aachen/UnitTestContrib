package ModacUnitTestCase;

use strict;
use warnings;

use Foswiki::Func;

use FoswikiFnTestCase();
our @ISA = qw(FoswikiFnTestCase);
our %mockedFunctions;


sub new {
	my $class = shift;
  	my $this  = $class->SUPER::new(@_);

  	return $this;
}

sub tear_down {
    my $this = shift;

    $this->_revertAllMocks();
    $this->SUPER::tear_down();
    return;
}

sub mock {
	my ($this, $functionToMock, $mockFunction) = @_;
	no strict 'refs';
	$mockedFunctions{$functionToMock} = *{$functionToMock};
	undef *{$functionToMock};
	*{$functionToMock} = $mockFunction;
	return;
}

sub _revertAllMocks {
	while(my ($functionName, $originalFunction) = each %mockedFunctions) {
		no strict 'refs';
		undef *{$functionName};
		*{$functionName} = $originalFunction;
	}
	%mockedFunctions = ();
	return;
}

1;
