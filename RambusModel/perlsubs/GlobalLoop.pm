#!/usr/local/bin/perl

package perlsubs::GlobalLoop;

# This package performs all operations specific to the section globalloop

# End User License Agreement for Software:
# 
# Copyright © 2010 Rambus Inc.  All Rights Reserved.
# 
# Use and modification of the software by the recipient is permitted.
# Redistribution of the software to any third party is not permitted without
# the express written authorization of Rambus Inc.
# Rambus Inc. has no obligation to provide any training for the software,
# or to correct any bugs, defects or errors, or to otherwise support, develop
# or maintain the software.
# 
# THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NONINFRINGEMENT,
# WHICH WARRANTIES ARE EXPRESSLY DISCLAIMED.  THE SOFTWARE MAY INCLUDE
# TECHNICAL INACCURACIES OR OTHER ERRORS.  RAMBUS INC. RESERVES THE RIGHT
# TO MAKE CHANGES TO THE SOFTWARE WITHOUT OBLIGATION TO NOTIFY ANY PERSON
# OR ORGANIZATION.  SUCH CHANGES MAY, AT RAMBUS INC.'S DISCRETION, BE
# INCORPORATED IN NEW VERSIONS OF THE SOFTWARE.  RAMBUS INC. MAY MAKE
# IMPROVEMENTS AND/OR CHANGES TO THE TECHNOLOGY DESCRIBED IN THE SOFTWARE
# AT ANY TIME.
# 
# IN NO EVENT WILL RAMBUS INC. OR ITS AFFILIATES BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES,
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING 
# IN ANY WAY OUT OF THE USE OF THE SOFTWARE, EVEN IF ADVISED OF THE POSSIBLITY
# OF SUCH DAMAGE.
# 
# Rambus Inc. may have patents, patent applications, trademarks, copyrights,
# or other intellectual property rights covering the contents of the software,
# and Rambus Inc. and its licensors retain all right, title, and interest in
# and to such intellectual property rights.  Except as expressly provided in
# a written agreement between you and Rambus Inc., the furnishing of the
# software does not grant you any license, express or implied, to any such
# patents, patent applications, trademarks, copyrights, or other intellectual
# property of Rambus Inc.
# 
# "XDR" and "Rambus" are trademarks or registered trademarks of Rambus Inc.
# protected by the laws of the United States or other countries.  
# 
# For additional information, please contact:
# Rambus Inc.
# 1050 Enterprise Way, Suite 700
# Sunnyvale, CA 94089
# 408-462-8000

use strict;
use warnings;

# Global variables

# Legal keys
my %valid_keys = (
  loop => 1,
  type => 1,
  );

sub check_loop {

  # performs syntax check of key loop

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    section => 1,
    key => 1,
    subkey => 1,
    value => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'loop'.\n";
    }

  }

sub check_type {

  # performs syntax check of key type

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    dimension => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'loop'.\n";
    }
    
  # Check values
  if (($value ne "one")&&($value ne "multi")&&($value ne "zero")) {
    $$errflag = 1;
    $$errstr .= "'$value' is not a valid value of subkey '$subkey' of key '$key' in section 'loop'.\n";
    }

  }

