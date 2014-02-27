# Base class for tests for browser-in-the-loop tests using Selenium WebDriver
#
# The FoswikiFnTestCase restrictions also apply.

package FoswikiSeleniumWdTestCase;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Encode;
use Foswiki();
use Unit::Request();
use Unit::Response();
use Foswiki::UI::Register();
use Error qw( :try );
use Scalar::Util qw( weaken );

my $startWait;
my $doze;

BEGIN {
    if ( eval { require Time::HiRes; Time::HiRes->import(qw/usleep time/); 1; }
      )
    {
        $startWait = sub { return time(); };

        # success
        $doze = sub {
            usleep(100_000);
            return ( time() - $_[0] ) * 1000;
        };
    }
    else {

        # use failed
        $startWait = sub { return time(); };
        $doze = sub {
            sleep(1);
            return ( time() - $_[0] ) * 1000;
        };
    }
}

my $useSeleniumError;
my $browsers;
my @BrowserFixtureGroups;
my $testsRunWithoutRestartingBrowsers = 0;

my $debug = 0;

sub skip {
    my ( $this, $test ) = @_;
    my $browsers = $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers};
    my $reason;

    if ( !( ref($browsers) eq 'HASH' && scalar( keys %{$browsers} ) ) ) {
        $reason =
"No browsers configured in \$Foswiki::cfg{UnitTestContrib}{SeleniumWd}{Browsers}";
    }

    if ( $this->{useSeleniumError} ) {
        $reason = "Cannot run Selenium-based tests: $this->{useSeleniumError}";
    }

    return $reason;
}

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    $this->{selenium_timeout} = 30_000;  # Same as WWW::Selenium's default value
    $this->{useSeleniumError} = $this->_loadSeleniumInterface;
    $this->{seleniumBrowsers} = $this->_loadSeleniumBrowsers;

    $this->timeout( $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{BaseTimeout} );

    return $this;
}

END {
    _shutDownSeleniumBrowsers() if $browsers;
}

sub DESTROY {
    my $this = shift;

    # avoid memory leaks - the limit was arbitrarily chosen
    $testsRunWithoutRestartingBrowsers++;
    if ( $testsRunWithoutRestartingBrowsers > 10 ) {
        _shutDownSeleniumBrowsers();
        $testsRunWithoutRestartingBrowsers = 0;
    }

    $this->SUPER::DESTROY if $this->can('SUPER::DESTROY');
}

sub fixture_groups {
    my ( $this, $suite ) = @_;

    return \@BrowserFixtureGroups if @BrowserFixtureGroups;

    for my $browser ( keys %{ $this->{seleniumBrowsers} } ) {
        my $onBrowser = "on$browser";
        push @BrowserFixtureGroups, $onBrowser;

        die $@
          if ( !eval
"sub $onBrowser { my \$this = shift; \$this->selectBrowser(\$browser); } 1;"
          );
    }
    return \@BrowserFixtureGroups;
}

sub selectBrowser {
    my $this        = shift;
    my $browserName = shift;
    $this->assert( defined($browserName), "Browser name not specified" );
    $this->assert(
        exists( $this->{seleniumBrowsers}->{$browserName} ),
        "No browser definition for $browserName"
    );
    $this->{browser}  = $browserName;
    $this->{selenium} = $this->{seleniumBrowsers}->{$browserName};
}

sub _loadSeleniumInterface {
    my $this = shift;

    return $useSeleniumError if defined $useSeleniumError;

    if ( !eval { require Selenium::Remote::Driver; 1; } ) {
        $useSeleniumError = $@;
        $useSeleniumError =~ s/\(\@INC contains:.*$//s;
    }
    else {
        $useSeleniumError = '';
    }
    return $useSeleniumError;
}

sub _loadSeleniumBrowsers {
    my $this = shift;

    return $browsers if $browsers;

    $browsers = {};

    if ( $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} ) {
        for my $browser (
            keys %{ $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} } )
        {
            my %config =
              %{ $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers}{$browser}
              };

            my $selenium;
            if ( $this->{useSeleniumError} ) {
                $browsers->{$browser} = undef;
            }
            else {
                $selenium = Selenium::Remote::Driver->new(%config);
                if ($selenium) {
                    $browsers->{$browser} = $selenium;
                }
                else {
                    $this->assert( 0,
"Could not create a Selenium::Remote::Driver object for $browser"
                    );
                }
            }
        }
    }
    if ( keys %{$browsers} ) {
        die $@ if ( !eval { require Test::Builder; 1; } );
        my $test = Test::Builder->new;
        $test->reset();
        $test->no_plan();
        $test->no_diag(1);
        $test->no_ending(1);
        my $testOutput = '';
        $test->output( \$testOutput );
    }

    return $browsers;
}

