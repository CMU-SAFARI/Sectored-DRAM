#!/usr/local/bin/perl

package perlsubs::Power;

# This package contains all subroutines necessary to calculate and output power

# End User License Agreement for Software:
# 
# Copyright � 2010 Rambus Inc.  All Rights Reserved.
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
# "XDR�" and "Rambus" are trademarks or registered trademarks of Rambus Inc.
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
my %components = (
  row => 1,
  column => 1,
  senseamp => 1,
  data => 1,
  control => 1,
  clock => 1,
  baseload => 1,
  );
my %locations = (
  core => 1,
  periphery  => 1,
  );
my %operations = (
  activate => 1,
  precharge => 1,
  read => 1,
  write  => 1,
  nop => 1,
  );
my %types = (
  device => 1,
  wire  => 1,
  );
my %voltages = (
  vcc => 1,
  vperi => 1,
  varray => 1,
  vpp  => 1,
  );

sub check_current {

  # Checks that all keys of the array current are valid
  
  # External variables
  my ($current, $errflag, $errstr, $verbose) = @_;
  # current: reference to hash containing the currents of all contributors to power
  #   the hash key is <component>-<location>-<operation>-<type>-<voltage>
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  foreach (sort keys %$current) {
    my @words = split (/-/, $_);
    my $flag = 0;
    if ($#words != 4) {
      $flag = 1;
      }
    else {
      if (!(exists $components{$words[0]})) { $flag = 1; }
      if (!(exists $locations{$words[1]})) { $flag = 1; }
      if (!(exists $operations{$words[2]})) { $flag = 1; }
      if (!(exists $types{$words[3]})) { $flag = 1; }
      if (!(exists $voltages{$words[4]})) { $flag = 1; }
      }
    if ($flag) {
      $$errflag = 1;
      $$errstr .= "Key $_ in hash %current is not correct, error in program.\n";
      }
    }
  
  }