sub GlobalLoop::check_syntax {

  # Performs syntax checking in section GlobalLoop
  
  # External variables
  my ($input, $errflag, $errstr) = @_;
  # input: reference to hash with keys and values
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  # Create list of all used keys
  my %found_keys = ();
  foreach (sort keys %$input) {
    my @words = split (/-/, $_);
    $found_keys{$words[0]} = 1;
    }

  # Check if there are not valid keys
  foreach (sort keys %found_keys) {
    my $key_stem = $_;
    $key_stem =~ s/[0-9]+$//;
    if (($key_stem ne "type")&&(!(exists $valid_keys{$key_stem})||(!(/[0-9]+$/)))) {
      $$errflag = 1;
      $$errstr .= "'" . $_ . "' is not a valid key in section 'globalloop'.\n";
      }
    }
  
  # Check for each key if subkeys and values are correct
  foreach (sort keys %$input) {
  
    # Get key, subkey and value
    my ($key, $subkey) = split (/-/, $_);
    my $value = $$input{$_};
    
    # Check  key, subkey and value combination
    # Error handling for not valid keys has been done above
    my $key_stem = $key;
    $key_stem =~ s/[0-9]+$//;
    if (exists $valid_keys{$key_stem}) {
      CASE: {
        if ($key_stem eq "loop")   { check_loop ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key_stem eq "type")   { check_type ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        }
      }
      
    }

  }

sub GlobalLoop::set_variables {

  # Sets global variables defined in section GlobalLoop
  
  # External variables
  my ($input, $loop, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # loop: array of hashes describing the fields loop
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  if ($verbose) {
    print "\nLoop variables:\n";
    }

  my %numbers = ();
  foreach (sort keys %$input) {
    if (/^globalloop-loop/) {
      my $n = $_;
      $n =~ s/globalloop-loop//;
      $n =~ s/-.*//;
      $numbers{$n} = 1;
      }
    }

  foreach (sort keys %numbers) {

    my $key = "globalloop-loop" . $_ . "-";
    if ((exists $$input{$key."section"})&&(exists $$input{$key."key"})&&(exists $$input{$key."subkey"})&&(exists $$input{$key."value"})) {
      my $loop_key = $$input{$key."section"} . "-" . $$input{$key."key"} . "-" . $$input{$key."subkey"};
      my $loop_value = $$input{$key."value"};
      my @loop_list = ();
      if ($loop_value =~ /^linear/) {
        $loop_value =~ s/^linear //;
        my @words = split (/ /, $loop_value);
	my ($start, $end, $step);
	if (($words[0] =~ /^\-*[0-9]*\.*[0-9]*$/)&&($words[0] =~ /[0-9]+/)) {
	  $start = $words[0];
	  }
	else {
	  $$errflag = 1;
	  $$errstr .= "Syntax error in first argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	if (($words[1] =~ /^\-*[0-9]*\.*[0-9]*$/)&&($words[1] =~ /[0-9]+/)) {
	  $end = $words[1];
	  }
	else {
	  $$errflag = 1;
	  $$errstr .= "Syntax error in second argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	if (($words[2] =~ /^\-*[0-9]*\.*[0-9]*$/)&&($words[2] =~ /[0-9]+/)) {
	  $step = $words[2];
	  }
	else {
	  $$errflag = 1;
	  $$errstr .= "Syntax error in third argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	if (($end<$start)||($step<=0)) {
	  $$errflag = 1;
	  $$errstr .= "Wrong start, end or step value in argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	for (my $v=$start; $v<=$end; $v+=$step) {
	  push @loop_list, $v;
	  }
	if ($loop_list[$#loop_list] != $end) {
	  push @loop_list, $end;
	  }
        }
      elsif ($loop_value =~ /^logarithmic/) {
       $loop_value =~ s/^logarithmic //;
        my @words = split (/ /, $loop_value);
	my ($start, $end, $multiplier);
	if (($words[0] =~ /^[0-9]*\.*[0-9]*$/)&&($words[0] =~ /[0-9]+/)) {
	  $start = $words[0];
	  }
	else {
	  $$errflag = 1;
	  $$errstr .= "Syntax error in first argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	if (($words[1] =~ /^[0-9]*\.*[0-9]*$/)&&($words[1] =~ /[0-9]+/)) {
	  $end = $words[1];
	  }
	else {
	  $$errflag = 1;
	  $$errstr .= "Syntax error in second argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	if (($words[2] =~ /^[0-9]*\.*[0-9]*$/)&&($words[2] =~ /[0-9]+/)) {
	  $multiplier = $words[2];
	  }
	else {
	  $$errflag = 1;
	  $$errstr .= "Syntax error in third argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	if (($start==1)||($end<$start)||($multiplier<=1)) {
	  $$errflag = 1;
	  $$errstr .= "Wrong start, end or multiplier value in argument of subkey 'value' at key 'loop$_' in section 'globalloop'.\n";
	  return -1;
	  }
	my $v=$start;
	while ($v<$end) {
	  push @loop_list, $v;
	  $v *= $multiplier;
	  }
	if ($loop_list[$#loop_list] != $end) {
	  push @loop_list, $end;
	  }
        }
      elsif ($loop_value =~ /^list/) {
        $loop_value =~ s/^list //;
	my @words = split (/,/, $loop_value);
	foreach (@words) {
	  s/^\s+//;
	  s/\s+$//;
	  push @loop_list, $_;
	  }
        }
      else {
	$$errflag = 1;
	$$errstr .= "Subkey 'value' needs assignment starting with 'linear', 'logarithmic' or 'list' at key 'loop$_' in section 'globalloop'.\n";
	return -1;
        }
      $$loop{$loop_key} = \@loop_list;
      if ($verbose) {
        my $line = "$loop_key: ";
	foreach (@loop_list) {
	  $line .= sprintf "%s, ", $_;
	  }
        $line =~ s/, $//;
	print "$line\n";
	}
      }
    else {
      $$errflag = 1;
      $$errstr .= "Subkeys 'section', 'key', 'subkey' and 'value' need to be defined for key 'loop$_' in section 'globalloop'.\n";
      return -1;
      }
    
    }
    
  }
