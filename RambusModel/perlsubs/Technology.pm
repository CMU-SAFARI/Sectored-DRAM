#!/usr/local/bin/perl

package perlsubs::Technology;

# This package performs all operations specific to the section technology

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
  oxide_main => 1,
  oxide_hv => 1,
  oxide_array => 1,
  transistor_main => 1,
  transistor_hv => 1,
  transistor_array => 1,
  array => 1,
  beol => 1,
  leakage => 1,
  );

sub check_oxide {

  # performs syntax check of key oxide_<x>

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    t => 1,
    c => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'technology'.\n";
    }

  # Check value
  if ($subkey eq "t") {
    $value =~ s/a//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }
  if ($subkey eq "c") {
    $value =~ s/ff\/um2//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  }

sub check_transistor {

  # performs syntax check of key transistor_<x>

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    lmin => 1,
    csd => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  if ($subkey eq "lmin") {
    $value =~ s/um//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }
  if ($subkey eq "csd") {
    $value =~ s/ff\/um//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  }

sub check_transistor_array {

  # performs syntax check of key transistor_array

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    l => 1,
    w => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  $value =~ s/um//;
  if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
    $$errflag = 1;
    $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
      " '$key' in section 'technology'.\n";
    }

  }

sub check_array {

  # performs syntax check of key array

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    cbl => 1,
    cshare_bl_swl => 1,
    cs => 1,
    mwlwirecap => 1,
    swlwirecap => 1,
    mwlpredecode => 1,
    mwldecnchw => 1,
    mwldecpchw=> 1,
    mwldectoggle =>1,
    wlctrlloadnchw => 1,
    wlctrlloadpchw => 1,
    swldrvnchw => 1,
    swldrvpchw => 1,
    swlrstnchw => 1,
    sanchw => 1,
    sanchl => 1,
    sapchw => 1,
    sapchl => 1,
    saeqlw => 1,
    saeqll => 1,
    sashrw => 1,
    sashrl => 1,
    sabsww => 1,
    sabswl => 1,
    sansetw => 1,
    sansetl => 1,
    sapsetw => 1,
    sapsetl => 1,
    coldecw => 1,
    coldecl => 1,
    bitspercsl => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'technology'.\n";
    }

  # Check values
  if (($subkey eq "mwlwirecap")||($subkey eq "swlwirecap")) {
    $value =~ s/pf\/mm//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit pF/mm) for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  if (($subkey eq "mwlpredecode")||($subkey eq "bitspercsl")) {
    if (!($value =~ /^[0-9]+$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a binary number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    elsif (int(log($value)/log(2)) != log($value)/log(2)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a binary number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  if (($subkey eq "cshare_bl_swl")||($subkey eq "mwlddectoggle")) {
    $value =~ s/%$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a percentage for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  if (($subkey eq "wlctrlloadnchw")||($subkey eq "wlctrlloadpchw")||($subkey eq "swldrvnchw")||
    ($subkey eq "swldrvpchw")||($subkey eq "mwldecnchw")||($subkey eq "mwldecpchw")||
    ($subkey=~/^sa/)) {
    $value =~ s/um//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit um) for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  }

sub check_beol {

  # performs syntax check of key beol

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    cperiwire => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  $value =~ s/pf\/mm//;
  if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
    $$errflag = 1;
    $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
      " '$key' in section 'technology'.\n";
    }

  }

sub check_leakage {

  # performs syntax check of key leakage

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    sd_main => 1,
    gate_main => 1,
    gidl_hv_nch => 1,
    gidl_hv_pch => 1,
    column_width => 1,
    mwldrvnchw => 1,
    bljunction => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  if (($subkey eq "sd_main")||($subkey eq "gidl_hv_nch")||($subkey eq "gidl_hv_pch")) {
    $value =~ s/na\/um//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }
  if ($subkey eq "gate_main") {
    $value =~ s/na\/um2//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }
  if (($subkey eq "column_width")||($subkey eq "mwldrvnchw")) {
    $value =~ s/um//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }
  if ($subkey eq "bljunction") {
    $value =~ s/fa\/cell//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'technology'.\n";
      }
    }

  }

sub Technology::check_syntax {

  # Performs syntax checking in section Technology
  
  # External variables
  my ($input, $errflag, $errstr) = @_;
  # input: reference to hash with keys and values
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %required_array = (
    mwlwirecap => 1,
    swlwirecap => 1,
    mwlpredecode => 1,
    mwldecnchw => 1,
    mwldecpchw => 1,
    mwldectoggle => 1,
    wlctrlloadnchw => 1,
    wlctrlloadpchw => 1,
    swldrvnchw => 1,
    swldrvpchw => 1,
    swlrstnchw => 1,
    cbl => 1,
    cs => 1,
    cshare_bl_swl => 1,
    sanchw => 1,
    sanchl => 1,
    sapchw => 1,
    sapchl => 1,
    saeqlw => 1,
    saeqll => 1,
    sabsww => 1,
    sabswl => 1,
    sansetw => 1,
    sansetl => 1,
    sapsetw => 1,
    sapsetl => 1,
    );
  
  # Create list of all used keys
  my %found_keys = ();
  foreach (sort keys %$input) {
    my @words = split (/-/, $_);
    $found_keys{$words[0]} = 1;
    }

  # Check if there are not valid keys
  foreach (sort keys %found_keys) {
    if (!(exists $valid_keys{$_})) {
      $$errflag = 1;
      $$errstr .= "'" . $_ . "' is not a valid key in section 'technology'.\n";
      }
    }
  
  # Check for each key if subkeys and values are correct
  foreach (sort keys %$input) {
  
    # Get key, subkey and value
    my ($key, $subkey) = split (/-/, $_);
    my $value = $$input{$_};
    
    # Check  key, subkey and value combination
    # Error handling for not valid keys has been done above
    if (exists $valid_keys{$key}) {
      CASE: {
        if ($key eq "oxide_main") { check_oxide ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "oxide_hv") { check_oxide ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "oxide_array") { check_oxide ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "transistor_main") { check_transistor ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "transistor_hv") { check_transistor ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "transistor_array") { check_transistor_array ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "array") { check_array ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "beol") { check_beol ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "leakage") { check_leakage ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        }
      }
      
    }

  # Check that all required technology-array subkeys are present
  foreach (sort keys %required_array) {
    my $fullkey = "array-" . $_;
    if (!(exists $$input{$fullkey})) {
      $$errflag = 1;
      $$errstr .= "'" . $_ . "' is required subkey of key 'array' in section 'technology'.\n";
      }
    }
  
  }
