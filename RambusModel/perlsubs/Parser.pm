#!/usr/local/bin/perl

package perlsubs::Parser;

# This package contains the parser subroutine which reads the textual
# description of the DRAM into a Perl hash.

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
# "XDRÅ" and "Rambus" are trademarks or registered trademarks of Rambus Inc.
# protected by the laws of the United States or other countries.  
# 
# For additional information, please contact:
# Rambus Inc.
# 1050 Enterprise Way, Suite 700
# Sunnyvale, CA 94089
# 408-462-8000

use strict;
use warnings;

sub Parser::parser {

  # Reads input file and creates hash with each hash pair having the format
  # corresponding to a Perl assignment
  # <section>-<key>-<subkey> => <value>
  # There is no syntax checking here except for two issues which would cause
  # this subroutine to fail. Full syntax checking has to happen with a 
  # different subroutine running through the hash

  # External variables
  my ($file, $input, $errflag, $errstr) = @_;
  # $file: filename containing DRAM description
  # $input: reference to hash for return of results
  # $errflag: set if error occurs
  # $errstr: verbal description of error

  # Open input file and read into variable @input;
  open (INPUT, $file) or die "$file could not be opened.\nScript aborted.\n\n";
  my @inputfile = <INPUT>;
  close INPUT;
  
  # Remove comments and line break characters, add spaces around equal signs,
  # make whitespace regular, change to lower case, remove leading whitespace
  foreach (@inputfile) {
    s/\#.*//;
    chomp;
    s/=/ = /g;
    s/\s+/ /g;
    $_ = lc;
    s/^\s+//;
    }
  
  # Remove empty lines
  my @description = ();
  foreach (@inputfile) {
    if (!(/^\s*$/)) {
      push (@description, $_);
      }
    }

  # Assemble continuation lines
  my @assembled = ();
  my $line = "";
  foreach (@description) {
    if (/\\\s*$/) {
      s/\\\s*$/ /;
      $line .= " ";
      $line .= $_;
      }
    else {
      if ($line ne "") {
        $line .= " " . $_;
        push (@assembled, $line);
	$line = "";
	}
      else {
        push (@assembled, $_);
	}
      }
    }
  if ($line ne "") {
    push (@assembled, $line);
    }

  # Remove comments and line break characters, add spaces around equal signs,
  # make whitespace regular, change to lower case, remove leading whitespace
  foreach (@assembled) {
    s/\#.*//;
    chomp;
    s/=/ = /g;
    s/\s+/ /g;
    $_ = lc;
    s/^\s+//;
    }
  

  # Read input file into hash
  my $section = "none";
  my $key;
  foreach (@assembled) {
    if (/=/) {

      # Line with equal sign contains key and subkey / value pairs
      
      # Read key and remove from line
      ($key, my $rest) = split (/ /, $_);
      s/$key //;

      # Splitting the rest needs to take into account that values can have spaces
      # Therefore first is split at the equal sign, subkeys are the word directly
      # before the equal sign, the remainder is a value
      my @subkeys = ();
      my @values = ();
      my @segments = split (/=/, $_);
      if ($#segments < 1) {
        $$errflag = 1;
	$$errstr = "Section $section key $key has no <subkey>=<value> pair.\n";
	return -1;
	}
      foreach (@segments) { s/^ //; s/ $//; }
      # First segment is only subkey
      push (@subkeys, $segments[0]);
      # Intermediate segments have value followed by subkey
      for (my $i=1;$i<$#segments;$i++) {
        my @words = split (/ /, $segments[$i]);
	push (@subkeys, $words[$#words]);
	pop @words;
	my $value="";
	foreach (@words) { $value .= $_; $value .= " "; }
	$value =~ s/ $//;
	push (@values, $value);
	}
      # Last segment is only value
      push (@values, $segments[$#segments]);
      # Check that subkey and value occur in pairs
      if ($#subkeys != $#values) {
        $$errflag = 1;
	$$errstr = "Section $section key $key has incomplete <subkey>=<value> pairs.\n";
	return -1;
	}
      for (my $i=0;$i<=$#subkeys;$i++) {
        my $fullkey = $section . "-" . $key . "-" . $subkeys[$i];
	$$input{$fullkey} = $values[$i];
	}
      
      }
    else {

      # Line without equal sign contains section name

      $section = $_;

      }
    }
  
  }

# Return 1 at end of package file
1;