sub output_pattern_idd_power {

  # Calculates current and power for the given pattern
  # NOTE: The hash %current is modified by this subroutine to correspond exactly to the used pattern,
  # also the generator / pump efficiencies are included in each value
  
  # External variables
  my ($input, $current, $vcc, $vperi, $varray, $vpp, $vperi_eff, $varray_eff, $vpp_eff, $row_period, $core_frequency,
    $opshare_act, $opshare_pre, $opshare_rd, $opshare_wrt, $coldat_opshare, $pa_factor, $idd, $power, $errflag, $errstr, $verbose, $verbose_power, $loop_flag) = @_;
  # input: reference to hash with keys and values
  # current: reference to hash containing the currents of all contributors to power
  #   the hash key is <component>-<location>-<operation>-<type>-<voltage>
  # vcc, vperi, varray, vpp: voltages (supply, periphery logic, bitline, wordline
  # v<voltage>_eff: generator respectively pump efficiency of internal voltages
  # row_period: row operation period (one activate and one precharge in that time)
  # core_frequency: core frequency used to calculate read and write current in sense-amp
  # opshare_act: share of activate operation of total current calculated from pattern
  # opshare_pre: share of precharge operation of total current calculated from pattern
  # opshare_rd: share of read operation of total current calculated from pattern
  # opshare_wrt: share of write operation of total current calculated from pattern
  # coldat_opshare: multiplier to account for full burst length on column and data path
  # idd and power: references to return the value of current and power
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  # loop_flag: flag for program running in loop

  # Variables
  my ($j, $key);

  # Normalize currents calculated with row period to control frequency
  my $control_frequency = $$input{"specification-control-frequency"};
  $control_frequency =~ s/mhz//;
  my $row_frequency = 1000 / $row_period;
  $$current{"row-core-activate-device-vperi"} *= $control_frequency / $row_frequency;
  $$current{"row-core-activate-wire-vperi"} *= $control_frequency / $row_frequency;
  $$current{"row-core-activate-device-vpp"} *= $control_frequency / $row_frequency;
  $$current{"row-core-activate-wire-vpp"} *= $control_frequency / $row_frequency;
  $$current{"row-core-precharge-device-vperi"} *= $control_frequency / $row_frequency;
  $$current{"row-core-precharge-wire-vperi"} *= $control_frequency / $row_frequency;
  $$current{"row-core-precharge-device-vpp"} *= $control_frequency / $row_frequency;
  $$current{"row-core-precharge-wire-vpp"} *= $control_frequency / $row_frequency;
  $$current{"row-periphery-activate-device-vperi"} *= $control_frequency / $row_frequency;
  $$current{"row-periphery-activate-wire-vperi"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-activate-device-varray"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-precharge-device-varray"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-activate-device-vperi"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-precharge-device-vperi"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-activate-device-vpp"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-precharge-device-vpp"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-activate-wire-vperi"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-precharge-wire-vperi"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-activate-wire-vpp"} *= $control_frequency / $row_frequency;
  $$current{"senseamp-core-precharge-wire-vpp"} *= $control_frequency / $row_frequency;

  # Normalize currents calculated with core frequency to control frequency
  $$current{"senseamp-core-read-device-varray"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-write-device-varray"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-read-device-vperi"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-write-device-vperi"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-read-device-vpp"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-write-device-vpp"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-read-wire-vperi"} *= $control_frequency / $core_frequency;
  $$current{"senseamp-core-write-wire-vperi"} *= $control_frequency / $core_frequency;
  
  # Normalize currents with operational shares
  my $opshare_nop = 1 - $opshare_act - $opshare_pre - $opshare_rd - $opshare_wrt;
  if ($opshare_nop < 0) {
    $opshare_nop = 0;
    }
  my $factor;
  foreach (sort keys %components) {
    my $c = $_;
    foreach (sort keys %locations) {
      my $l = $_;
      foreach (sort keys %types) {
        my $t = $_;
	foreach (sort keys %voltages) {
          $key = $c . "-" . $l . "-activate-" . $t . "-" . $_;
	  if (exists $$current{$key}) { $$current{$key} *= $opshare_act; }
          $key = $c . "-" . $l . "-precharge-" .$t . "-" . $_;
	  if (exists $$current{$key}) { $$current{$key} *= $opshare_pre; }
          $key = $c . "-" . $l . "-write-" .$t . "-" . $_;
          $factor = $opshare_wrt;
	  if (($c eq "column")||($c eq "data")) {
	    $factor *= $coldat_opshare * $pa_factor;
	    #if ($factor > 1) { $factor = 1; }
	    }
	  if (exists $$current{$key}) { $$current{$key} *= $factor; }
          $key = $c . "-" . $l . "-read-" .$t . "-" . $_;
          $factor = $opshare_rd;
	  if (($c eq "column")||($c eq "data")) {
	    $factor *= $coldat_opshare * $pa_factor;
	    #if ($factor > 1) { $factor = 1; }
	    }
	  if (exists $$current{$key}) { $$current{$key} *= $factor; }
          $key = $c . "-" . $l . "-nop-" .$t . "-" . $_;
	  if (exists $$current{$key}) { $$current{$key} *= $opshare_nop; }
	  }
	}
      }
    }
  
  # Normalize current with generator / pump efficiencies
  foreach my $c (sort keys %components) {
    foreach my $l (sort keys %locations) {
      foreach my $t (sort keys %types) {
	foreach my $o (sort keys %operations) {
	  $key = $c . "-" . $l . "-" . $o . "-" . $t . "-";
	  if (exists $$current{$key."vperi"})  { $$current{$key."vperi"} *= 100 / $vperi_eff; }
	  if (exists $$current{$key."varray"}) { $$current{$key."varray"} *= 100 / $varray_eff; }
	  if (exists $$current{$key."vpp"})    { $$current{$key."vpp"} *= 100 / $vpp_eff; }
	  }
	}
      }
    }

  # Activate
  my $j_activate = 0;
  foreach (sort keys %components) {
    my $c = $_;
    foreach (sort keys %locations) {
      $key = $c . "-" . $_ . "-activate-";
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vcc"})) { $j += $$current{$key.$_."-vcc"}; } }
      $j_activate += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vperi"})) { $j += $$current{$key.$_."-vperi"}; } }
      $j_activate += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-varray"})) { $j += $$current{$key.$_."-varray"}; } }
      $j_activate += $j;
      $j = 0; foreach (sort keys %types) { if (exists ( $$current{$key.$_."-vpp"})) { $j += $$current{$key.$_."-vpp"}; } }
      $j_activate += $j;
      }
    }

  # Precharge
  my $j_precharge = 0;
  foreach (sort keys %components) {
    my $c = $_;
    foreach (sort keys %locations) {
      $key = $c . "-" . $_ . "-precharge-";
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vcc"})) { $j += $$current{$key.$_."-vcc"}; } }
      $j_precharge += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vperi"})) { $j += $$current{$key.$_."-vperi"}; } }
      $j_precharge += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-varray"})) { $j += $$current{$key.$_."-varray"}; } }
      $j_precharge += $j;
      $j = 0; foreach (sort keys %types) { if (exists ( $$current{$key.$_."-vpp"})) { $j += $$current{$key.$_."-vpp"}; } }
      $j_precharge += $j;
      }
    }

  # Write
  my $j_write = 0;
  foreach (sort keys %components) {
    my $c = $_;
    foreach (sort keys %locations) {
      $key = $c . "-" . $_ . "-write-";
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vcc"})) { $j += $$current{$key.$_."-vcc"}; } }
      $j_write += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vperi"})) { $j += $$current{$key.$_."-vperi"}; } }
      $j_write += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-varray"})) { $j += $$current{$key.$_."-varray"}; } }
      $j_write += $j;
      $j = 0; foreach (sort keys %types) { if (exists ( $$current{$key.$_."-vpp"})) { $j += $$current{$key.$_."-vpp"}; } }
      $j_write += $j;
      }
    }

  # Read
  my $j_read = 0;
  foreach (sort keys %components) {
    my $c = $_;
    foreach (sort keys %locations) {
      $key = $c . "-" . $_ . "-read-";
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vcc"})) { $j += $$current{$key.$_."-vcc"}; } }
      $j_read += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vperi"})) { $j += $$current{$key.$_."-vperi"}; } }
      $j_read += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-varray"})) { $j += $$current{$key.$_."-varray"}; } }
      $j_read += $j;
      $j = 0; foreach (sort keys %types) { if (exists ( $$current{$key.$_."-vpp"})) { $j += $$current{$key.$_."-vpp"}; } }
      $j_read += $j;
      }
    }

  # NOP
  my $j_nop = 0;
  foreach (sort keys %components) {
    my $c = $_;
    foreach (sort keys %locations) {
      $key = $c . "-" . $_ . "-nop-";
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vcc"})) { $j += $$current{$key.$_."-vcc"}; } }
      $j_nop += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-vperi"})) { $j += $$current{$key.$_."-vperi"}; } }
      $j_nop += $j;
      $j = 0; foreach (sort keys %types) { if (exists ($$current{$key.$_."-varray"})) { $j += $$current{$key.$_."-varray"}; } }
      $j_nop += $j;
      $j = 0; foreach (sort keys %types) { if (exists ( $$current{$key.$_."-vpp"})) { $j += $$current{$key.$_."-vpp"}; } }
      $j_nop += $j;
      }
    }

  # Set output variables
  $$idd = $j_activate + $j_precharge + $j_write + $j_read + $j_nop;
  $$power = $$idd * $vcc;
 
  if (!$loop_flag||$verbose||$verbose_power) {
    my ($j_act_full, $j_pre_full, $j_wrt_full, $j_rd_full, $j_nop_full);
    if ($opshare_act > 0) {
      $j_act_full = $j_activate / $opshare_act;
      }
    else {
      $j_act_full = 0;
      }
    if ($opshare_pre > 0) {
      $j_pre_full = $j_precharge / $opshare_pre;
      }
    else {
      $j_pre_full = 0;
      }
    if ($opshare_wrt > 0) {
      $j_wrt_full = $j_write / $opshare_wrt;
      }
    else {
      $j_wrt_full = 0;
      }
    if ($opshare_rd > 0) {
      $j_rd_full =  $j_read / $opshare_rd;
      }
    else {
      $j_rd_full = 0;
      }
    if ($opshare_nop > 0) {
      $j_nop_full = $j_nop / $opshare_nop;
      }
    else {
      $j_nop_full = 0;
      }
    print "\nPattern current and power:\n";
    if ($coldat_opshare > 1) {
      printf "Burst length is %s clock cycles, used as multiplier for internal share of column and data operation in read and write.\n", $coldat_opshare;
      }
    printf "Activate current:  %7.1fmA (%3.0f%% of %7.1fmA )\n", $j_activate, $opshare_act * 100, $j_act_full;
    printf "Precharge current: %7.1fmA (%3.0f%% of %7.1fmA )\n", $j_precharge, $opshare_pre * 100, $j_pre_full;
    printf "Write current:     %7.1fmA (%3.0f%% of %7.1fmA )\n", $j_write, $opshare_wrt * 100, $j_wrt_full;
    printf "Read current:      %7.1fmA (%3.0f%% of %7.1fmA )\n", $j_read, $opshare_rd * 100, $j_rd_full;
    printf "NOP current:       %7.1fmA (%3.0f%% of %7.1fmA )\n", $j_nop, $opshare_nop * 100, $j_nop_full;
    printf "Total current:     %7.1fmA\n", $$idd;
    printf "Power:             %7.1fmW\n", $$power
    }
  if ($loop_flag) {
    printf "Power: %7.1fmW (row period %.2fns)\n", $$power, $row_period;
    }
  
  }

sub Power::power {
  
  # External variables
  my ($input, $current, $vcc, $vperi, $varray, $vpp, $vperi_eff, $varray_eff, $vpp_eff, $row_period, $core_frequency,
    $opshare_act, $opshare_pre, $opshare_rd, $opshare_wrt, $coldat_opshare, $pa_factor, $idd, $power, $errflag, $errstr, $verbose, $loop_flag) = @_;
  # input: reference to hash with keys and values
  # current: reference to hash containing the currents of all contributors to power
  #   the hash key is <component>-<location>-<operation>-<type>-<voltage>
  # vcc, vperi, varray, vpp: voltages (supply, periphery logic, bitline, wordline
  # v<voltage>_eff: generator respectively pump efficiency of internal voltages
  # row_period: row operation period (one activate and one precharge in that time)
  # core_frequency: core frequency used to calculate read and write current in sense-amp
  # opshare_act: share of activate operation of total current calculated from pattern
  # opshare_pre: share of precharge operation of total current calculated from pattern
  # opshare_rd: share of read operation of total current calculated from pattern
  # opshare_wrt: share of write operation of total current calculated from pattern
  # coldat_opshare: multiplier to account for full burst length on column and data path
  # idd and power: references to return the values of current and power
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  # loop_flag: flag for program running in loop

  # Check hash
  check_current ($current, $errflag, $errstr, $verbose);
  
  # Calculate current and power of the used pattern
  output_pattern_idd_power ($input, $current, $vcc, $vperi, $varray, $vpp, $vperi_eff, $varray_eff, $vpp_eff, $row_period, $core_frequency,
    $opshare_act, $opshare_pre, $opshare_rd, $opshare_wrt, $coldat_opshare, $pa_factor, $idd, $power, $errflag, $errstr, $verbose, $loop_flag);
    
  }

sub Power::output_power_to_excel {

  # Writes pattern power to an Excel readable text file. Requires subroutine output_pattern_idd_power
  # to be run before to have hash %current contain the correctly normalized values 
  
  # External variables
  my ($output_name, $description, $input, $current, $vcc, $power, $errflag, $errstr, $verbose, $loop_flag) = @_;
  # output_name: file into which output is written
  # description: header line to be printed to file (contains variation in case of loop)
  # input: reference to hash with keys and values
  # current: reference to hash containing the currents of all contributors to power
  #   the hash key is <component>-<location>-<operation>-<type>-<voltage>
  # vcc: supply voltage
  # power: reference to hash with calculated power values
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  # loop_flag: flag for program running in loop

  # Reset power hash
  %{$power} = ();

  # Open file for export to Excel
  if (!(open (OUTPUT, ">" . $output_name))) {
    $$errflag = 1;
    $$errstr .= "Output file $output_name to export power to Excel could not be opened.\n";
    return;
    }

  # Write pattern to file
  # print OUTPUT "Loop instance: $description\n";
  if (exists $$input{"specification-pattern-loop"}) {
    # print OUTPUT "Pattern: ";
    # printf OUTPUT "%s\n\n", $$input{"specification-pattern-loop"};
    }
  else {
    print "Excel power file is only created when pattern is defined in section specification.\n";
    return;
    }

  # Write detailed dresults to file
  # print OUTPUT "\nDetailed power analysis\n";
  printf OUTPUT "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", "component", "location", "operation", "type", "voltage", "key", "power";
  foreach my $c (sort keys %components) {
    foreach my $l (sort keys %locations) {
      foreach my $o (sort keys %operations) {
        foreach my $t (sort keys %types) {
	  foreach my $v (sort keys %voltages) {
	    my $key = $c . "-" . $l . "-" . $o . "-" . $t . "-" . $v;
	    if (exists $$current{$key}) {
	      if ($$current{$key}>0) {
	        printf OUTPUT "%s\t%s\t%s\t%s\t%s\t%s\t%7.1f\n", $c, $l, $o, $t, $v, $key, $$current{$key} * $vcc;
		if (exists $$power{$c}) { $$power{$c} += $$current{$key} * $vcc; } else { $$power{$c} = $$current{$key} * $vcc; }
		if (exists $$power{$l}) { $$power{$l} += $$current{$key} * $vcc; } else { $$power{$l} = $$current{$key} * $vcc; }
		if (exists $$power{$o}) { $$power{$o} += $$current{$key} * $vcc; } else { $$power{$o} = $$current{$key} * $vcc; }
		if (exists $$power{$t}) { $$power{$t} += $$current{$key} * $vcc; } else { $$power{$t} = $$current{$key} * $vcc; }
		if (exists $$power{$v}) { $$power{$v} += $$current{$key} * $vcc; } else { $$power{$v} = $$current{$key} * $vcc; }
		my $ol = $o . "-" . $l;
		my $ot = $o . "-" . $t;
		my $lv = $l . "-" . $v;
		if (exists $$power{$ol}) { $$power{$ol} += $$current{$key} * $vcc; } else { $$power{$ol} = $$current{$key} * $vcc; }
		if (exists $$power{$ot}) { $$power{$ot} += $$current{$key} * $vcc; } else { $$power{$ot} = $$current{$key} * $vcc; }
		if (exists $$power{$lv}) { $$power{$lv} += $$current{$key} * $vcc; } else { $$power{$lv} = $$current{$key} * $vcc; }
		my $og;
		if (($o eq "activate")||($o eq "precharge")) {
		  $og = "row";
		  }
		else {
		  $og = "column";
		  }
		my $ogtl = $og . "-" . $t . "-" . $l;
		if (exists $$power{$ogtl}) { $$power{$ogtl} += $$current{$key} * $vcc; } else { $$power{$ogtl} = $$current{$key} * $vcc; }
		}
	      else {
	        # printf OUTPUT "%s\t%s\t%s\t%s\t%s\t%s\t%7.1f\n", $c, $l, $o, $t, $v, $key, 0;
	        }
	      }
	    else {
              # printf OUTPUT "%s\t%s\t%s\t%s\t%s\t%s\t%7.1f\n", $c, $l, $o, $t, $v, $key, 0;
	      }
	    }
	  }
	}
      }
    }

=pod
  # Write power categorized by component
  print OUTPUT "\nPower by component\n";
  foreach my $c (sort keys %components) {
    if (exists $$power{$c}) { printf OUTPUT "%s\t%7.1f\n", $c, $$power{$c}; }
    }

  # Write power categorized by location
  print OUTPUT "\nPower by location\n";
  foreach my $l (sort keys %locations) {
    if (exists $$power{$l}) { printf OUTPUT "%s\t%7.1f\n", $l, $$power{$l}; }
    }

  # Write power categorized by operation
  print OUTPUT "\nPower by operation\n";
  foreach my $o (sort keys %operations) {
    if (exists $$power{$o}) { printf OUTPUT "%s\t%7.1f\n", $o, $$power{$o}; }
    }

  # Write power categorized by type
  print OUTPUT "\nPower by type\n";
  foreach my $t (sort keys %types) {
    if (exists $$power{$t}) { printf OUTPUT "%s\t%7.1f\n", $t, $$power{$t}; }
    }

  # Write power categorized by voltage
  print OUTPUT "\nPower by voltage\n";
  foreach my $v (sort keys %voltages) {
    if (exists $$power{$v}) { printf OUTPUT "%s\t%7.1f\n", $v, $$power{$v}; }
    }

  # Write power categorized by operation and location
  print OUTPUT "\nPower by operation and location\n";
  foreach my $o (sort keys %operations) {
    foreach my $l (sort keys %locations) {
      my $ol = $o . "-" . $l;
      if (exists $$power{$ol}) { printf OUTPUT "%s\t%7.1f\n", $ol, $$power{$ol}; }
      }
    }

  # Write power categorized by operation and type
  print OUTPUT "\nPower by operation and type\n";
  foreach my $o (sort keys %operations) {
    foreach my $t (sort keys %types) {
      my $ot = $o . "-" . $t;
      if (exists $$power{$ot}) { printf OUTPUT "%s\t%7.1f\n", $ot, $$power{$ot}; }
      }
    }

  # Write power categorized by location and voltage
  print OUTPUT "\nPower by location and voltage\n";
  foreach my $l (sort keys %locations) {
    foreach my $v (sort keys %voltages) {
      my $lv = $l . "-" . $v;
      if (exists $$power{$lv}) { printf OUTPUT "%s\t%7.1f\n", $lv, $$power{$lv}; }
      }
    }

  # Write power categorized by location and voltage
  if (!$loop_flag||$verbose) {
    print "\nPower by location and voltage\n";
    foreach my $l (sort keys %locations) {
      foreach my $v (sort keys %voltages) {
	my $lv = $l . "-" . $v;
	if (exists $$power{$lv}) { printf "%s\t%7.1f\n", $lv, $$power{$lv}; }
	}
      }
    }

  # Write power categorized by generalized operation, type and location
  print OUTPUT "\nPower by generalized operation, type and location\n";
  foreach my $og (("row", "column")) {
    foreach my $l (sort keys %locations) {
      foreach my $t (sort keys %types) {
	my $ogtl = $og . "-" . $t . "-" . $l;
	if (exists $$power{$ogtl}) { printf OUTPUT "%s\t%7.1f\n", $ogtl, $$power{$ogtl}; }
	}
      }
    }

  # Write power categorized by location
  if (!$loop_flag||$verbose) {
    print "\nPower by location\n";
    foreach my $l (sort keys %locations) {
      if (exists $$power{$l}) { printf "%-16s%7.1f\n", $l, $$power{$l}; }
      }
    }

  # Close output file
  close OUTPUT;
=cut
  }

sub Power::loop_header {

  # Writes header of file with power information collected for all variations created by loop statements
  
  # External variables
  my ($FH, $loop, $errflag, $errstr, $verbose) = @_;
  # FH: filehandle to output data to
  # Loop: hash with variations being looped through
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  my $line = "";
  foreach (sort keys %{$loop}) {
    $line .= sprintf "%s\t", $_;
    }
  $line .= sprintf "%s\t", "total";
  $line .= sprintf "%s\t", "row";
  $line .= sprintf "%s\t", "column";
  $line .= sprintf "%s\t", "nop";
  foreach my $l (sort keys %locations) {
    foreach my $v (sort keys %voltages) {
      my $lv = $l . "-" . $v;
      $line .= sprintf "%s\t", $lv;
      }
    }
  foreach (sort keys %components) {
    $line .= sprintf "%s\t", $_;
    }
  foreach (sort keys %locations) {
    $line .= sprintf "%s\t", $_;
    }
  foreach (sort keys %operations) {
    $line .= sprintf "%s\t", $_;
    }
  foreach (sort keys %types) {
    $line .= sprintf "%s\t", $_;
    }
  foreach (sort keys %voltages) {
    $line .= sprintf "%s\t", $_;
    }
  foreach my $o (sort keys %operations) {
    foreach my $l (sort keys %locations) {
      my $ol = $o . "-" . $l;
      $line .= sprintf "%s\t", $ol;
      }
    }
  foreach my $o (sort keys %operations) {
    foreach my $t (sort keys %types) {
      my $ot = $o . "-" . $t;
      $line .= sprintf "%s\t", $ot;
      }
    }
  $line =~ s/\t$//;
  $line .= "\n";
  print $FH $line;
  
  }

sub Power::loop_line {

  # Writes single line of results of file with power information collected for all variations created by loop statements
  
  # External variables
  my ($FH, $description, $power, $errflag, $errstr, $verbose) = @_;
  # FH: filehandle to output data to
  # description: reference to hash with parameters of this line
  # power: hash with power information
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  my $total = 0;
  foreach my $c (sort keys %components) {
    if (exists $$power{$c}) {
      $total += $$power{$c};
      }
    }
  my $p_row = 0;
  if (exists $$power{"activate"}) { $p_row += $$power{"activate"}; }
  if (exists $$power{"precharge"}) { $p_row += $$power{"precharge"}; }
  my $p_col = 0;
  if (exists $$power{"read"}) { $p_col += $$power{"read"}; }
  if (exists $$power{"write"}) { $p_col += $$power{"write"}; }
  my $p_nop = 0;
  if (exists $$power{"nop"}) { $p_nop += $$power{"nop"}; }
  my $line = "";
  foreach (sort keys %{$description}) {
    $line .= sprintf "%s\t", $$description{$_};
    }
  $line .= sprintf "%s\t", $total;
  $line .= sprintf "%s\t", $p_row;
  $line .= sprintf "%s\t", $p_col;
  $line .= sprintf "%s\t", $p_nop;
  foreach my $l (sort keys %locations) {
    foreach my $v (sort keys %voltages) {
      my $lv = $l . "-" . $v;
      if (exists $$power{$lv}) {
	$line .= sprintf "%s\t", $$power{$lv};
	}
      else {
	$line .= sprintf "%s\t", 0;
	}
      }
    }
  foreach my $c (sort keys %components) {
    if (exists $$power{$c}) {
      $line .= sprintf "%s\t", $$power{$c};
      }
    else {
      $line .= sprintf "%s\t", 0;
      }
    }
  foreach my $l (sort keys %locations) {
    if (exists $$power{$l}) {
      $line .= sprintf "%s\t", $$power{$l};
      }
    else {
      $line .= sprintf "%s\t", 0;
      }
    }
  foreach my $o (sort keys %operations) {
    if (exists $$power{$o}) {
      $line .= sprintf "%s\t", $$power{$o};
      }
    else {
      $line .= sprintf "%s\t", 0;
      }
    }
  foreach my $t (sort keys %types) {
    if (exists $$power{$t}) {
      $line .= sprintf "%s\t", $$power{$t};
      }
    else {
      $line .= sprintf "%s\t", 0;
      }
    }
  foreach my $v (sort keys %voltages) {
    if (exists $$power{$v}) {
      $line .= sprintf "%s\t", $$power{$v};
      }
    else {
      $line .= sprintf "%s\t", 0;
      }
    }
  foreach my $o (sort keys %operations) {
    foreach my $l (sort keys %locations) {
      my $ol = $o . "-" . $l;
      if (exists $$power{$ol}) {
	$line .= sprintf "%s\t", $$power{$ol};
	}
      else {
	$line .= sprintf "%s\t", 0;
	}
      }
    }
  foreach my $o (sort keys %operations) {
    foreach my $t (sort keys %types) {
      my $ot = $o . "-" . $t;
      if (exists $$power{$ot}) {
	$line .= sprintf "%s\t", $$power{$ot};
	}
      else {
	$line .= sprintf "%s\t", 0;
	}
      }
    }
  $line =~ s/\t$//;
  $line .= "\n";
  print $FH $line;
  
  }

# Return 1 at end of package file
1;
