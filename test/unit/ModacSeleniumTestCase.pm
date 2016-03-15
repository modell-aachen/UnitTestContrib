package ModacSeleniumTestCase;

use strict;
use warnings;

use Error qw(:try);
use Foswiki::Func;
use Selenium::Remote::WDKeys;

use FoswikiSeleniumWdTestCase();
our @ISA = qw(FoswikiSeleniumWdTestCase);

our $loggedIn = 0;

sub skip {
  my ($this, $test) = @_;

  my $package = ref($this);
  if ( $test && $ENV{DOTEST} && $test !~ m#^\Q$package\E::\Q$ENV{DOTEST}\E_on# ) {
    return "Test not selected. Skipping...";
  }

  return $this->SUPER::skip( $test );
}

# XXX Copy/Paste/Change from FoswikiSeleniumTestCase
sub login {
  return if $loggedIn;
  my $this = shift;
  my $topic = shift || $this->{test_topic};

  # There might be an editor left open from a previous test, don't let it interupt us
  if ( $this->{selenium}->get_current_url() =~ m#/edit# ) {
    $this->{selenium}->execute_script('window.onbeforeunload = function(e){};');
  }

  #SMELL: Assumes TemplateLogin
  $this->{selenium}->get(
    Foswiki::Func::getScriptUrl(
      $this->{test_web}, $topic, 'login',
      t => time()
    )
  );
  $this->waitForPageToLoad();

  $this->{selenium}->find_element('input[name="username"]', 'css')->send_keys(
    $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username}
  );
  $this->{selenium}->find_element('input[name="password"]', 'css')->send_keys(
    $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password}
  );

  $this->setMarker();
  my $loginFormLocator = 'form[name="loginform"]';
  $this->{selenium}->find_element('//input[@type="submit"]')->click();
  $this->waitForPageToLoad();

  my $postLoginLocation = $this->{selenium}->get_current_url();
  my $viewUrl =
    Foswiki::Func::getScriptUrl($this->{test_web}, $topic,'view');

  # make short urls work
  my $viewUrlShort = $viewUrl;
  $viewUrlShort =~ s#/bin/view##;
  my $urlTest = qr#^(?:\Q$viewUrl\E|\Q$viewUrlShort\E)$#;
  unless ( $postLoginLocation=~m/$urlTest/ ) {
    sleep(5); # maybe the page didn't load yet
    $postLoginLocation = $this->{selenium}->get_current_url();
    my $attempt = shift || 0;
    if(not $postLoginLocation=~m/$urlTest/ && $attempt < 5) {
      return $this->login(++$attempt);
    }
  }
  $this->assert_matches( $urlTest, $postLoginLocation );
  $loggedIn = 1;
}

sub becomeSeleniumUser {
  my ( $this ) = @_;

  my $user = $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username};
  $this->createNewFoswikiSession( $user );
  return $user;
}

sub becomeAnAdmin {
  my ( $this ) = @_;

  $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} || 'AdminUser' );
  my $user = Foswiki::Func::getWikiName();
  $this->assert( Foswiki::Func::isAnAdmin($user), "Could not become AdminUser, tried as $user." );
  return $user;
}

sub edit {
  my ($this, $web, $topic, $params) = @_;
  $params->{t} = time unless defined $params->{t};
  $this->{selenium}->get(
    Foswiki::Func::getScriptUrl($web, $topic, 'edit', $params)
  );
}

sub save {
  my $this = shift;
  $this->{selenium}->find_element('#save', 'css')->click();
}

sub cancel {
  my $this = shift;
  $this->{selenium}->find_element('#cancel', 'css')->click();
}

sub view {
    my ($this, $web, $topic, $params) = @_;
    $this->{selenium}->get(
      Foswiki::Func::getScriptUrl($web, $topic, 'view', $params)
    );
}

# XXX Make sure new page loaded before continueing.
# This should not be required, but seems to be buggy on ff atm.
# Note: Updating Selenium::Remote::Driver to 0.2102 did not redeem this
sub waitForPageToLoad {
    my $this = shift;
    $this->waitFor(sub {
        $this->{selenium}->execute_script('if(window.SeleniumMarker) return 0; return jQuery("#modacContentsWrapper").length');
    }, 'Page did not load after transition', undef, 10_000 );
}

# Sets a marker for waitForPageToLoad to listen to.
sub setMarker {
    my ( $this) = @_;
    $this->{selenium}->execute_script("window.SeleniumMarker = 1");
}

sub waitForSelector {
  my ($this, $selector, $ms, $negate, ) = @_;
  my $negated = $negate ? ' === 0' : '';
  $this->waitFor(
    sub {
      $this->{selenium}->execute_script("return jQuery('$selector').length$negated");
    },
    "'$selector' did not become ready...",
    undef,
    $ms || 10_000
  );
}

sub waitForBlockUI {
  my ($this, $ms) = @_;
  $this->waitForSelector('.blockUI.blockOverlay', $ms, 1);
}

1;
