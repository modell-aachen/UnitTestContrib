package ModacSeleniumTestCase;

use strict;
use warnings;

use Error qw(:try);
use Foswiki::Func;
use Selenium::Remote::WDKeys;

use FoswikiSeleniumWdTestCase();
our @ISA = qw(FoswikiSeleniumWdTestCase);

our $loggedIn = 0;

sub new {
  my $class = shift;
  my $this  = $class->SUPER::new(@_);

  my $usr = $ENV{TESTUSERS} || $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username};
  $usr =~ s/\s*//g;
  my @users = split(/,/, $usr);
  $this->{users} = \@users;
  return $this;
}

sub loadExtraConfig {
  # Skip initialization from FoswikiFnTestCase
}

sub set_up {
  my $this = shift;
  # Skip initialization from FoswikiFnTestCase and go directly to FoswikiTestCase
  FoswikiTestCase::set_up($this, @_);

  # partial copy from FoswikiFnTestCase follows
  # (skips registering dummy user)

  my $query = new Unit::Request("");
  $query->path_info("/$this->{test_web}/$this->{test_topic}");

  # Note: some tests are testing Foswiki::UI which also creates a session
  $this->createNewFoswikiSession( undef, $query );
  $this->{response} = new Unit::Response();
  $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
  my $webObject = $this->populateNewWeb( $this->{test_web} );
  $webObject->finish();

  $this->{tempWebs} = {};

  $this->{test_topicObject}->finish() if $this->{test_topicObject};
  ( $this->{test_topicObject} ) =
    Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
  $this->{test_topicObject}->text("%HRT%\n");
  $this->{test_topicObject}->save( forcedate => ( time() + 60 ) );
}

sub tear_down {
  my $this = shift;

  # partial copy from FoswikiFnTestCase follows
  # (skips things related to user fixtures)

  $this->removeWebFixture( $this->{session}, $this->{test_web} );

  # Clean up stuff created by installAppWeb
  while (my ($k, $v) = each(%{$this->{tempWebs}})) {
    for (my $i = 1; $i < $v; $i++) {
      $this->removeWebFixture( $this->{session}, "Temporary${k}Web$i" );
    }
  }

  # go directly to grandparent, skip FoswikiFnTestCase
  FoswikiTestCase::tear_down($this, @_);

}

sub skip {
  my ($this, $test) = @_;

  my $package = ref($this);
  if ( $test && $ENV{DOTEST} && $test !~ m#^\Q$package\E::\Q$ENV{DOTEST}\E_on# ) {
    return "Test not selected. Skipping...";
  }

  return $this->SUPER::skip( $test );
}

sub assertElementIsPresent {
  my $this = shift;
  my $selector = shift;

  unless ($selector =~ /^\w+=.+/) {
    $selector = "css=$selector";
  }

  $this->SUPER::assertElementIsPresent($selector, @_);
  return;
}

# Create a temporary copy of an app for testing
# TODO: the current install process moves the app out of _apps so this will fail
# TODO: if a test errors out, tear_down is not executed so the temp web remains,
#       and if this is run again in the same wiki it will die in AppManagerPlugin::_install
sub installAppWeb {
  my ($this, $appname) = @_;
  my $target = "Temporary${appname}Web";
  $this->{tempWebs}{$appname} //= 1;
  $target .= $this->{tempWebs}{$appname}++;
  require Foswiki::Plugins::AppManagerPlugin;
  my $res = Foswiki::Plugins::AppManagerPlugin::_install($appname, { copy => 1, installname => $target });
  unless ($res->{result} eq 'ok') {
    die "Installing temporary web for '$appname' failed: ". JSON->new->utf8->pretty->encode($res) ."\n";
  }
  $target;
}

sub createTestTopic {
  my ($this, $web, $topic, %opts) = @_;
  $this->assert(!Foswiki::Func::topicExists($web, $topic));
  my $time = delete $opts{date} || time;
  my $author = delete $opts{author} || $this->{session}{user};
  my $text = '';
  $text .= delete $opts{text} if $opts{text};
  if (keys %opts) {
    $text .= "\n\n";
    $text .= qq[\%META:FORM{name="$opts{form}"}%\n] if $opts{form};
    while (my ($k, $v) = each(%{$opts{fields} || {}})) {
      $text .= qq[\%META:FIELD{name="$k" value="$v"}%\n];
    }
    # TODO: directly support attachments, other metadata
  }
  my $meta = Foswiki::Meta->new($this->{session}, $web, $topic, $text);
  $meta->save(
    forcedate => $time,
    author => $author,
  );
}

sub normalizeEpoch {
  my ($this, $epoch) = @_;
  Foswiki::Time::formatTime($epoch, '$epoch', 'servertime');
}

sub setInputValue {
  my ($this, $selector, $value) = @_;
  my $elem = $this->{selenium}->find_element($selector, 'css');
  $elem->send_keys($value);
}

sub setDate2Today {
  my $this = shift;
  my $selector = shift;
  my $s = $this->{selenium};

  $s->find_element($selector, 'css')->click();
  $s->find_element("$selector + .picker--opened .picker__button--today", 'css')->click();
}

sub setDate2Empty {
  my $this = shift;
  my $selector = shift;
  my $s = $this->{selenium};

  $s->find_element($selector, 'css')->click();
  $s->find_element("$selector + .picker--opened .picker__button--clear", 'css')->click();
}

