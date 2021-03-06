use strict;

# tests for the correct expansion of INCLUDE

package Fn_INCLUDE;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'INCLUDE', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{other_web} = "$this->{test_web}other";
    my $webObject = $this->populateNewWeb( $this->{other_web} );
    $webObject->finish();
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, $this->{other_web} );
    $this->SUPER::tear_down();
}

# Test that web references are correctly expanded when a topic is included
# from another web. Verifies that verbatim, literal and noautolink zones
# are correctly honoured.
sub test_webExpansion {
    my $this = shift;

    # Create topic to include
    my $includedTopic = "TopicToInclude";
    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text( <<THIS);
<literal>
1 [[$includedTopic][one]] $includedTopic
</literal>
<verbatim>
2 [[$includedTopic][two]] $includedTopic
</verbatim>
<pre>
3 [[$includedTopic][three]] $includedTopic
</pre>
<noautolink>
4 [[$includedTopic][four]] [[$includedTopic]] $includedTopic
</noautolink>
5 [[$includedTopic][five]] $includedTopic
$includedTopic 6
7 ($includedTopic)
8 #$includedTopic
9 [[System.$includedTopic]]
10 [[$includedTopic]]
11 [[http://fleegle][$includedTopic]]
12 [[#anchor][$includedTopic]]
13 [[#$includedTopic][$includedTopic]]
THIS
    $inkyDink->save();

    # Expand an include in the context of the test web
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $text = $topicObject->expandMacros(
        "%INCLUDE{$this->{other_web}.$includedTopic}%");
    my @get    = split( /\n/, $text );
    my @expect = split( /\n/, <<THIS);
<literal>
1 [[$includedTopic][one]] $includedTopic
</literal>
<verbatim>
2 [[$includedTopic][two]] $includedTopic
</verbatim>
<pre>
3 [[$this->{other_web}.$includedTopic][three]] $this->{other_web}.$includedTopic
</pre>
<noautolink>
4 [[$this->{other_web}.$includedTopic][four]] [[$this->{other_web}.$includedTopic][$includedTopic]] $includedTopic
</noautolink>
5 [[$this->{other_web}.$includedTopic][five]] $this->{other_web}.$includedTopic
$this->{other_web}.$includedTopic 6
7 ($this->{other_web}.$includedTopic)
8 #$includedTopic
9 [[System.$includedTopic]]
10 [[$this->{other_web}.$includedTopic][$includedTopic]]
11 [[http://fleegle][$includedTopic]]
12 [[#anchor][$includedTopic]]
13 [[#$includedTopic][$includedTopic]]
THIS
    while ( my $e = pop(@expect) ) {
        $this->assert_str_equals( $e, pop(@get) );
    }

}

# Test include of a section when there is no such section in the included
# topic
sub test_3158 {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text(<<THIS);
Snurfle
%STARTSECTION{"suction"}%
Such a section!
%ENDSECTION{"suction"}%
Out of scope
THIS
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\"}%");
    $this->assert_str_equals( "\nSuch a section!\n", $text );

    $inkyDink->text(<<THIS);
%STARTSECTION{"nosuction"}%
No such section!
%ENDSECTION{"nosuction"}%
THIS
    $inkyDink->save();

    #warnings are off
    $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\" warn=\"off\"}%"
      );
    $this->assert_str_equals( '', $text );

    #warning on
    $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\" warn=\"on\"}%"
      );
    $this->assert_str_equals( <<HERE, $text . "\n" );
<span class='foswikiAlert'>
    Warning: Can't find named section <nop>suction in topic <nop>TemporaryINCLUDETestWebINCLUDEother.<nop>TopicToInclude 
</span>
HERE

    #custom warning
    $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"suction\" warn=\"consider yourself warned\"}%"
      );
    $this->assert_str_equals( 'consider yourself warned', $text );
}

# INCLUDE{"" section=""}% should act as though section was not set (ie, return the entire topic)
sub test_5649 {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Snurfle
%STARTSECTION{"suction"}%
Such a section!
%ENDSECTION{"suction"}%
Out of scope
THIS
    my $handledTopicText = $topicText;
    $handledTopicText =~ s/%(START|END)SECTION{"suction"}%//g;

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" section=\"\"}%");
    $this->assert_str_equals( $handledTopicText, $text . "\n" )
      ;    #add \n because expandMacros removes it :/
}

sub test_singlequoted_params {
    my $this = shift;
    my $text =
      $this->{test_topicObject}
      ->expandMacros("%INCLUDE{'Oneweb.SomeTopic' section='suction'}%");
    $this->assert_str_equals(
        "<span class='foswikiAlert'>
   Warning: Can't INCLUDE '<nop>'Oneweb.SomeTopic' section='suction'', path is empty or contains illegal characters. 
</span>", $text
    );

    $text =
      $this->{test_topicObject}
      ->expandMacros('%INCLUDE{"I can\'t beleive its not butter"}%');
    $this->assert_str_equals(
        "<span class='foswikiAlert'>
   Warning: Can't INCLUDE '<nop>I can't beleive its not butter', path is empty or contains illegal characters. 
</span>", $text
    );
}

sub test_fullPattern {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\"^.*?(Have.*sir).*\"}%"
      );
    $this->assert_str_equals( "Have you any socks?\nYes sir, yes sir", $text );
}

sub test_pattern {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
"%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\"(Have.*sir)\"}%"
      );
    $this->assert_str_equals( "Have you any socks?\nYes sir, yes sir", $text );
}

# INCLUDE{"" pattern="(blah)"}% that does not match should return nothing
sub test_patternNoMatch {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\"(blah)\"}%");
    $this->assert_str_equals( "", $text );
}

# INCLUDE{"" pattern="blah"}% that does not capture should return nothing
sub test_patternNoCapture {
    my $this          = shift;
    my $includedTopic = "TopicToInclude";
    my $topicText     = <<THIS;
Baa baa black sheep
Have you any socks?
Yes sir, yes sir
But only in acrylic
THIS

    my ($inkyDink) =
      Foswiki::Func::readTopic( $this->{other_web}, $includedTopic );
    $inkyDink->text($topicText);
    $inkyDink->save();
    my $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"$this->{other_web}.$includedTopic\" pattern=\".*\"}%");
    $this->assert_str_equals( "", $text );
}

sub test_docInclude {
    my $this = shift;

    my $class = 'Foswiki::IncludeHandlers::doc';
    my $text = $this->{test_topicObject}->expandMacros("%INCLUDE{doc:$class}%");
    my $expected = <<"EXPECTED";

---+ =internal package= Foswiki::IncludeHandlers::doc

This package is designed to be lazy-loaded when Foswiki sees
an INCLUDE macro with the doc: protocol. It implements a single
method INCLUDE which generates perl documentation for a Foswiki class.

EXPECTED
    $this->assert_str_equals( $expected, $text );

    # Add a pattern
    $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"doc:$class\" pattern=\"(Foswiki .*protocol)\"}%");
    $expected = "Foswiki sees\nan INCLUDE macro with the doc: protocol";
    $this->assert_str_equals( $expected, $text );

    # A pattern with no ()'s
    $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"doc:$class\" pattern=\"Foswiki .*protocol\"}%");
    $expected = '';
    $this->assert_str_equals( $expected, $text );

    # A pattern that does not match
    $text =
      $this->{test_topicObject}->expandMacros(
        "%INCLUDE{\"doc:$class\" pattern=\"(cabbage.*avocado)\" warn=\"no\"}%");
    $expected = '';
    $this->assert_str_equals( $expected, $text );
}

1;
