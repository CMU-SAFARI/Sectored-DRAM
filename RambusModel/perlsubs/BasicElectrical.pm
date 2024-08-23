#!/usr/local/bin/perl

package perlsubs::BasicElectrical;

# This package performs all operations specific to the section specification

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
  voltages => 1,
  efficiency => 1,
  );

sub check_voltages {

  # performs syntax check of key voltages

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    vcc => 1,
    vperi => 1,
    varray => 1,
    vpp => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  if (($subkey eq "vcc")||($subkey eq "vperi")||($subkey eq "varray")||($subkey eq "vpp")) {
    $value =~ s/v$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }

  }
  
sub check_efficiency {

  # performs syntax check of key efficiency

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    vperi => 1,
    varray => 1,
    vpp => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  if (($subkey eq "vcc")||($subkey eq "vperi")||($subkey eq "varray")||($subkey eq "vpp")) {
    $value =~ s/%$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }

  }
  
sub BasicElectrical::check_syntax {

  # Performs syntax checking in section BasicElectrical
  
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
    if (!(exists $valid_keys{$_})) {
      $$errflag = 1;
      $$errstr .= "'" . $_ . "' is not a valid key in section 'specification'.\n";
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
        if ($key eq "voltages")   { check_voltages   ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "efficiency") { check_efficiency ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        }
      }
      
    }
  
  }

sub BasicElectrical::set_voltages {

  # Sets voltages and generator / pump efficiency in section BasicElectrical
  
  # External variables
  my ($input, $vcc, $vperi, $vperi_eff, $varray,
  $varray_eff, $vpp, $vpp_eff, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # vcc, vperi, varray, vpp: voltages (supply, periphery logic, bitline, wordline
  # v<voltage>_eff: generator respectively pump efficiency of internal voltages
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Vcc
  if (exists $$input{"basicelectrical-voltages-vcc"}) {
    $$vcc = $$input{"basicelectrical-voltages-vcc"};
    $$vcc =~ s/v$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'vcc' needs to be defined in key 'voltages' section 'basicelectrical'.\n";
    }
  
  # Vperi
  if (exists $$input{"basicelectrical-voltages-vperi"}) {
    $$vperi = $$input{"basicelectrical-voltages-vperi"};
    $$vperi =~ s/v$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'vperi' needs to be defined in key 'voltages' section 'basicelectrical'.\n";
    }
  
  # Varray
  if (exists $$input{"basicelectrical-voltages-varray"}) {
    $$varray = $$input{"basicelectrical-voltages-varray"};
    $$varray =~ s/v$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'varray' needs to be defined in key 'voltages' section 'basicelectrical'.\n";
    }
  
   # Vpp
  if (exists $$input{"basicelectrical-voltages-vpp"}) {
    $$vpp = $$input{"basicelectrical-voltages-vpp"};
    $$vpp =~ s/v$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'vpp' needs to be defined in key 'voltages' section 'basicelectrical'.\n";
    }
  
  # Vperi efficiency
  if (exists $$input{"basicelectrical-efficiency-vperi"}) {
    $$vperi_eff = $$input{"basicelectrical-efficiency-vperi"};
    $$vperi_eff =~ s/%$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'vperi' needs to be defined in key 'efficiency' section 'basicelectrical'.\n";
    }
  
  # Varray efficiency
  if (exists $$input{"basicelectrical-efficiency-varray"}) {
    $$varray_eff = $$input{"basicelectrical-efficiency-varray"};
    $$varray_eff =~ s/%$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'varray' needs to be defined in key 'efficiency' section 'basicelectrical'.\n";
    }
  
   # Vpp efficiency
  if (exists $$input{"basicelectrical-efficiency-vpp"}) {
    $$vpp_eff = $$input{"basicelectrical-efficiency-vpp"};
    $$vpp_eff =~ s/%$//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'vpp' needs to be defined in key 'efficiency' section 'basicelectrical'.\n";
    }

  if ($$errflag) { return -1; }
  
  if ($verbose) {
    print "\nVoltages:\n";
    printf "Vcc = %.2fV\n", $$vcc;
    printf "Vperi = %.2fV, generator efficiency = %.0f%%\n", $$vperi, $$vperi_eff;
    printf "Varray = %.2fV, generator efficiency = %.0f%%\n", $$varray, $$varray_eff;
    printf "Vpp = %.2fV, generator efficiency = %.0f%%\n", $$vpp, $$vpp_eff;
    }
 
  }

# Return 1 at end of package file
1;
