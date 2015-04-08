# See bottom of file for license and copyright information

package ModacTestRunnerSeleniumTestCase;

use FoswikiSeleniumWdTestCase();
our @ISA = qw( FoswikiSeleniumWdTestCase );

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

# XXX Copy/Paste/Change from FoswikiSeleniumTestCase
sub login {
    my $this = shift;

    #SMELL: Assumes TemplateLogin
    $this->{selenium}->get(
        Foswiki::Func::getScriptUrl(
            $this->{test_web}, $this->{test_topic}, 'login', t => time()
        )
    );
    $this->waitForPageToLoad();
    my $usernameInputFieldLocator = 'input[name="username"]';
    $this->{selenium}->find_element($usernameInputFieldLocator, 'css')->send_keys($Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username});
    my $passwordInputFieldLocator = 'input[name="password"]';
    $this->{selenium}->find_element($passwordInputFieldLocator, 'css')->send_keys($Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password});

    my $loginFormLocator = 'form[name="loginform"]';
    $this->{selenium}->find_element('//input[@type="submit"]')->click();

    my $postLoginLocation = $this->{selenium}->get_current_url();
    my $viewUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );

    # XXX change here, so short urls work
    my $viewUrlShort = $viewUrl;
    $viewUrlShort =~ s#/bin/view##;
    my $urlTest = qr/^(?:\Q$viewUrl\E|\Q$viewUrlShort\E)$/;
    unless($postLoginLocation=~m/$urlTest/) {
        sleep(5); # maybe the page didn't load yet
        $postLoginLocation = $this->{selenium}->get_current_url();
        my $attempt = shift || 0;
        if(not $postLoginLocation=~m/$urlTest/ && $attempt < 5) {
            return $this->login(++$attempt);
        }
    }
    $this->assert_matches( qr/\Q$viewUrl\E|\Q$viewUrlShort\E$/, $postLoginLocation );
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

# XXX Make sure new page loaded before continueing.
# This should not be required, but seems to be buggy on ff atm.
# Note: Updating Selenium::Remote::Driver to 0.2102 did not redeem this
sub waitForPageToLoad {
    my $this = shift;
    $this->waitFor( sub { $this->{selenium}->execute_script('if(window.SeleniumMarker) return 0; return jQuery("#modacContentsWrapper").length'); }, 'Page did not load after transition', undef, 10_000 );
}
# Sets a marker for waitForPageToLoad to listen to.
sub setMarker {
    my ( $this) = @_;
    $this->{selenium}->execute_script("window.SeleniumMarker = 1");
}
