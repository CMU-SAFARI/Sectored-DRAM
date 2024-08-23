#!/usr/local/bin/perl

package perlsubs::Periphery;

# This package performs all operations specific to the section periphery

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
  logic => 1,
  sink => 1,
  );

sub check_logic {

  # performs syntax check of key logic

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    toggle => 1,
    gates => 1,
    nchw => 1,
    pchw => 1,
    devicespergate => 1,
    areafactor => 1,
    wirefactor => 1,
    component => 1,
    operation => 1,
    swing => 1,
    p_eff => 1,
    );

  my %valid_operation = (
    all => 1,
    activate => 1,
    precharge => 1,
    read => 1,
    write => 1,
    readwrite => 1,
    row => 1,
    );

  my %valid_component = (
    row => 1,
    column => 1,
    data => 1,
    control => 1,
    clock => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'periphery'.\n";
    }

  # Check value
  if (($subkey eq "nchw")||($subkey eq "pchw")) {
    $value =~ s/um$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit um) for subkey '$subkey' of key" .
	" '$key' in section 'periphery'.\n";
      }
    }
  if (($subkey eq "toggle")||($subkey eq "areafactor")||($subkey eq "wirefactor")||($subkey eq "p_eff")) {
    $value =~ s/%$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit %) for subkey '$subkey' of key" .
	" '$key' in section 'periphery'.\n";
      }
    }
  if (($subkey eq "gates")||($subkey eq "devicespergate")) {
    if (!($value =~ /^[0-9]+$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive integer for subkey '$subkey' of key" .
	" '$key' in section 'periphery'.\n";
      }
    }
  if ($subkey eq "operation") {
    if (!(exists $valid_operation{$value})) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be 'all', 'activate', 'read', 'write', 'precharge',
        'readwrite' or 'row' for subkey '$subkey' of key '$key' in section 'periphery'.\n";
      }
    }
  if ($subkey eq "component") {
    if (!(exists $valid_component{$value})) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be 'row' 'column' 'data' 'control' " .
        "or 'clock' for subkey '$subkey' of key '$key' in section 'periphery'.\n";
      }
    }
  if ($subkey eq "swing") {
    $value =~ s/v$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit V) for subkey '$subkey' of key" .
	" '$key' in section 'periphery'.\n";
      }
    }

  }

sub check_sink {

  # performs syntax check of key logic

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
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'periphery'.\n";
    }

  # Check value
  if (($subkey eq "vcc")||($subkey eq "vperi")||($subkey eq "varray")||($subkey eq "vpp")) {
    $value =~ s/ma$//;
    if (!(($value =~ /^[0-9]*\.*[0-9]*$/)&&($value =~ /[0-9]/))) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit mA) for subkey '$subkey' of key" .
	" '$key' in section 'periphery'.\n";
      }
    }

  }

sub Periphery::check_syntax {

  # Performs syntax checking in section Periphery
  
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
    if (!(exists $valid_keys{$key_stem})||(!(/[0-9]+$/))) {
      $$errflag = 1;
      $$errstr .= "'" . $_ . "' is not a valid key in section 'periphery'.\n";
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
        if ($key_stem eq "logic")   { check_logic ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key_stem eq "sink")   { check_sink ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        }
      }
      
    }
  
  }

