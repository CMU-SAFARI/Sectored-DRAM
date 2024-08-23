#!/usr/local/bin/perl

package perlsubs::Current;

# This package contains all subroutines necessary to calculate the currents of the different contributors to total power

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
my @components = qw( row column senseamp data control clock baseload);
my @location = qw( core periphery );
my @operation = qw( activate precharge read write );
my @type = qw( device wire );
my @voltage = qw( vcc vperi varray vpp );

# Miscellaneous information
my ($mwl_length, $dx_length);
my ($min_logic_l, $min_hv_l);
my ($logic_c, $hv_c, $array_c);
my ($jctcap_logic, $jctcap_hv);
my $c_periwire;

sub initialize_power_variables {

  # External variables
  my ($current) = @_; 
  # current: reference to hash with with currents calculated for the different power components
  
  foreach (@components) {
    my $c = $_;
    foreach (@location) {
      my $l = $_;
      foreach (@operation) {
        my $o = $_;
	foreach (@type) {
	  my $t = $_;
	  foreach (@voltage) {
	    my $key = $c . "-" . $l . "-" . $o . "-" . $t . "-" . $_;
	    $$current{$key} = 0;
	    }
	  }
	}
      }
    }

  }

sub set_global_variables {

  # External variables
  my ($input, $n_subbanks, $n_subarray_par_bl, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # n_subbanks: number of sub banks in a bank
  # n_subarray_par_bl: number of subarrays parallel BL
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Get WL length in one subbank
  if ($$input{"floorplanphysical-cellarray-bl"} eq "h") {
    $mwl_length = $$input{"floorplanphysical-sizevertical-a1"};
    $dx_length = $$input{"floorplanphysical-sizehorizontal-a1"};
    if (exists $$input{"floorplanphysical-sizevertical-a2"}) {
      $$errflag = 1;
      $$errstr .= "Array blocks of different sizes not implemented ('FloorplanPhysical', 'SizeVertical', 'A2').\n";
      return -1;
      }
    }
  else {
    $mwl_length = $$input{"floorplanphysical-sizehorizontal-a1"};
    $dx_length = $$input{"floorplanphysical-sizevertical-a1"};
    if (exists $$input{"floorplanphysical-sizehorizontal-a2"}) {
      $$errflag = 1;
      $$errstr .= "Array blocks of different sizes not implemented ('FloorplanPhysical', 'SizeHorizontal', 'A2').\n";
      return -1;
      }
    }
  # Calculate total master wordline length
  $mwl_length *= $n_subbanks;
  # Calculate dx and wlrst length (running from one SA stripe to the next)
  $dx_length = $dx_length / $n_subarray_par_bl;
  
  # There is no existence check for 'technology-array' subkeys as this is done at the end of the technology syntax checker
  
  # Set device length variables
  if (exists $$input{"technology-transistor_main-lmin"}) {
    $min_logic_l = $$input{"technology-transistor_main-lmin"};
    $min_logic_l =~ s/um//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'lmin' is required subkey of key 'transistor_main' in section 'technology'.\n";
    }
  if (exists $$input{"technology-transistor_hv-lmin"}) {
    $min_hv_l = $$input{"technology-transistor_hv-lmin"};
    $min_hv_l =~ s/um//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "'lmin' is required subkey of key 'transistor_hv' in section 'technology'.\n";
    }
  # Specific capacitance of transistors
  if (exists $$input{"technology-oxide_main-t"}) {
    if (exists $$input{"technology-oxide_main-c"}) {
      $$errflag = 1;
      $$errstr .= "'Only one of subkeys 't' or 'c' of key 'oxide_main' in section 'technology' should be defined.\n";
      return -1;
      }
    else {
      $logic_c = $$input{"technology-oxide_main-t"};
      $logic_c =~ s/a//;
      $logic_c = 3.9 * 88.54 / $logic_c;
      }
    }
  else {
    if (exists $$input{"technology-oxide_main-c"}) {
      $logic_c = $$input{"technology-oxide_main-t"};
      $logic_c =~ s/ff\um2//;
      }
    else {
      $$errflag = 1;
      $$errstr .= "'One of subkeys 't' or 'c' of key 'oxide_main' in section 'technology' needs to be defined.\n";
      return -1;
      }
    }
  if (exists $$input{"technology-oxide_hv-t"}) {
    if (exists $$input{"technology-oxide_hv-c"}) {
      $$errflag = 1;
      $$errstr .= "'Only one of subkeys 't' or 'c' of key 'oxide_hv' in section 'technology' should be defined.\n";
      return -1;
      }
    else {
      $hv_c = $$input{"technology-oxide_hv-t"};
      $hv_c =~ s/a//;
      $hv_c = 3.9 * 88.54 / $hv_c;
      }
    }
  else {
    if (exists $$input{"technology-oxide_hv-c"}) {
      $hv_c = $$input{"technology-oxide_hv-t"};
      $hv_c =~ s/ff\um2//;
      }
    else {
      $$errflag = 1;
      $$errstr .= "'One of subkeys 't' or 'c' of key 'oxide_hv' in section 'technology' needs to be defined.\n";
      return -1;
      }
    }
  if (exists $$input{"technology-oxide_array-t"}) {
    if (exists $$input{"technology-oxide_array-c"}) {
      $$errflag = 1;
      $$errstr .= "'Only one of subkeys 't' or 'c' of key 'oxide_array' in section 'technology' should be defined.\n";
      return -1;
      }
    else {
      $array_c = $$input{"technology-oxide_array-t"};
      $array_c =~ s/a//;
      $array_c = 3.9 * 88.54 / $array_c;
      }
    }
  else {
    if (exists $$input{"technology-oxide_array-c"}) {
      $array_c = $$input{"technology-oxide_array-t"};
      $array_c =~ s/ff\um2//;
      }
    else {
      $$errflag = 1;
      $$errstr .= "'One of subkeys 't' or 'c' of key 'oxide_array' in section 'technology' needs to be defined.\n";
      return -1;
      }
    }

  # Set specific junction capacitance
  $jctcap_logic = 0;
  if (exists $$input{"technology-transistor_main-csd"}) {
    $jctcap_logic = $$input{"technology-transistor_main-csd"};
    $jctcap_logic =~ s/ff\/um//;
    }
  elsif ($verbose) {
    print "INFO: Subkey 'csd' of key 'transistor_main' in section technology not defined, assumed to be 0.\n";
    }
  $jctcap_hv = 0;
  if (exists $$input{"technology-transistor_hv-csd"}) {
    $jctcap_hv = $$input{"technology-transistor_hv-csd"};
    $jctcap_hv =~ s/ff\/um//;
    }
  elsif ($verbose) {
    print "INFO: Subkey 'csd' of key 'transistor_hv' in section technology not defined, assumed to be 0.\n";
    }

  }

sub current_row {

  # External variables
  my ($input, $n_subbanks, $rowadd, $pagesize, $numberSWLstripes, $n_subarray_par_bl, $row_period, $pa_factor, $vperi, $vpp, 
    $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # n_subbanks: number of sub banks in a bank
  # rowadd: reference to array describing row address path segments length, width, frequency, buffers, toggle and swing
  # pagesize: number of bits
  # numberSWLstripes: total number of sub-WL driver stripes
  # n_subarray_par_bl: number of subarrays parallel BL
  # row_period: time period in which exactly one activate / precharge pair occurs in pattern
  # pa_factor: partial activation factor, how many MATs do we activate
  #             expressed in decimals (e.g., 0.25 --> ACT 1/4th of the MATs)
  # vperi: peripheral logic voltage
  # vpp: worldine voltage
  # current: reference to has with external power calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Constants
  my $n_swl_mwl = 4; # sub WLs per MWL

  # Variables
  my ($mwl_wire_cap, $dx_wire_cap, $swl_wire_cap);
  my ($swlctrl_nch_w, $swlctrl_pch_w);
  my ($swldrv_nch_w, $swldrv_pch_w, $swlrst_nch_w);
  my ($device_current, $wire_current);
  
  # Calculate array device capacitance
  if ((exists $$input{"technology-transistor_array-l"})&&(exists $$input{"technology-transistor_array-w"})) {
    my ($l, $w) = ($$input{"technology-transistor_array-l"}, $$input{"technology-transistor_array-w"});
    $l =~ s/um//;
    $w =~ s/um//;
    $array_c *= $l * $w;
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'l' and / or 'w' of key 'transistor_array' in section 'technology' are missing.\n";
    return -1;
    }

  # Calculate remaining parasitics of cell to WL capactitance as share of BL capacitance
  my ($cbl, $cshare) = ($$input{"technology-array-cbl"}, $$input{"technology-array-cshare_bl_swl"});
  $cbl =~ s/ff//;
  $cshare =~ s/%//;
  $cshare = $cshare / 100;
  my $c_swl_cell = $cbl * $cshare / $$input{"floorplanphysical-cellarray-bitsperbl"};

  # Calculate master wordline wire capacitance
  $mwl_wire_cap = $$input{"technology-array-mwlwirecap"};
  $mwl_wire_cap =~ s/pf\/mm//;
  $mwl_wire_cap *= $mwl_length;
  
  # Calculate wlrst and dx wire capacitance
  $dx_wire_cap = $$input{"technology-array-mwlwirecap"};
  $dx_wire_cap =~ s/pf\/mm//;
  $dx_wire_cap *= $dx_length;
  # There is one switching dx and one switching wlrst in every second SWL driver stripe
  $dx_wire_cap *= $numberSWLstripes / 2;
  
  # Calculate SWL wire capacitance
  $swl_wire_cap = $$input{"technology-array-swlwirecap"};
  $swl_wire_cap =~ s/pf\/mm//;
  $swl_wire_cap *= $mwl_length;

  # Device load on wlctrl signal in sense-amp stripe
  $swlctrl_nch_w = $$input{"technology-array-wlctrlloadnchw"};
  $swlctrl_nch_w =~ s/um//;
  $swlctrl_pch_w = $$input{"technology-array-wlctrlloadpchw"};
  $swlctrl_pch_w =~ s/um//;
  my $wlctrl_gatecap = ($swlctrl_nch_w + $swlctrl_pch_w) * $min_hv_l * $hv_c;
  my $wlctrl_devcap = $wlctrl_gatecap + ($swlctrl_nch_w + $swlctrl_pch_w) * $jctcap_hv;
  # Each wlctrl signal has a set of devices at every second sense-amp stripe hole
  # There are 4 wlctrl signals but only one switches at an activation or precharge
  $wlctrl_devcap = $numberSWLstripes / 2 * $wlctrl_devcap;

  # Device load in SWL driver / decoder
  # MWL gate load
  $swldrv_nch_w = $$input{"technology-array-swldrvnchw"};
  $swldrv_nch_w =~ s/um//;
  $swldrv_pch_w = $$input{"technology-array-swldrvpchw"};
  $swldrv_pch_w =~ s/um//;
  $swlrst_nch_w = $$input{"technology-array-swlrstnchw"};
  $swlrst_nch_w =~ s/um//;
  my $mwl_gatecap = ($swldrv_nch_w + $swldrv_pch_w) * $min_hv_l * $hv_c;
  $mwl_gatecap *= $numberSWLstripes * $n_swl_mwl / 2;
  # SWL gate load: cell access transistor
  my $swl_gatecap = $pagesize * $array_c * $pa_factor;
  # SWL cell parasitics load
  my $swl_cellcap = $pagesize * $c_swl_cell * $pa_factor;
  # Number of wordlines and MWL in one array stripe between two sense-amp stripes
  my $n_wl = $$input{"specification-control-rows"} / $n_subarray_par_bl;
  my $n_mwl = $n_wl / $n_swl_mwl;
  # dx junction load
  my $dx_jctcap = $swldrv_pch_w * $jctcap_hv * $numberSWLstripes / 2 * $n_mwl;
  # wlrst device load
  my $wlrst_cap = ($swlrst_nch_w * $min_logic_l * $logic_c + $swlrst_nch_w * $jctcap_logic) * $numberSWLstripes / 2 * $n_mwl;
  
  # Loads in MWL driver and decoder
  # MWL decoder transistors used at activate
  my $n_decode = $$input{"technology-array-mwlpredecode"};
  my $mwldec_gatecap = $$input{"technology-array-mwldecnchw"};
  $mwldec_gatecap =~ s/um//;
  $mwldec_gatecap *= $min_logic_l * $logic_c;
  my $toggle = $$input{"technology-array-mwldectoggle"};
  $toggle =~ s/%//;
  $toggle = $toggle / 100;
  $mwldec_gatecap *= $n_decode * $toggle * $n_mwl * $n_subbanks * $pa_factor;
  # MWL decoder wiring used at activate
  my $mwldec_wirecap = $$input{"technology-array-mwlwirecap"};
  $mwldec_wirecap =~ s/pf\/mm//;
  $mwldec_wirecap *= $n_decode * $toggle * $dx_length * $n_subbanks;
  # MWL decoder transistors used at precharge
  my $mwlpre_gatecap = $$input{"technology-array-mwldecpchw"};
  $mwlpre_gatecap =~ s/um//;
  $mwlpre_gatecap *= $min_logic_l * $logic_c;
  $mwlpre_gatecap *= $n_mwl * $n_subbanks;
  my $mwlpre_wirecap = $$input{"technology-array-mwlwirecap"};
  $mwlpre_wirecap =~ s/pf\/mm//;
  $mwlpre_wirecap *= $dx_length * $n_subbanks;

  # Calculate capacitances at Vperi and Vpp for activate
  my $vperi_cap_act = $dx_wire_cap + $wlrst_cap + $mwldec_gatecap + $mwldec_wirecap;
  my $vpp_cap_act = $mwl_wire_cap + $mwl_gatecap + $swl_wire_cap + $swl_gatecap + $swl_cellcap + $dx_wire_cap + $dx_jctcap;
    
  # Calculate capacitances at Vperi and Vpp for precharge
  my $vperi_cap_pre = $dx_wire_cap + $wlrst_cap + $mwlpre_gatecap + $mwlpre_wirecap;
  my $vpp_cap_pre = $mwl_wire_cap + $mwl_gatecap + $swl_wire_cap + $swl_gatecap + $swl_cellcap + $dx_wire_cap + $dx_jctcap;

  # Add calculated values to global variable
  $$current{"row-core-activate-device-vperi"} += ($wlrst_cap + $mwldec_gatecap) * $vperi / 1000 / $row_period;
  $$current{"row-core-activate-wire-vperi"} += ($dx_wire_cap + $mwldec_wirecap) * $vperi / 1000 / $row_period;
  $$current{"row-core-activate-device-vpp"} += ($mwl_gatecap + $swl_gatecap + $swl_cellcap + $dx_jctcap) * $vpp * $pa_factor / 1000 / $row_period;
  $$current{"row-core-activate-wire-vpp"} += ($mwl_wire_cap + $swl_wire_cap + $dx_wire_cap) * $vpp * $pa_factor / 1000 / $row_period;
  $$current{"row-core-precharge-device-vperi"} += ($wlrst_cap + $mwlpre_gatecap) * $vperi / 1000 / $row_period;
  $$current{"row-core-precharge-wire-vperi"} += ($dx_wire_cap + $mwlpre_wirecap) * $vperi / 1000 / $row_period;
  $$current{"row-core-precharge-device-vpp"} += ($mwl_gatecap + $swl_gatecap + $swl_cellcap + $dx_jctcap) * $vpp * $pa_factor / 1000 / $row_period;
  $$current{"row-core-precharge-wire-vpp"} += ($mwl_wire_cap + $swl_wire_cap + $dx_wire_cap) * $vpp * $pa_factor / 1000 / $row_period;

  if ($verbose) {
    print "\nRow current calculation:\n";
    foreach (("activate", "precharge")) {
      my $o = $_;
      foreach (@type) {
	my $t = $_;
	foreach (("vperi", "vpp")) {
	  my $key = "row-core-" . $o . "-" . $t . "-" . $_;
          printf "%s: %.2fmA\n", $key, $$current{$key};
	  }
	}
      }
    }

  # Row address bus in the periphery
  if (exists $$input{"technology-beol-cperiwire"}) {
    $c_periwire = $$input{"technology-beol-cperiwire"};
    $c_periwire =~ s/pf\/mm//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'CperiWire' of key 'BEOL' in section 'Technology' is missing.\n";
    return -1;
    }
  my $control_freq;
  if (exists $$input{"specification-control-frequency"}) {
    $control_freq = $$input{"specification-control-frequency"};
    $control_freq =~ s/mhz//;
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'frequency' of key 'control' in section 'specification' is missing.\n";
    return -1;
    }
  my $rowadd_wirecap = 0;
  my $rowadd_devcap = 0;
  foreach (@$rowadd) {
    my $toggle;
    if (exists $$_{toggle}) {
      $toggle = $$_{toggle};
      $toggle =~ s/%//;
      $toggle = $toggle / 100;
      }
    else {
      $toggle = 1;
      }
    my $multiplier = $toggle * $$_{frequency} / $control_freq;
    if (exists $$_{nchw}) { $rowadd_devcap += $$_{nchw} * $$_{width} * $multiplier; }
    if (exists $$_{pchw}) { $rowadd_devcap += $$_{nchw} * $$_{width} * $multiplier; }
    $rowadd_wirecap += $$_{length} * $$_{width} * $multiplier;
    }
  $rowadd_wirecap *= $c_periwire / 1000;
  $rowadd_devcap *= ($min_logic_l * $logic_c + $jctcap_logic) / 1000;
  $$current{"row-core-activate-device-vperi"} += $rowadd_devcap * $vperi / $row_period;
  $$current{"row-core-activate-wire-vperi"} += $rowadd_wirecap * $vperi / $row_period;

  if ($verbose) {
    printf "%s: %.2fmA\n", "row-core-activate-device-vperi", $$current{"row-core-activate-device-vperi"};
    printf "%s: %.2fmA\n", "row-core-activate-wire-vperi", $$current{"row-core-activate-wire-vperi"};
    }

  }

sub current_senseamp {

  # External variables
  my ($input, $pagesize, $prefetch, $varray, $pa_factor, $vperi, $vpp, $row_period, $core_frequency, $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # pagesize: number of bits
  # prefetch: data prefetch for high-speed IO
  # varray: bitline voltage
  # row period: time period in which one act / pre occurs
  # core_frequency: frequency of read and write operation in array
  # current: reference to has with external power calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  # Variables
  my ($sacap_act_varray, $sacap_pre_varray, $sacap_read_varray, $sacap_wrt_varray) = (0, 0, 0, 0);
  my ($sacap_act_vperi, $sacap_pre_vperi, $sacap_read_vperi, $sacap_wrt_vperi) = (0, 0, 0, 0);
  my ($sacap_act_vpp, $sacap_pre_vpp, $sacap_read_vpp, $sacap_wrt_vpp) = (0, 0, 0, 0);
  my ($sanchw, $sapchw, $saeqlw, $sashrw, $sabsww, $sanstw, $sapstw);
  my ($sanchl, $sapchl, $saeqll, $sashrl, $sabswl, $sanstl, $sapstl);
  my ($bl_cap, $cell_cap);
  my ($qsa_act, $qsa_read, $qsa_wrt, $qsa_pre);
  my $data_width;
  my $csl_length;
  my $core_period;
  my $active_csls;

  # Check and set internal variables
  $sanchw = $$input{"technology-array-sanchw"};
  $sapchw = $$input{"technology-array-sapchw"};
  $saeqlw = $$input{"technology-array-saeqlw"};
  if (exists $$input{"technology-array-sashrw"}) {
    $sashrw = $$input{"technology-array-sashrw"};
    }
  else {
    $sashrw = 0;
    }
  $sabsww = $$input{"technology-array-sabsww"};
  $sanstw = $$input{"technology-array-sansetw"};
  $sapstw = $$input{"technology-array-sapsetw"};
  $sanchl = $$input{"technology-array-sanchl"};
  $sapchl = $$input{"technology-array-sapchl"};
  $saeqll = $$input{"technology-array-saeqll"};
  if (exists $$input{"technology-array-sashrl"}) {
    $sashrl = $$input{"technology-array-sashrl"};
    }
  else {
    $sashrl = 0;
    }
  $sabswl = $$input{"technology-array-sabswl"};
  $sanstl = $$input{"technology-array-sansetl"};
  $sapstl = $$input{"technology-array-sapsetl"};
  $sanchw =~ s/um$//;
  $sapchw =~ s/um$//;
  $saeqlw =~ s/um$//;
  $sashrw =~ s/um$//;
  $sabsww =~ s/um$//;
  $sanstw =~ s/um$//;
  $sapstw =~ s/um$//;
  $sanchl =~ s/um$//;
  $sapchl =~ s/um$//;
  $saeqll =~ s/um$//;
  $sashrl =~ s/um$//;
  $sabswl =~ s/um$//;
  $sanstl =~ s/um$//;
  $sapstl =~ s/um$//;
  if (!($sanchw =~ /[0-9]*\.*[0-9]*/)&&!($sanchw =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sanchw' of key 'array' in section 'technology'.\n";
    }
  if (!($sapchw =~ /[0-9]*\.*[0-9]*/)&&!($sapchw =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sapchw' of key 'array' in section 'technology'.\n";
    }
  if (!($saeqlw =~ /[0-9]*\.*[0-9]*/)&&!($saeqlw =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'saeqlw' of key 'array' in section 'technology'.\n";
    }
  if (!($sashrw =~ /[0-9]*\.*[0-9]*/)&&!($sashrw =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sashrw' of key 'array' in section 'technology'.\n";
    }
  if (!($sabsww =~ /[0-9]*\.*[0-9]*/)&&!($sabsww =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sabsww' of key 'array' in section 'technology'.\n";
    }
  if (!($sanstw =~ /[0-9]*\.*[0-9]*/)&&!($sanstw =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sanstw' of key 'array' in section 'technology'.\n";
    }
  if (!($sapstw =~ /[0-9]*\.*[0-9]*/)&&!($sapstw =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sapstw' of key 'array' in section 'technology'.\n";
    }
  if (!($sanchl =~ /[0-9]*\.*[0-9]*/)&&!($sanchl =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sanchl' of key 'array' in section 'technology'.\n";
    }
  if (!($sapchl =~ /[0-9]*\.*[0-9]*/)&&!($sapchl =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sapchl' of key 'array' in section 'technology'.\n";
    }
  if (!($saeqll =~ /[0-9]*\.*[0-9]*/)&&!($saeqll =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'saeqll' of key 'array' in section 'technology'.\n";
    }
  if (!($sashrl =~ /[0-9]*\.*[0-9]*/)&&!($sashrl =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sashrl' of key 'array' in section 'technology'.\n";
    }
  if (!($sabswl =~ /[0-9]*\.*[0-9]*/)&&!($sabswl =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sabswl' of key 'array' in section 'technology'.\n";
    }
  if (!($sanstl =~ /[0-9]*\.*[0-9]*/)&&!($sanstl =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sanstl' of key 'array' in section 'technology'.\n";
    }
  if (!($sapstl =~ /[0-9]*\.*[0-9]*/)&&!($sapstl =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'sapstl' of key 'array' in section 'technology'.\n";
    }
  $bl_cap = $$input{"technology-array-cbl"};
  $bl_cap =~ s/ff$//;
  if (!($bl_cap =~ /[0-9]*\.*[0-9]*/)&&!($bl_cap =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'cbl' of key 'array' in section 'technology'.\n";
    }
  $cell_cap = $$input{"technology-array-cs"};
  $cell_cap =~ s/ff$//;
  if (!($cell_cap =~ /[0-9]*\.*[0-9]*/)&&!($cell_cap =~ /[0-9]/)) {
    $$errflag = 1;
    $$errstr .= "value is incorrect in subkey 'cbl' of key 'array' in section 'technology'.\n";
    }
  $data_width = $$input{"specification-io-width"} * $prefetch;
  if (exists $$input{"floorplanphysical-cellarray-cslblocks"}) {
    $csl_length = $$input{"floorplanphysical-cellarray-cslblocks"};
    my $l;
    if ($$input{"floorplanphysical-cellarray-bl"} eq "h") {
      $l = $$input{"floorplanphysical-sizehorizontal-a1"};
      }
    else {
      $l = $$input{"floorplanphysical-sizevertical-a1"};
      }
    $l =~ s/um$//;
    $csl_length *= $l;
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'cslblocks' of key 'cellarray' in section 'floorplanphysical' needs to be defined.\n";
    }
  # Number of active csls during read or write
  if (exists $$input{"technology-array-bitspercsl"}) {
    $active_csls = $data_width / $$input{"technology-array-bitspercsl"};
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'bitspercsl' of key 'array' in section 'technology' needs to be defined.\n";
    }
  # Frequency of read and write: core frequency
  $core_period = 1000 / $core_frequency;

  # Sense-amp device capacitance activate
  if ($$input{"floorplanphysical-cellarray-bltype"} eq "folded") {
    # Folded bitline: SAnch, SApch, eql, shr, bsw only junction
    $sacap_act_varray += ($sanchw * $sanchl + $sapchw * $sapchl) * $logic_c;
    $sacap_act_varray += ($sanchw + $sapchw) * $jctcap_logic;
    $sacap_act_vperi += ($saeqlw * $saeqll) * $logic_c;
    $sacap_act_vperi += ($saeqlw + $sabsww) * $jctcap_logic;
    $sacap_act_vpp += ($sashrw * $sashrl) * $logic_c;
    $sacap_act_vpp += ($sashrw) * $jctcap_logic;
    }
  else {
    # Open bitline: SAnch, SApch, eql, bsw only junction at activate
    $sacap_act_varray += ($sanchw * $sanchl + $sapchw * $sapchl) * $logic_c;
    $sacap_act_varray += ($sanchw + $sapchw) * $jctcap_logic;
    $sacap_act_vperi += ($saeqlw * $saeqll) * $logic_c;
    $sacap_act_vperi += ($saeqlw + $sabsww) * $jctcap_logic;
    }
  # Sense-amp device capacitance at read: only bitswitch load
  $sacap_read_vperi += $sabsww * $sabswl * $logic_c + $sabsww * $jctcap_logic;
  # Sense-amp device capacitance at write: all including bsw
  if ($$input{"floorplanphysical-cellarray-bltype"} eq "folded") {
    # Folded bitline: SAnch, SApch, eql,switching shr, bsw
    $sacap_act_varray += ($sanchw * $sanchl + $sapchw * $sapchl) * $logic_c;
    $sacap_act_varray += ($sanchw + $sapchw) * $jctcap_logic;
    $sacap_act_vperi += ($saeqlw * $saeqll +  $sabsww * $sabswl) * $logic_c;
    $sacap_act_vperi += ($saeqlw + $sabsww) * $jctcap_logic;
    $sacap_act_vpp += ($sashrw * $sashrl) * $logic_c;
    $sacap_act_vpp += ($sashrw) * $jctcap_logic;
    }
  else {
    # Open bitline: SAnch, SApch, eql, bsw
    $sacap_act_varray += ($sanchw * $sanchl + $sapchw * $sapchl) * $logic_c;
    $sacap_act_varray += ($sanchw + $sapchw) * $jctcap_logic;
    $sacap_act_vperi += ($saeqlw * $saeqll + $sabsww * $sabswl) * $logic_c;
    $sacap_act_vperi += ($saeqlw + $sabsww) * $jctcap_logic;
    }
  # Add nset and pset to activate and precharge
  $sacap_act_vperi += ($sapstw * $sanstl + $sanstw * $sapstl) * $logic_c;
  $sacap_pre_vperi += ($sapstw * $sanstl + $sanstw * $sapstl) * $logic_c;
  
  # Add bitline capacitance to activate and write
  $sacap_act_varray += $bl_cap;
  $sacap_wrt_varray += $bl_cap;
  
  # Add cell capacitance to write
  $sacap_wrt_varray += $cell_cap;

  # Calculate charge per sense-amp for varray
  $qsa_act = 0.5 * $varray * $sacap_act_varray;
  $qsa_read = $varray * $sacap_read_varray;
  $qsa_wrt = $varray * $sacap_wrt_varray;
  $qsa_pre = 0.5 * $varray * $sacap_pre_varray;
  # Calaculate total charge
  # Activate and precharge: switching sense-amps determined by pagesize
  $qsa_act *= $pagesize * $pa_factor / 1000;
  $qsa_pre *= $pagesize * $pa_factor / 1000;
  # Read and write: switching sense-amps determined by data width (number of IOs * prefetch)
  $qsa_read *= $data_width * $pa_factor / 1000;
  $qsa_wrt *= $data_width * $pa_factor / 1000;
  # Calculate currents
  # Frequency of act and pre: row period
  $$current{"senseamp-core-activate-device-varray"} += $qsa_act / $row_period;
  $$current{"senseamp-core-precharge-device-varray"} += $qsa_pre / $row_period;
  $$current{"senseamp-core-read-device-varray"} += $qsa_read / $core_period;
  $$current{"senseamp-core-write-device-varray"} += $qsa_wrt / $core_period;

  # Calculate charge per sense-amp for vperi
  $qsa_act = 0.5 * $vperi * $sacap_act_vperi;
  $qsa_read = $vperi * $sacap_read_vperi;
  $qsa_wrt = $vperi * $sacap_wrt_vperi;
  $qsa_pre = 0.5 * $vperi * $sacap_pre_vperi;
  # Calaculate total charge
  # Activate and precharge: switching sense-amps determined by pagesize
  $qsa_act *= $pagesize * $pa_factor/ 1000;
  $qsa_pre *= $pagesize * $pa_factor / 1000;
  # Read and write: switching sense-amps determined by data width (number of IOs * prefetch)
  $qsa_read *= $data_width * $pa_factor / 1000;
  $qsa_wrt *= $data_width * $pa_factor / 1000;
  # Calculate currents
  # Frequency of act and pre: row period
  $$current{"senseamp-core-activate-device-vperi"} += $qsa_act / $row_period;
  $$current{"senseamp-core-precharge-device-vperi"} += $qsa_pre / $row_period;
  $$current{"senseamp-core-read-device-vperi"} += $qsa_read / $core_period;
  $$current{"senseamp-core-write-device-vperi"} += $qsa_wrt / $core_period;

  # Calculate charge per sense-amp for vpp
  $qsa_act = 0.5 * $vpp * $sacap_act_vpp;
  $qsa_read = $vpp * $sacap_read_vpp;
  $qsa_wrt = $vpp * $sacap_wrt_vpp;
  $qsa_pre = 0.5 * $vpp * $sacap_pre_vpp;
  # Calaculate total charge
  # Activate and precharge: switching sense-amps determined by pagesize
  $qsa_act *= $pagesize * $pa_factor / 1000;
  $qsa_pre *= $pagesize * $pa_factor / 1000;
  # Read and write: switching sense-amps determined by data width (number of IOs * prefetch)
  $qsa_read *= $data_width * $pa_factor / 1000;
  $qsa_wrt *= $data_width * $pa_factor / 1000;
  # Calculate currents
  # Frequency of act and pre: row period
  $$current{"senseamp-core-activate-device-vpp"} += $qsa_act / $row_period;
  $$current{"senseamp-core-precharge-device-vpp"} += $qsa_pre / $row_period;
  $$current{"senseamp-core-read-device-vpp"} += $qsa_read / $core_period;
  $$current{"senseamp-core-write-device-vpp"} += $qsa_wrt / $core_period;

  # Wire capacitances
  # nset, pset, shr (=mux, iso) and eql at activate and precharge
  my $nset_cap = 2 * $mwl_length * $c_periwire;
  my $pset_cap = 2 * $mwl_length * $c_periwire;
  my $shr_cap = 0;
  if ($$input{"floorplanphysical-cellarray-bltype"} eq "folded") { $shr_cap = 2 * $mwl_length * $c_periwire; }
  my $eql_cap = 2 * $mwl_length * $c_periwire;
  # Current at Vperi
  $qsa_act = ($nset_cap + $pset_cap + $eql_cap) * $vperi / 1000;
  $qsa_pre = ($nset_cap + $pset_cap + $eql_cap) * $vperi / 1000;
  $$current{"senseamp-core-activate-wire-vperi"} += $qsa_act / $row_period;
  $$current{"senseamp-core-precharge-wire-vperi"} += $qsa_pre / $row_period;
  # Current at vpp
  $qsa_act = $shr_cap * $vpp / 1000;
  $qsa_pre = $shr_cap * $vpp / 1000;
  $$current{"senseamp-core-activate-wire-vpp"} += $qsa_act / $row_period;
  $$current{"senseamp-core-precharge-wire-vpp"} += $qsa_pre / $row_period;
  # csl at read and write
  my $csl_cap = $csl_length * $c_periwire * $active_csls * $pa_factor;
  $qsa_read = $csl_cap * $vperi / 1000;
  $qsa_wrt = $csl_cap * $vperi / 1000;
  $$current{"senseamp-core-read-wire-vperi"} += $qsa_read / $core_period;
  $$current{"senseamp-core-write-wire-vperi"} += $qsa_wrt / $core_period;

  if ($verbose) {
    print "\nSense-amp current calculation:\n";
    foreach (@operation) {
      my $o = $_;
      foreach (@type) {
	my $t = $_;
	foreach (@voltage) {
	  my $key = "senseamp-core-" . $o ."-" . $t . "-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub signal_current {

  # External variables
  my ($name, $signal, $vperi, $varray, $device_current, $wire_current, $device_current_varray, $wire_current_varray, $device_current_core, $wire_current_core,
    $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose) = @_;
  # name: name of signal for error messages
  # signal: reference to array with signal description hashes
  # vperi: periphery voltage
  # varray: array (bitline) voltage
  # device_current: reference to return calculated device current - not data: contains all current
  # wire_current: reference to return calculated wire current - not data: contains all current
  # device_current_varray: reference to return calculated device current - only for data: read first and write last segment is on varray
  # wire_current_varray: reference to return calculated wire current - only for data: read first and write last segment is on varray
  # device_current_core: reference to return calculated device current - only for data: uses boundary statement to assign to core
  # wire_current_core: reference to return calculated wire current - only for data: uses boundary statement to assign to core
  # coreboundary_read/write: last respectively first segment number for data path read and write 
  # which is considered part of the core when assigning currents to location
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  # Variables
  my $voltage;
  my $max_seg = $#{$signal};

  # Initialize currents to 0
  $$device_current = 0;
  $$wire_current = 0;
  $$device_current_varray = 0;
  $$wire_current_varray = 0;
  $$device_current_core = 0;
  $$wire_current_core = 0;

  # Loop over all signal segments
  my $seg = -1;
  foreach (@$signal) {
    $seg++; # loop index needed for special treatment array in data path
    if ((($name eq "data_read")&&($seg==0))||(($name eq "data_write")&&($seg==$max_seg))) {
      $voltage = $varray;
      }
    else {
      $voltage = $vperi;
      }
    if (!exists $$_{"length"}) {
      $$errflag = 1;
      $$errstr .= "'floorplansignaling' '$name' length not defined.\n";
      return -1;
      }
    if (!exists $$_{"width"}) {
      $$errflag = 1;
      $$errstr .= "'floorplansignaling' '$name' width not defined.\n";
      return -1;
      }
    if (!exists $$_{"frequency"}) {
      $$errflag = 1;
      $$errstr .= "'floorplansignaling' '$name' frequency not defined.\n";
      return -1;
      }
    my $length = $$_{"length"};
    my $width = $$_{"width"};
    my $frequency = $$_{"frequency"};
    my $toggle = 1;
    if (exists $$_{"toggle"}) {
      $toggle = $$_{"toggle"};
      $toggle =~ s/%//;
      if (($toggle=~/^[0-9]*\.*[0-9]*$/)&&($toggle=~/[0-9]/)) {
	$toggle = $toggle / 100;
	}
      else {
	$$errflag = 1;
	$$errstr .= "'floorplansignaling' '$name' toggle incorrectly defined as $toggle.\n";
	}
      }
    my $swing = $voltage;
    if (exists $$_{"swing"}) {
      $swing = $$_{"swing"};
      $swing =~ s/v//;
      if ($swing=~/^full$/) {
	$swing = $voltage;
	}
      elsif ($swing=~/^half$/) {
	$swing = $voltage / 2;
	}
      elsif (($swing=~/^[0-9]*\.*[0-9]$/)&&($swing=~/[0-9]/)) {
	# do nothing, correctly defined
	}
      else {
	$$errflag = 1;
	$$errstr .= "'floorplansignaling' '$name' swing incorrectly defined as $swing.\n";
	}
      }
    my $p_eff = 1;
    if (exists $$_{"p_eff"}) {
      $p_eff = $$_{"p_eff"};
      $p_eff =~ s/%//;
      if (($p_eff=~/^[0-9]*\.*[0-9]$/)&&($p_eff=~/[0-9]/)) {
        $p_eff = $p_eff / 100;
	}
      else {
	$$errflag = 1;
	$$errstr .= "'floorplansignaling' '$name' P_Eff incorrectly defined as $p_eff.\n";
	}
      }
    my $nchw = 0;
    if (exists $$_{"nchw"}) { 
      $nchw = $$_{"nchw"};
      $nchw =~ s/um//;
      if (($nchw=~/^[0-9]*\.*[0-9]*$/)&&($nchw=~/[0-9]/)) {
	# do nothing, correctly defined
	}
      else {
	$$errflag = 1;
	$$errstr .= "'floorplansignaling' '$name' nchw incorrectly defined as $nchw.\n";
	}
      }
    my $pchw = 0;
    if (exists $$_{"pchw"}) {
      $pchw = $$_{"pchw"};
      $pchw =~ s/um//;
      if (($pchw=~/^[0-9]*\.*[0-9]*$/)&&($pchw=~/[0-9]/)) {
	# do nothing, correctly defined
	}
      else {
	$$errflag = 1;
	$$errstr .= "'floorplansignaling' '$name' pchw incorrectly defined as $pchw.\n";
	}
      }
    my $load = 0;
    if (exists $$_{"load"}) {
      $load = $$_{"load"};
      $load =~ s/ff//;
      if (($load=~/^[0-9]*\.*[0-9]*$/)&&($load=~/[0-9]/)) {
	# do nothing, correctly defined
	}
      else {
	$$errflag = 1;
	$$errstr .= "'floorplansignaling' '$name' load incorrectly defined as $load.\n";
	}
      }
    if ($$errflag) { return -1; }
    my $device_cap = (($nchw + $pchw) * ($min_logic_l * $logic_c + $jctcap_logic) + $load) * $width;
    my $wire_cap = $length * $c_periwire * $width;
    my $q_device = $device_cap * $swing / 1000;
    my $q_wire = $wire_cap * $swing / 1000;
    if ((($name eq "data_read")&&($seg==0))||(($name eq "data_write")&&($seg==$max_seg))) {
      $$device_current_varray += $q_device * $frequency * $toggle / 1000 / $p_eff;
      $$wire_current_varray += $q_wire * $frequency * $toggle / 1000 / $p_eff;
      }
    elsif ((($name eq "data_read")&&($seg<=$coreboundary_read))||(($name eq "data_write")&&($seg>=$coreboundary_write))) {
      $$device_current_core += $q_device * $frequency * $toggle / 1000 / $p_eff;
      $$wire_current_core += $q_wire * $frequency * $toggle / 1000 / $p_eff;
      }
    else {
      $$device_current += $q_device * $frequency * $toggle / 1000 / $p_eff;
      $$wire_current += $q_wire * $frequency * $toggle / 1000 / $p_eff;
      }
      
    }
  
  }

sub current_column {

  # External variables
  my ($input, $coladd, $vperi, $varray, $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # coladd: reference to array describing column address path segments length, width, frequency, buffers, toggle and swing
  # vperi: peripheral logic voltage
  # varray: array (bitline) voltage
  # current: reference to hash with with currents calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Variables
  my ($device_current, $wire_current, $device_current_varray, $wire_current_varray,$device_current_core, $wire_current_core);

  # Calculate signal current of coladd bus
  signal_current ("coladd", $coladd, $vperi, $varray, \$device_current, \$wire_current, \$device_current_varray, \$wire_current_varray,
    \$device_current_core, \$wire_current_core, 0, 0, $errflag, $errstr, $verbose);
  $$current{"column-core-read-device-vperi"} += $device_current;
  $$current{"column-core-read-wire-vperi"} += $wire_current;
  $$current{"column-core-write-device-vperi"} += $device_current;
  $$current{"column-core-write-wire-vperi"} += $wire_current;
  if ($verbose) {
    print "\nColumn current calculation:\n";
    foreach (@operation) {
      my $o = $_;
      foreach (@type) {
	my $t = $_;
	foreach (@voltage) {
	  my $key = "column-core-" . $o ."-" . $t . "-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub current_data_read {

  # External variables
  my ($input, $data_read, $vperi, $varray, $current, $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # data_read: reference to array describing data read path segments length, width, frequency, buffers, toggle and swing
  # vperi: peripheral logic voltage
  # varray: array (bitline) voltage
  # current: reference to hash with with currents calculated for the different power components
  # coreboundary_read/write: last respectively first segment number for data path read and write 
  # which is considered part of the core when assigning currents to location
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Variables
  my ($device_current, $wire_current, $device_current_varray, $wire_current_varray, $device_current_core, $wire_current_core);
  
  # Calculate signal current of data read bus
  signal_current ("data_read", $data_read, $vperi, $varray, \$device_current, \$wire_current, \$device_current_varray, \$wire_current_varray,
    \$device_current_core, \$wire_current_core, $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose);
  $$current{"data-periphery-read-device-vperi"} += $device_current;
  $$current{"data-periphery-read-wire-vperi"} += $wire_current;
  $$current{"data-core-read-device-varray"} += $device_current_varray;
  $$current{"data-core-read-wire-varray"} += $wire_current_varray;
  $$current{"data-core-read-device-vperi"} += $device_current_core;
  $$current{"data-core-read-wire-vperi"} += $wire_current_core;
  if ($verbose) {
    print "\nData read current calculation:\n";
    foreach (@location) {
      my $l = $_;
      foreach (@type) {
	my $t = $_;
	foreach (@voltage) {
	  my $key = "data-" . $l . "-read-" . $t . "-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub current_data_write {

  # External variables
  my ($input, $data_write, $vperi, $varray, $current, $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # data_write: reference to array describing data write path segments length, width, frequency, buffers, toggle and swing
  # vperi: peripheral logic voltage
  # varray: array (bitline) voltage
  # current: reference to hash with with currents calculated for the different power components
  # coreboundary_read/write: last respectively first segment number for data path read and write 
  # which is considered part of the core when assigning currents to location
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Variables
  my ($device_current, $wire_current, $device_current_varray, $wire_current_varray, $device_current_core, $wire_current_core);
  
  # Calculate signal current of data write bus
  signal_current ("data_write", $data_write, $vperi, $varray, \$device_current, \$wire_current, \$device_current_varray, \$wire_current_varray,
    \$device_current_core, \$wire_current_core, $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose);
  $$current{"data-periphery-write-device-vperi"} += $device_current;
  $$current{"data-periphery-write-wire-vperi"} += $wire_current;
  $$current{"data-core-write-device-varray"} += $device_current_varray;
  $$current{"data-core-write-wire-varray"} += $wire_current_varray;
  $$current{"data-core-write-device-vperi"} += $device_current_core;
  $$current{"data-core-write-wire-vperi"} += $wire_current_core;
  if ($verbose) {
    print "\nData write current calculation:\n";
    foreach (@location) {
      my $l = $_;
      foreach (@type) {
	my $t = $_;
	foreach (@voltage) {
	  my $key = "data-" . $l . "-write-" . $t . "-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub current_control {

  # External variables
  my ($input, $control, $bankadd, $vperi, $varray, $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # control: reference to array describing control path segments length, width, frequency, buffers, toggle and swing
  # bankadd: reference to array describing bank address path segments length, width, frequency, buffers, toggle and swing
  # vperi: peripheral logic voltage
  # varray: array (bitline) voltage
  # current: reference to hash with with currents calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Variables
  my ($device_current, $wire_current, $device_current_varray, $wire_current_varray, $device_current_core, $wire_current_core);
  
  # Calculate signal current of control bus
  signal_current ("control", $control, $vperi, $varray, \$device_current, \$wire_current, \$device_current_varray, \$wire_current_varray,
    \$device_current_core, \$wire_current_core, 0, 0, $errflag, $errstr, $verbose);
  $$current{"control-periphery-write-device-vperi"} += $device_current;
  $$current{"control-periphery-write-wire-vperi"} += $wire_current;
  $$current{"control-periphery-read-device-vperi"} += $device_current;
  $$current{"control-periphery-read-wire-vperi"} += $wire_current;
  $$current{"control-periphery-activate-device-vperi"} += $device_current;
  $$current{"control-periphery-activate-wire-vperi"} += $wire_current;
  $$current{"control-periphery-precharge-device-vperi"} += $device_current;
  $$current{"control-periphery-precharge-wire-vperi"} += $wire_current;
  # Control is assumed to draw current even during NOP
  $$current{"control-periphery-nop-device-vperi"} += $device_current;
  $$current{"control-periphery-nop-wire-vperi"} += $wire_current;
  my $one_bank = 0;
  if (exists $$input{"specification-control-bankadd"}) {
    if ($$input{"specification-control-bankadd"} == 0) {
      $one_bank = 1;
      }
    }
  if (exists $$input{"specification-control-banks"}) {
    if ($$input{"specification-control-banks"} == 1) {
      $one_bank = 1;
      }
    }
  unless ($one_bank) {
    signal_current ("bankadd", $bankadd, $vperi, $varray, \$device_current, \$wire_current, \$device_current_varray, \$wire_current_varray,
      \$device_current_core, \$wire_current_core, 0, 0, $errflag, $errstr, $verbose);
    $$current{"control-periphery-write-device-vperi"} += $device_current;
    $$current{"control-periphery-write-wire-vperi"} += $wire_current;
    $$current{"control-periphery-read-device-vperi"} += $device_current;
    $$current{"control-periphery-read-wire-vperi"} += $wire_current;
    $$current{"control-periphery-activate-device-vperi"} += $device_current;
    $$current{"control-periphery-activate-wire-vperi"} += $wire_current;
    $$current{"control-periphery-precharge-device-vperi"} += $device_current;
    $$current{"control-periphery-precharge-wire-vperi"} += $wire_current;
    }
  # Control is assumed to draw current even during NOP
  $$current{"control-periphery-nop-device-vperi"} += $device_current;
  $$current{"control-periphery-nop-wire-vperi"} += $wire_current;
  if ($verbose) {
    print "\nControl current calculation:\n";
    foreach (@operation) {
      my $o = $_;
      foreach (@type) {
	my $t = $_;
	foreach (@voltage) {
	  my $key = "control-periphery-" . $o . "-" . $t . "-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub current_clock {

  # External variables
  my ($input, $clock, $vperi, $varray, $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # clock: reference to array describing clock path segments length, width, frequency, buffers, toggle and swing
  # vperi: peripheral logic voltage
  # varray: array (bitline) voltage
  # current: reference to hash with with currents calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Variables
  my ($device_current, $wire_current, $device_current_varray, $wire_current_varray, $device_current_core, $wire_current_core);
  
  # Calculate signal current of clock bus
  signal_current ("clock", $clock, $vperi, $varray, \$device_current, \$wire_current, \$device_current_varray, \$wire_current_varray,
    \$device_current_core, \$wire_current_core, 0, 0, $errflag, $errstr, $verbose);
  $$current{"clock-periphery-write-device-vperi"} += $device_current;
  $$current{"clock-periphery-write-wire-vperi"} += $wire_current;
  $$current{"clock-periphery-read-device-vperi"} += $device_current;
  $$current{"clock-periphery-read-wire-vperi"} += $wire_current;
  $$current{"clock-periphery-activate-device-vperi"} += $device_current;
  $$current{"clock-periphery-activate-wire-vperi"} += $wire_current;
  $$current{"clock-periphery-precharge-device-vperi"} += $device_current;
  $$current{"clock-periphery-precharge-wire-vperi"} += $wire_current;
  # Clock is assumed to draw current even during NOP
  $$current{"clock-periphery-nop-device-vperi"} += $device_current;
  $$current{"clock-periphery-nop-wire-vperi"} += $wire_current;
  if ($verbose) {
    print "\nClock current calculation:\n";
    foreach (@operation) {
      my $o = $_;
      foreach (@type) {
	my $t = $_;
	foreach (@voltage) {
	  my $key = "clock-periphery-" . $o . "-" . $t . "-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub current_periphery {

  # External variables
  my ($input, $periphery_logic, $periphery_sinks, $vcc, $vperi, $varray, $vpp, $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # periphery_logic: reference to array describing periphery logic blocks' device_width, wire_length, operation, component and toggle
  # periphery_sinks: reference to array describing sinks' voltage and current
  # vcc: supply voltage
  # vperi: peripheral logic voltage
  # varray: array (bitline) voltage
  # vpp: wordline voltage
  # current: reference to hash with with currents calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Logic blocks
  my $clock_frequency = $$input{"specification-dataclock-frequency"};
  $clock_frequency =~ s/mhz//;
  my $control_frequency = $$input{"specification-control-frequency"};
  $control_frequency =~ s/mhz//;
  foreach (@$periphery_logic) {
    my $device_width = $$_{"device_width"};
    my $wire_length = $$_{"wire_length"};
    my $operation = $$_{"operation"};
    my $component = $$_{"component"};
    my $toggle = $$_{"toggle"};
    my $devcap = $device_width * $min_logic_l * $logic_c + $device_width * $jctcap_logic;
    my $wirecap = $wire_length * $c_periwire;
    my ($qdev, $qwire);
    if (exists $$_{"swing"}) {
      my $swing = $$_{"swing"};
      $swing =~ s/v//;
      $qdev = $devcap * $swing / 1000;
      $qwire = $wirecap * $swing / 1000;
      }
    else {
      $qdev = $devcap * $vperi / 1000;
      $qwire = $wirecap * $vperi / 1000;
      }
    my $p_eff = 1;
    if (exists $$_{"p_eff"}) {
      $p_eff = $$_{"p_eff"};
      $p_eff =~ s/%//;
      if (($p_eff=~/^[0-9]*\.*[0-9]$/)&&($p_eff=~/[0-9]/)) {
        $p_eff = $p_eff / 100;
	}
      else {
	$$errflag = 1;
	$$errstr .= "'Periphery' 'Logic' P_Eff incorrectly defined as $p_eff.\n";
	}
      }
    my ($dev_current, $wire_current);
    if (($component eq "row")||($component eq "column")||($component eq "control")) {
      $dev_current = $qdev * $control_frequency * $toggle / 1000 / $p_eff;
      $wire_current = $qwire * $control_frequency * $toggle / 1000 / $p_eff;
      }
    else {
      $dev_current = $qdev * $clock_frequency * $toggle / 1000 / $p_eff;
      $wire_current = $qwire * $clock_frequency * $toggle / 1000 / $p_eff;
      }
    my $key_stem;
    if (($component eq "row")||($component eq "column")) {
      $key_stem = $component . "-core-";
      }
    else {
      $key_stem = $component . "-periphery-";
      }
    if (($operation eq "all")||($operation eq "read")||($operation eq "readwrite")) {
      my $key = $key_stem . "read-";
      $$current{$key."device-vperi"} += $dev_current;
      $$current{$key."wire-vperi"} += $wire_current;
      }
    if (($operation eq "all")||($operation eq "write")||($operation eq "readwrite")) {
      my $key = $key_stem . "write-";
      $$current{$key."device-vperi"} += $dev_current;
      $$current{$key."wire-vperi"} += $wire_current;
      }
    if (($operation eq "all")||($operation eq "activate")||($operation eq "row")) {
      my $key = $key_stem . "activate-";
      $$current{$key."device-vperi"} += $dev_current;
      $$current{$key."wire-vperi"} += $wire_current;
      }
    if (($operation eq "all")||($operation eq "precharge")||($operation eq "row")) {
      my $key = $key_stem . "precharge-";
      $$current{$key."device-vperi"} += $dev_current;
      $$current{$key."wire-vperi"} += $wire_current;
      }
    if ($operation eq "all") {
      if (($component eq "control")||($component eq "clock")) {
	my $key = $key_stem . "nop-";
	$$current{"control-periphery-nop-device-vperi"} += $dev_current;
	$$current{"control-periphery-nop-wire-vperi"} += $wire_current;
	}
      }
    }

  # Sinks
  foreach (@$periphery_sinks) {
    $$current{"baseload-periphery-activate-device-".$$_{"voltage"}} += $$_{"current"};
    $$current{"baseload-periphery-precharge-device-".$$_{"voltage"}} += $$_{"current"};
    $$current{"baseload-periphery-read-device-".$$_{"voltage"}} += $$_{"current"};
    $$current{"baseload-periphery-write-device-".$$_{"voltage"}} += $$_{"current"};
    $$current{"baseload-periphery-nop-device-".$$_{"voltage"}} += $$_{"current"};
    }
    
  if ($verbose) {
    print "\nLogic block current calculation:\n";
    foreach (@components) {
      my $c = $_;
      foreach (@operation) {
        my $o = $_;
        foreach (@voltage) {
	  my $key = $c . "-periphery-" . $o . "-device-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  $key = $c . "-core-" . $o . "-device-" . $_;
	  if ($$current{$key}>0) {
	    printf "%s: %.2fmA\n", $key, $$current{$key};
	    }
	  }
	}
      }
    }

  }

sub Current::calculate_current {

  # External Variables
  my ($input, $data_r, $data_w, $coladd, $rowadd, $bankadd, $control, $clock, $periphery_logic, $periphery_sinks, $prefetch,
    $pagesize, $wl_act_overhead, $numberSWLstripes, $n_subarray_par_bl, $n_subarray_par_wl,
    $n_subbanks, $row_period, $pa_factor, $core_frequency, $vcc, $vperi, $vperi_eff, $varray, $varray_eff, $vpp, $vpp_eff,
    $coreboundary_read, $coreboundary_write, $current, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # data_r: reference to array describing read data path segments length, width, frequency, buffers, toggle and swing
  # data_w: reference to array describing write data path segments length, width, frequency, buffers, toggle and swing
  # coladd: reference to array describing column address path segments length, width, frequency, buffers, toggle and swing
  # rowadd: reference to array describing row address path segments length, width, frequency, buffers, toggle and swing
  # bankadd: reference to array describing bank address path segments length, width, frequency, buffers, toggle and swing
  # control: reference to array describing control path segments length, width, frequency, buffers, toggle and swing
  # clock: reference to array describing clock distribution segments length, width, frequency, buffers, toggle and swing
  # periphery_logic: reference to array describing periphery logic blocks' device_width, wire_length, operation, component and toggle
  # periphery_sinks: reference to array describing sinks' voltage and current
  # prefetch: data prefetch in bits
  # pagesize: number of bits
  # wl_act_overhead: multiplier for WL activation power in open bitline architectures with edge arrays
  # numberSWLstripes: total number of sub-WL driver stripes
  # n_subarray_par_bl: number of sub-arrays parallel to BLs
  # n_subarray_par_wl: number of sub-arrays parallel to WLs
  # n_subbanks: number of subbanks
  # row_period: time period for one act / pre command pair
  # core frequency: frequency of read and write operation in DRAM core
  # vcc: supply voltage
  # vperi: peripheral logic voltage
  # vperi_eff: generator efficiency of vperi
  # varray: array bitline voltage
  # varray_eff: generator efficiency of varray
  # vpp: worldine voltage
  # vpp_eff: pump efficiency of vpp
  # coreboundary_read/write: last respectively first segment number for data path read and write 
  # which is considered part of the core when assigning currents to location
  # current: reference to hash with with currents calculated for the different power components
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  # All power calculation is done in these steps
  # - calculate capacitance (either wire or device)
  # - calculate charge to be moved
  # - calculate effective charge due to generator / pump efficiency
  # - calculate current based on operating frequency
  # - calculate external power at supply voltage vcc

  # Initialize
  initialize_power_variables ($current);
  set_global_variables ($input, $n_subbanks, $n_subarray_par_bl, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate row related currents
  current_row ($input, $n_subbanks, $rowadd, $pagesize, $numberSWLstripes, $n_subarray_par_bl, $row_period, $pa_factor, $vperi, $vpp, 
    $current, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate sense-amp and bitline related currents
  current_senseamp ($input, $pagesize, $prefetch, $varray, $pa_factor, $vperi, $vpp, $row_period, $core_frequency, $current, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }

  # Calculate column peripheral current
  current_column ($input, $coladd, $vperi, $varray, $current, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate data read current
  current_data_read ($input, $data_r, $vperi, $varray, $current, $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate data write current
  current_data_write ($input, $data_w, $vperi, $varray, $current, $coreboundary_read, $coreboundary_write, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate control current
  current_control ($input, $control, $bankadd, $vperi, $varray, $current, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate clock current
  current_clock ($input, $clock, $vperi, $varray, $current, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  # Calculate periphery logic current
  current_periphery ($input, $periphery_logic, $periphery_sinks, $vcc, $vperi, $varray, $vpp, $current, $errflag, $errstr, $verbose);
  if ($$errflag) { return -1; }
  
  }

# Return 1 at end of package file
1;