sub setDate2Value {
  my $this = shift;
  my $selector = shift;
  my ($year, $month, $day) = @_;
  my $s = $this->{selenium};

  unless ($month && $day) {
    my $date = Foswiki::Time::formatTime($year, '$year $mo $day');
    ($year, $month, $day) = map {int($_)} split(/\s/, $date);
  }

  # months are zero based
  $month = $month - 1 if $month;

  $s->find_element($selector, 'css')->click();
  my $elemY = $s->find_element("$selector + .picker--opened .picker__select--year", 'css');
  $s->find_child_element($elemY, "option[value=\"$year\"]", 'css')->click();

  my $elemM = $s->find_element("$selector + .picker--opened .picker__select--month", 'css');
  $s->find_child_element($elemM, "option[value=\"$month\"]", 'css')->click();

  my @days = $s->find_elements("$selector + .picker--opened .picker__table td div", 'css');
  foreach my $div (@days) {
    my $txt = $div->get_text();
    $txt =~ s/\s*//g;
    if ($txt =~ /^$day$/) {
      $div->click();
      last;
    }
  }

  # ...
  # Waiting 2 secs allows us to set more than one datepicker value
  $s->pause(2000);
}

sub setPickADateValue{
  my $this = shift;
  my $name = shift;
  my($day, $month, $year) = @_;
  my $sel = $this->{selenium};

  unless ($month && $year) {
    my $date = Foswiki::Time::formatTime($day, '$year $mo $day');
    ($year, $month, $day) = map {int($_)} split(/\s/, $date);
  }
  if(int($day) < 10){
    $day = "0".$day;
  }
  $month = $month-1;
  my $inputfield = $sel->find_element("input[data-name='$name']", 'css');
  $inputfield->click(); #open pickadate

  $sel->find_element("div[aria-hidden='false'] .picker__button--today", 'css')->click(); #get current date
  $inputfield->click(); #open pickadate

  my $selYear = $sel->find_element("div[aria-hidden='false'] .picker__select--year", 'css');

  while($selYear->get_value() != $year){
    my $value = $selYear->get_value();
    if($value < $year){
      $this->setSelectValues("div[aria-hidden='false'] .picker__select--year", $value+1);
    }elsif ($value > $year){
      $this->setSelectValues("div[aria-hidden='false'] .picker__select--year", $value-1);
    }
    $selYear = $sel->find_element("div[aria-hidden='false'] .picker__select--year", 'css');
    $value = $selYear->get_value();
  }
  # set month
  $this->setSelectValues("div[aria-hidden='false'] .picker__select--month", $month);

  #set day
  $sel->find_element(".picker--opened div[aria-label^='$day']", 'css')->click();
  $sel->pause(1000);
}


sub setSelectValues {
  my $this = shift;
  my $selector = shift;
  my @values = @_;
  my $s = $this->{selenium};

  # XXX unfortunately the click on an option fails on firefox
  # Doing a JavaScript workaround

  my $select = $s->find_element($selector, 'css');
  $select->click();
#  my @options = $s->find_child_elements($select, 'option', 'css');
#  foreach my $value (@values) {
#    my $option = $s->find_child_element($select, "option[value=\"$value\"]", 'css');
#    if ($option) {
#      $option->click();
#      next;
#    }
#
#    my @results = grep {$_->get_text() =~ /^$value$/} @options;
#    $results[0]->click() if scalar(@results);
#  }
  my $escapedSelector = $selector;
  $escapedSelector =~ s#'#\\'#g;
  foreach my $value (@values) {
      $s->execute_script("jQuery('$escapedSelector').blur().val(\"$value\").change()");
  }

}

sub setSelect2Values {
  my $this = shift;
  my $selector = shift;
  my @values = @_;
  my $s = $this->{selenium};

  $this->waitForSelector($selector);
  $selector .= ' + .select2' unless $selector =~ /\+\s?\.select2$/;
  my $elem = $s->find_element($selector, 'css');
  my $resultSel = '.select2-results__option--highlighted';

  my @results;
  foreach my $value (@values) {
    $elem->click();
    $this->waitForSelector('.select2-container--open');
    $s->find_element('.select2-container--open .select2-search__field', 'css')->send_keys($value);
    $this->waitForSelector('.select2-results__option.loading-results', 10_000, 1);

    for (my $i = 0; $i < 15; $i++) {
      $this->waitForSelector($resultSel);
      my $result = $s->find_element($resultSel, 'css');
      my $txt = $result->get_text();

      if (grep(/^$txt$/, @results)) {
        sleep(1);
        next;
      } else {
        push(@results, $txt);
        $result->click();
        last;
      }
    }
  }
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
        $this->{selenium}->execute_script('if(window.SeleniumMarker) return 0; if(typeof jQuery !== "function" || typeof foswiki !== "object") return 0; return jQuery("#modacContentsWrapper").length');
    }, 'Page did not load', undef, 10_000 );
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
sub waitForWindowClosed {
  my ($this,$sel) = @_;
  $this->waitFor(sub {
    my $hand = $sel->get_window_handles;
    scalar @$hand < 2;
  }, 'Window does not close...', undef, 15_000 );
}

1;