sub _shutDownSeleniumBrowsers {
    for my $browser ( values %$browsers ) {
        print STDERR "Shutting down $browser\n" if $debug;
        $browser->quit() if $browser;
    }
    undef $browsers;
}

sub browserName {
    my $this = shift;
    return $this->{browser};
}

sub currentBrowserIs {
    my $this = shift;
    my %spec = @_;
    my $b = $this->{seleniumBrowsers}{ $this->{browser} };
    return 0 if exists $spec{browser_name} && $spec{browser_name} ne $b->{browser_name};
    return 0 if exists $spec{version} && $spec{version} ne $b->{version};
    return 0 if exists $spec{platform} && $spec{platform} ne $b->{platform};
    return 1;
}

sub selenium {
    my $this = shift;
    return $this->{selenium};
}

sub login {
    my $this = shift;
    my $s = $this->{selenium};

    #SMELL: Assumes TemplateLogin
    $s->get(
        Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'login' )
    );
    $s->find_element( '//input[@name="username"]' )->send_keys( $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username} );

    $s->find_element( '//input[@name="password"]' )->send_keys( $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password} );

    $s->find_element( '//input[@type="submit"]' )->click;

    my $postLoginLocation = $s->get_current_url;
    my $viewUrl =
      Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
        'view' );
    $this->assert_matches( qr/\Q$viewUrl\E$/, $postLoginLocation, 'Login to Foswiki failed' );
}

sub timeout {
    my $this    = shift;
    my $timeout = shift;
    $this->{selenium_timeout} = $timeout if $timeout;
    return $this->{selenium_timeout};
}

sub waitFor {
    my $this    = shift;
    my $testFn  = shift;
    my $message = shift;
    my $args    = shift;
    my $timeout = shift;
    $timeout ||= $this->{selenium_timeout};
    $args ||= [];
    my $result;
    my $elapsed = 0;
    my $start   = $startWait->();

    while ( not $result and $elapsed < $timeout ) {
        $result = $testFn->( $this, @$args );
        $elapsed = $doze->($start) if not $result;
    }
    $this->assert( $result, $message || "timeout" );
}

my $extractLocator = sub {
    my $text = shift;
    if ( $text =~ /^(class|class_name|css|id|link|link_text|partial_link_text|tag_name|name|xpath)=(.*)$/ ) {
        return ($2, $1);
    }
    return ( $text, 'xpath' );
};

sub assertElementIsPresent {
    my $this    = shift;
    my ( $locator, $locatorType ) = $extractLocator->(shift);
    my $message = shift;
    $message ||= "Element $locator is not present";
    $this->assert( $this->{selenium}->find_element($locator, $locatorType), $message );

    return;
}

sub assertElementIsVisible {
    my $this    = shift;
    my ( $locator, $locatorType ) = $extractLocator->(shift);
    my $message = shift;
    $message ||= "Element $locator is not visible";
    $this->assert( $this->{selenium}->find_element( $locator, $locatorType )->is_displayed, $message );

    return;
}

sub assertElementIsNotVisible {
    my $this    = shift;
    my ( $locator, $locatorType ) = $extractLocator->(shift);
    my $message = shift;
    $this->assertElementIsPresent($locator);
    $message ||= "Element $locator is visible";
    $this->assert( not $this->{selenium}->find_element( $locator, $locatorType )->is_displayed, $message );

    return;
}

1;
