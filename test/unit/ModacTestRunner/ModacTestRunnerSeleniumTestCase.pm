# See bottom of file for license and copyright information

package ModacTestRunnerSeleniumTestCase;

use ModacSeleniumTestCase;
our @ISA = qw( ModacSeleniumTestCase );

use strict;
use warnings;

use Foswiki();
use Error qw ( :try );

sub new {
    my ($class, @args) = @_;
    my $this = $class->SUPER::new('ModacTestRunnerSeleniumTestCase', @args);

    return $this;
}

sub registerUser {
    # we need no additional users (Selenium user should already exist)
}

sub verify_SeleniumRc_config {
    my $this = shift;
    $this->selenium->get(
        Foswiki::Func::getScriptUrl(
            $this->{test_web}, $this->{test_topic}, 'view'
        )
    );

    $this->login();
}