sub Periphery::set_variables {

  # Sets global variables defined in section Periphery
  
  # External variables
  my ($input, $periphery_logic, $periphery_sinks, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # periphery_logic: array of hasehse describing the fields logic
  # periphery_sinks: array of current values in sinks
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  if ($verbose) {
    print "\nPeriphery circuits:\n";
    }

  my %numbers = ();
  foreach (sort keys %$input) {
    if (/^periphery-logic/) {
      my $n = $_;
      $n =~ s/periphery-logic//;
      $n =~ s/-.*//;
      $numbers{$n} = 1;
      }
    }

  foreach (sort keys %numbers) {

    my $key = "periphery-logic" . $_ . "-";
    if ((exists $$input{$key."gates"})&&(exists $$input{$key."nchw"})&&(exists $$input{$key."pchw"})&&
      (exists $$input{$key."devicespergate"})&&(exists $$input{$key."areafactor"})&&(exists
      $$input{$key."wirefactor"})&&(exists $$input{$key."operation"})&&(exists $$input{$key."component"})) {
      my $gates = $$input{$key."gates"};
      my $nchw = $$input{$key."nchw"};
      $nchw =~ s/um//;
      my $pchw = $$input{$key."pchw"};
      $pchw =~ s/um//;
      my $devicespergate = $$input{$key."devicespergate"};
      my $areafactor = $$input{$key."areafactor"};
      $areafactor =~ s/%//;
      $areafactor = $areafactor / 100;
      my $wirefactor = $$input{$key."wirefactor"};
      $wirefactor =~ s/%//;
      $wirefactor = $wirefactor / 100;
      my $operation = $$input{$key."operation"};
      my $component = $$input{$key."component"};
      my $toggle = 1;
      if (exists $$input{$key."toggle"}) {
        $toggle = $$input{$key."toggle"};
	$toggle =~ s/%//;
	$toggle = $toggle / 100;
	}
      my $swing;
      if (exists $$input{$key."swing"}) {
        $swing = $$input{$key."swing"};
	$swing =~ s/V//;
	}
      my $p_eff;
      if (exists $$input{$key."p_eff"}) {
        $p_eff = $$input{$key."p_eff"};
	$p_eff =~ s/%//;
	}
      my $device_width = $gates * $devicespergate * ($nchw + $pchw) / 2;
      my $length = $$input{"technology-transistor_main-lmin"};
      $length =~ s/um//;
      my $area = $device_width * $length * 3 / $areafactor; # 3 for diffusion gate diffusion in transistor
      my $block_length = sqrt ($area);
      my $pitch = $length;
      my $local_wires = int ($block_length / $pitch);
      my $wire_length = $local_wires * $block_length * $wirefactor;
      my %logic = ();
      $logic{"device_width"} = $device_width;
      $logic{"wire_length"} = $wire_length;
      $logic{"operation"} = $operation;
      $logic{"component"} = $component;
      $logic{"toggle"} = $toggle;
      if (exists $$input{$key."swing"}) {
        $logic{"swing"} = $swing;
        }
      if (exists $$input{$key."p_eff"}) {
        $logic{"p_eff"} = $p_eff;
        }
      push @$periphery_logic, \%logic;
      }
    else {
      $$errflag = 1;
      $$errstr .= "Subkeys 'gates', 'nchw', 'pchw', 'devicespergate', 'areafactor', 'wirefactor',
        'operation' and 'component' need to be defined for key 'logic$_' in section 'periphery'.\n";
      return -1;
      }
    }
    
    if ($verbose) {
      foreach (@$periphery_logic) {
        printf "Logic: device width %.0fum wire length %.0fum operation %s component %s toggle %.0f%%\n",
	  $$_{"device_width"}, $$_{"wire_length"}, $$_{"operation"}, $$_{"component"}, $$_{"toggle"}*100;
	}
      }

  %numbers = ();
  foreach (sort keys %$input) {
    if (/^periphery-sink/) {
      my $n = $_;
      $n =~ s/periphery-sink//;
      $n =~ s/-.*//;
      $numbers{$n} = 1;
      }
    }

  foreach (sort keys %numbers) {

    my $key = "periphery-sink" . $_ . "-";
    my $current;
    my $voltage;
    if (exists $$input{$key."vcc"}) {
      $current = $$input{$key."vcc"};
      $current =~ s/ma//;
      $voltage = "vcc";
      }
    elsif (exists $$input{$key."vperi"}) {
      $current = $$input{$key."vperi"};
      $current =~ s/ma//;
      $voltage = "vperi";
      }
    elsif (exists $$input{$key."varray"}) {
      $current = $$input{$key."varray"};
      $current =~ s/ma//;
      $voltage = "varray";
      }
    elsif (exists $$input{$key."vpp"}) {
      $current = $$input{$key."vpp"};
      $current =~ s/ma//;
      $voltage = "vpp";
      }
    else {
      $$errflag = 1;
      $$errstr .= "One of subkeys 'vcc', 'vperi', 'varray' or 'vpp' needs to be defined " .
        "for key 'sink$_' in section 'periphery'.\n";
      return -1;
      }
    my %sink = ();
    $sink{"voltage"} = $voltage;
    $sink{"current"} = $current;
    push @$periphery_sinks, \%sink;
    }
    
    if ($verbose) {
      foreach (@$periphery_sinks) {
        printf "Sink: voltage %s current %.0fmA\n", $$_{"voltage"}, $$_{"current"};
	}
      }
    
    
  }
