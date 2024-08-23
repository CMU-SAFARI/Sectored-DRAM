#!/usr/local/bin/perl

package perlsubs::Specification;

# This package performs all operations specific to the section specification

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

# Legal keys
my %valid_keys = (
  io => 1,
  control => 1,
  dataclock => 1,
  pattern => 1,
  );

sub check_io {

  # performs syntax check of key io

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    width => 1,
    datarate => 1,
    type => 1,
    burstlength => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  if (($subkey eq "width")||($subkey eq "burstlength")) {
    if (!($value =~ /^[0-9]+$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive integer for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }
  if ($subkey eq "datarate") {
    $value =~ s/gbps$//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit Gbps) for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }
  if ($subkey eq "type") {
    if (($value ne "single")&&($value ne "differential")) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be either 'single' or 'differential' for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }

  }

sub check_control {

  # performs syntax check of key control

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    frequency => 1,
    banks => 1,
    rows => 1,
    columns => 1,
    bankadd => 1,
    rowadd => 1,
    coladd => 1,
    miscellaneous => 1,
    pafactor => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Prpeare to check unit of frequency
  if ($subkey eq "frequency") {
    $value =~ s/mhz//;
    }

  # Check value
  #if (!($value =~ /^[0-9]+$/)) {
  #  $$errflag = 1;
  #  $$errstr .= "'$value' needs to be a positive integer for subkey '$subkey' of key" .
  #    " '$key' in section 'specification'.\n";
  #  }
  }

sub check_dataclock {

  # performs syntax check of key dataclock

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    number => 1,
    frequency => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  if ($subkey eq "number") {
    if (!($value =~ /^[0-9]+$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive integer for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }
  if ($subkey eq "frequency") {
    $value =~ s/mhz$//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number (unit MHz) for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }
  }

sub check_pattern {

  # performs syntax check of key pattern

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # key: key
  # subkey: subkey
  # value: value of subkey
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  
  my %valid_subkeys = (
    loop => 1,
    );

  my %valid_ops = (
    act => 1,
    pre => 1,
    rd => 1,
    wrt => 1,
    nop => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'specification'.\n";
    }

  # Check value
  my @words = split (/ /, $value);
  foreach (@words) {
    if (!(exists $valid_ops{$_})) {
      $$errflag = 1;
      $$errstr .= "Operation '$_' needs to be 'act', 'pre', 'rd', 'wrt' or 'nop' for subkey '$subkey' of key" .
	" '$key' in section 'specification'.\n";
      }
    }

  }

sub add_spec {

  # Adds specification information to signal paths
  
  # X, Y, 16, Z
  # External variables
  my ($input, $key, $initial_width, $initial_frequency, $forward, $signal, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # key: stem of key (e.g. datar)
  # initial_width: initial width
  # initial_frequency: initial frequency
  # forward: flag, if set then width and frequency is calculated from first segment which is init to last, otherwise from
  #   last (which then is init) to first
  # signal: reference to array of hashes describing signal
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  # Cancel if bus has no width
  if ($initial_width<0) {
    $$errflag = 1;
    $$errstr .= "Bus width needs to be >0 for signal '$key' in section 'specification'.\n";
    return -1;
    }
  elsif ($initial_width==0) {
    $initial_width = 1;
    }

  # Start verbose output
  if ($verbose) { print "\nSignal $key:\n"; }
  
  # Calculate bus width for each segment
  my ($seg_start, $seg_end, $seg_step);
  if ($forward) {
    $seg_start = 0;
    $seg_end = $#{$signal};
    }
  else {
    $seg_start = $#{$signal};
    $seg_end = 0;
    }
  $$signal[$seg_start]{width} = $initial_width;
  $$signal[$seg_start]{frequency} = $initial_frequency;
  if ((exists $$signal[$seg_start]{mux})&&(!$forward||($forward&&($seg_start==$seg_end)))) {
    $$errflag = 1;
    $$errstr .= "mux cannot be used in the last segment of key '$key' " . 
      "(topology: no wire after mux) in section 'floorplansignaling'.\n";
    return -1;
    }
  my @seg = ();
  if ($forward) {
    for (my $i=0;$i<$seg_end;$i++) { $seg[$i] = $i+1; }
    }
  else {
    for (my $i=0;$i<$seg_start;$i++) { $seg[$i] = $seg_start - $i; }
    }
    
  foreach (@seg) {
    my $seg = $_;
    my $mux = 1;
    if (exists $$signal[$seg-1]{mux}) {
      if (!($$signal[$seg-1]{mux} =~ /^[0-9]+:[0-9]+$/)) {
	$$errflag = 1;
	$$errstr .= "mux needs to have the form '<m>:<n>' for key '$key' segment '$seg' in section 'floorplansignaling'.\n";
	return -1;
	}
      my @words = split (/:/, $$signal[$seg-1]{mux});
      $mux = $words[1] / $words[0];
      }
    if ($forward) {
      $$signal[$seg]{width} = $$signal[$seg-1]{width} * $mux;
      $$signal[$seg]{frequency} = $$signal[$seg-1]{frequency} / $mux;
      }
    else {
      $$signal[$seg-1]{width} = $$signal[$seg]{width} / $mux;
      $$signal[$seg-1]{frequency} = $$signal[$seg]{frequency} * $mux;
      }
    }
  if ($verbose) {
    printf "  segment %d: wire %d bits, frequency %.0fMHz\n", 0, $$signal[0]{width}, $$signal[0]{frequency};
    for (my $seg=1; $seg<=$#{$signal}; $seg++) {
      printf "  segment %d: wire %d bits, frequency %.0fMHz\n", $seg, $$signal[$seg]{width}, $$signal[$seg]{frequency};
      }
    }
  
  }

sub Specification::check_syntax {

  # Performs syntax checking in section Specification
  
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
        if ($key eq "io")        { check_io        ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "control")   { check_control   ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "dataclock") { check_dataclock ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "pattern")   { check_pattern   ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        }
      }
      
    }
  
  }

sub Specification::add_specification_to_signals {
  
  # Adds specification information to each signal segment to allow electrical evaluation

  # External variables
  my ($input, $data_r, $data_w, $coladd, $rowadd,
    $bankadd, $control, $clock, $prefetch, $core_frequency,
    $errflag, $errstr, $verbose) = @_ ;
  # input: reference to hash with keys and values
  # data_r, data_w, coladd, rowadd,
  # bankadd, control, clock: references to arrays
  # of hashes with either a start / end pair or an inside / fraction
  # pair, the buffer values as defined in the input file and the swing and toggle.
  # prefetch: reference to prefetch calculated from data path
  # core frequency: frequency of read and write operation in DRAM core
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Verify that required spec parameters are defined
  if (!(exists $$input{"specification-io-width"})) {
    $$errflag = 1;
    $$errstr .= "key 'io' subkey 'width' needs to be defined in section 'specification'.\n";
    return -1;
    }
  if (!(exists $$input{"specification-io-datarate"})) {
    $$errflag = 1;
    $$errstr .= "key 'io' subkey 'datarate' needs to be defined in section 'specification'.\n";
    return -1;
    }
  my $io_frequency = $$input{"specification-io-datarate"};
  $io_frequency =~ s/gbps//;
  if (!(exists $$input{"specification-control-frequency"})) {
    $$errflag = 1;
    $$errstr .= "key 'control' subkey 'frequency' needs to be defined in section 'specification'.\n";
    return -1;
    }
  my $control_frequency = $$input{"specification-control-frequency"};
  $control_frequency =~ s/mhz//;
  if (!(exists $$input{"specification-dataclock-frequency"})) {
    $$errflag = 1;
    $$errstr .= "key 'clock' subkey 'frequency' needs to be defined in section 'specification'.\n";
    return -1;
    }
  my $clock_frequency = $$input{"specification-dataclock-frequency"};
  $clock_frequency =~ s/mhz//;

  # Calculate width of address busses
  my ($col_bus, $row_bus, $bank_bus) = (0, 0, 0);
  if (exists $$input{"specification-control-bankadd"}) {
    if (exists $$input{"specification-control-banks"}) {
      if (2**$$input{"specification-control-bankadd"} != $$input{"specification-control-banks"}) {;
	$$errflag = 1;
	$$errstr .= "Specify either 'control bankadd' or 'control banks' in section 'specification', not both.\n";
	return -1;
	}
      }
    $bank_bus = $$input{"specification-control-bankadd"};
    }
  if (exists $$input{"specification-control-rowadd"}) {
    if (exists $$input{"specification-control-rows"}) {
      if (2**$$input{"specification-control-rowadd"} != $$input{"specification-control-rows"}) {;
	$$errflag = 1;
	$$errstr .= "Specify either 'control rowadd' or 'control rows' in section 'specification', not both.\n";
	return -1;
	}
      }
    $row_bus = $$input{"specification-control-rowadd"};
    }
  if (exists $$input{"specification-control-coladd"}) {
    if (exists $$input{"specification-control-columns"}) {
      if (2**$$input{"specification-control-coladd"} != $$input{"specification-control-columns"}) {;
	$$errflag = 1;
	$$errstr .= "Specify either 'control coladd' or 'control columns' in section 'specification', not both.\n";
	return -1;
	}
      }
    $col_bus = $$input{"specification-control-coladd"};
    }
  if (exists $$input{"specification-control-banks"}) {
    if ($$input{"specification-control-banks"}>0) { $bank_bus = log ($$input{"specification-control-banks"}) / log (2); }
    }
  if (exists $$input{"specification-control-rows"}) {
    if ($$input{"specification-control-rows"}>0) { $row_bus = log ($$input{"specification-control-rows"}) / log (2); }
    }
  if (exists $$input{"specification-control-columns"}) {
    if ($$input{"specification-control-columns"}>0) { $col_bus = log ($$input{"specification-control-columns"}) / log (2); }
    }

  # Specify width of miscellaneous control bus and clock
  my ($control_bus, $clock_bus) = (0, 0);
  if (exists $$input{"specification-control-miscellaneous"}) {
    $control_bus = $$input{"specification-control-miscellaneous"};
    }
  if (exists $$input{"specification-dataclock-number"}) {
    $clock_bus = $$input{"specification-dataclock-number"};
    }

  # Add specification information to each existing signal
  if (exists $$data_r[0]{length}) { add_spec ($input, "datar", $$input{"specification-io-width"},
    $io_frequency*1000, 0, $data_r,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }
  if (exists $$data_w[0]{length}) { add_spec ($input, "dataw", $$input{"specification-io-width"},
    $io_frequency*1000, 1, $data_w,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }
  if (exists $$bankadd[0]{length}) { add_spec ($input, "bankadd", $bank_bus,
    $control_frequency, 1, $bankadd,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }
  if (exists $$rowadd[0]{length}) { add_spec ($input, "rowadd", $row_bus,
    $control_frequency, 1, $rowadd,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }
  if (exists $$coladd[0]{length}) { add_spec ($input, "coladd", $col_bus,
    $control_frequency, 1, $coladd,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }
  if (exists $$control[0]{length}) { add_spec ($input, "control", $control_bus,
    $control_frequency, 1, $control,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }
  if (exists $$clock[0]{length}) { add_spec ($input, "clock", $clock_bus,
    $clock_frequency, 1, $clock,  $errflag, $errstr, $verbose); }
  if ($$errflag) { return -1; }

  # set number of banks, rows and columns for later use
  $$input{"specification-control-banks"} = 2**$bank_bus;
  $$input{"specification-control-rows"} = 2**$row_bus;
  $$input{"specification-control-columns"} = 2**$col_bus;
  
  # check and set prefetch
  my @check_prefetch = ();
  if (exists $$data_r[0]{width}) {
    my $p = $$data_r[0]{width} / $$data_r[$#{$data_r}]{width};
    printf "check prefetch read %d\n", $p;
    push (@check_prefetch, $p);
    }
  if (exists $$data_w[0]{width}) {
    my $p = $$data_w[$#{$data_w}]{width} / $$data_w[0]{width};
    printf "check prefetch write %d\n", $p;
    push (@check_prefetch, $p);
    }
  if ($#check_prefetch<0) {
    $$errflag = 1;
    $$errstr .= "Neither data read nor data write specified in section 'floorplansignaling'.\n";
    return -1;
    }
  my $previous = $check_prefetch[0];
  foreach (@check_prefetch) {
    if ($_!=$previous) {
     $$errflag = 1;
     $$errstr .= "Multiplexing not consistent for data read and / or data write in section 'floorplansignaling'.\n";
     return -1;
      }
    $previous = $_;
    }
  $$prefetch = $previous;

  printf "prefetch is %d\n", $$prefetch;
  
  # set core frequency
  $$core_frequency = $io_frequency * 1000 / $$prefetch;
  
  }

sub Specification::set_specification_variables {
  
  # Sets specification related variables in main program

  # External variables
  my ($input, $bl_dir, $prefetch, $pagesize, $wl_act_overhead, $numberSWLstripes, $n_subarray_par_bl,
    $n_subarray_par_wl, $n_subbanks, $opshare_act, $opshare_pre, $opshare_rd, $opshare_wrt, $row_period, $pa_factor, $coldat_opshare,
    $dev_density, $dev_banks, $dev_rows, $dev_columns, $dev_io, $dev_prefetch, $dev_granularity, $errflag, $errstr, $verbose) = @_ ;
  # input: reference to hash with keys and values
  # bl_dir: BL direction (h or v)
  # prefetch: prefetch as calculated before
  # pagesize: references to global variable for pagesize
  # wl_act_overhead: reference to WL activation overhead for open bitline architectures
  # numberSWLstripes: reference to number of sub-WL redriver stripes
  # n_subarray_par_bl: reference to number of subarray blocks parallel to BL
  # n_subarray_par_wl:reference to  number of subarray blocks parallel to WL
  # n_subbanks: reference to number of subbanks in one bank
  # opshare_act: share of activate operation of total current calculated from pattern
  # opshare_pre: share of precharge operation of total current calculated from pattern
  # opshare_rd: share of read operation of total current calculated from pattern
  # opshare_wrt: share of write operation of total current calculated from pattern
  # row_period: time period which includes exactly one activate and precharge operation
  # coldat_opshare: multiplier for clock period of column and data path to get full burst out
  # dev_density: denisty
  # dev_banks: number of banks
  # dev_rows: number of rows
  # dev_columns: number of columns
  # dev_io: number of io bits
  # dev_prefetch: prefetch
  # dev_granularity: granularity
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  if (!(exists $$input{"specification-control-banks"})) {
    $$errflag = 1;
    $$errstr .= "Number of banks needs to be specified in section 'specification'.\n";
    }
  if (!(exists $$input{"specification-control-rows"})) {
    $$errflag = 1;
    $$errstr .= "Number of rows needs to be specified in section 'specification'.\n";
    }
  if (!(exists $$input{"specification-control-columns"})) {
    $$errflag = 1;
    $$errstr .= "Number of columns needs to be specified in section 'specification'.\n";
    }
  if (!(exists $$input{"specification-io-width"})) {
    $$errflag = 1;
    $$errstr .= "Number of IOs needs to be specified in section 'specification'.\n";
    }
  if ($$errflag) { return -1; }
  
  my ($banks, $rows, $columns, $io) = ($$input{"specification-control-banks"}, $$input{"specification-control-rows"},
    $$input{"specification-control-columns"}, $$input{"specification-io-width"});
    
  $$dev_density = $banks*$rows*$columns*$io/1024/1024;
  $$dev_banks = $banks;
  $$dev_rows = $rows;
  $$dev_columns = $columns;
  $$dev_io = $io;
  $$dev_prefetch = $prefetch;
  $$dev_granularity = $prefetch*$io/8;
  if ($verbose) {
    print "\nDevice Architecture Overview:\n";
    printf "Density %dMb\n", $banks*$rows*$columns*$io/1024/1024;
    print "$banks Banks, $rows rows, $columns columns, $io IOs\n";
    printf "Prefetch %d bits\n", $prefetch;
    printf "Granularity %d Bytes\n", $prefetch*$io/8;
    }

  # Calculate page size
  if (exists $$input{"floorplanphysical-cellarray-eccfactor"}) {
    $$pagesize = $columns*$io*$$input{"floorplanphysical-cellarray-eccfactor"};
    }
  else {
    $$pagesize = $columns*$io;
    }
  if ($verbose) {
    printf "Page size %.0f kByte\n", $$pagesize/1024/8;
    }

  # Check that bits per BL and cells per WL have been defined in FloorplanPhysical
  if (!(exists $$input{"floorplanphysical-cellarray-bitsperbl"})) {
    $$errflag = 1;
    $$errstr .= "BitsPerBL needs to be specified in section 'FloorplanPhysical'.\n";
    }
  if (!(exists $$input{"floorplanphysical-cellarray-cellsperswl"})) {
    $$errflag = 1;
    $$errstr .= "CellsPerSWL needs to be specified in section 'FloorplanPhysical'.\n";
    }
  if (!(exists $$input{"floorplanphysical-cellarray-bltype"})) {
    $$errflag = 1;
    $$errstr .= "BLtype needs to be specified in section 'FloorplanPhysical'.\n";
    }
  if ($$errflag) { return -1; }

  # Calculate number of SWL stripes
  my ($WLperSubarray, $BLperSubarray);
  if ($$input{"floorplanphysical-cellarray-bltype"} eq "folded") {
    $WLperSubarray = 2*$$input{"floorplanphysical-cellarray-bitsperbl"};
    }
  else {
    $WLperSubarray = $$input{"floorplanphysical-cellarray-bitsperbl"};
    }
  $BLperSubarray = $$input{"floorplanphysical-cellarray-cellsperswl"};
  my $WLperDie = $banks * $rows;
  $$numberSWLstripes = $$pagesize / $BLperSubarray;
  
  # Calculate additional SWL stripes due to array architecture (number of subbanks)
  my $blocks_par_bl;
  my $blocks_par_wl;
  if ($bl_dir eq "v") {
    $blocks_par_bl = $$input{"floorplanphysical-vertical-blocks"};
    $blocks_par_wl = $$input{"floorplanphysical-horizontal-blocks"};
    }
  else {
    $blocks_par_bl = $$input{"floorplanphysical-horizontal-blocks"};
    $blocks_par_wl = $$input{"floorplanphysical-vertical-blocks"};
    }
  $blocks_par_bl =~ s/[0-9]+//g;
  $blocks_par_wl =~ s/[0-9]+//g;
  my @blocks = split (/ /, $blocks_par_bl);
  my $n_array_par_bl = 0;
  if ($blocks[0] eq "a") { $n_array_par_bl++; }
  for (my $i=1;$i<=$#blocks;$i++) {
    if ($blocks[$i] eq "a") { $n_array_par_bl++; }
    }
  @blocks = split (/ /, $blocks_par_wl);
  my $n_array_par_wl = 0;
  if ($blocks[0] eq "a") { $n_array_par_wl++; }
  for (my $i=1;$i<=$#blocks;$i++) {
    if ($blocks[$i] eq "a") { $n_array_par_wl++; }
    }
  $$n_subbanks = $n_array_par_bl * $n_array_par_wl / $banks;
  $$numberSWLstripes += $$n_subbanks;

  # Assign pa_factor
  $$pa_factor = $$input{"specification-control-pafactor"};

  # Calculate master wordline length
  
  # Calculate number of subarrays in one array block parallel to the BL and WL
  $$n_subarray_par_bl = $rows / $WLperSubarray;
  $$n_subarray_par_wl = ($$numberSWLstripes - $$n_subbanks) / $$n_subbanks;

  # Calculate row activation overhead due to edge arrays in open bitline architectures
  $$wl_act_overhead = 1;
  if ($$input{"floorplanphysical-cellarray-bltype"} eq "open") {
    $$wl_act_overhead = ($$n_subarray_par_bl+ 1) / $$n_subarray_par_bl;
    }

  if ($verbose) {
    printf "Subbanks per bank: %d\n", $$n_subbanks;
    printf "Subarrays in array block parallel BL: %d\n", $$n_subarray_par_bl;
    printf "Subarrays in array block parallel WL: %d\n", $$n_subarray_par_wl;
    printf "Number of SWL driver stripes: %d\n", $$numberSWLstripes;
    printf "Row activation overhead (>1 for open bitline): %.3f\n", $$wl_act_overhead;
    }

  my $loop_period;
  my $clock_period = $$input{"specification-control-frequency"};
  $clock_period =~ s/mhz$//;
  $clock_period = 1000 / $clock_period;
  if (!(exists $$input{"specification-pattern-loop"})) {
    $$errflag = 1;
    $$errstr .= "Section 'specification' key 'pattern' subkey 'loop' needs to be defined.\n";
    return -1;
    }
  else {
    my $pattern = $$input{"specification-pattern-loop"};
    my @operations = split (/ /, $pattern);
    my ($n_act, $n_pre, $n_rd, $n_wrt, $n_nop) = (0, 0, 0, 0, 0);
    foreach (@operations) {
      if (/act/) { $n_act++; }
      if (/pre/) { $n_pre++; }
      if (/rd/) { $n_rd++; }
      if (/wrt/) { $n_wrt++; }
      if (/nop/) { $n_nop++; }
      }
    my $n_all = $n_act + $n_pre + $n_rd + $n_wrt + $n_nop;
    if ($n_act != $n_pre) {
      if ($n_pre > 0) {
        $$errflag = 1;
        $$errstr .= "Section 'specification' key 'pattern' needs same number of 'act' and 'pre'.\n";
        return -1;
	}
      else {
        $n_pre = $n_act;
	$n_nop = $n_nop - $n_pre;
	if ($n_nop < 0) { $n_nop = 0; }
	if ($verbose) {
          printf "No PRE commands but ACT commands specified, rda and wrta assumed.\n";
	  }
	}
      }
    $$opshare_act = $n_act / $n_all;
    $$opshare_pre = $n_pre / $n_all;
    $$opshare_rd = $n_rd / $n_all;
    $$opshare_wrt = $n_wrt / $n_all;
    $loop_period = $clock_period * $n_all;
    if ($n_act>0) {
      $$row_period = $loop_period / $n_act;
      }
    else {
      # This is a dummy value as this location is only reached in a loop pattern without row operation
      $$row_period = 60;
      }
    }
  $clock_period = $$input{"specification-control-frequency"};
  $clock_period =~ s/mhz//;
  $clock_period = 1000 / $clock_period;
  my $io_period = $$input{"specification-io-datarate"};
  $io_period =~ s/gbps//;
  $io_period = 1 / $io_period;
  # Model DDR4 burst length
  my $burst_period = $io_period * $prefetch * 2;
  $$coldat_opshare = $burst_period / $clock_period;
  printf "coldat_opshare is %d\n", $$coldat_opshare;
  if (exists $$input{"specification-io-burstlength"}) {
    my $bl = $$input{"specification-io-burstlength"};
    if (int($bl / $$coldat_opshare) != $bl / $$coldat_opshare) {
      $$errflag = 1;
      $$errstr .= "Section 'specification', key 'control': burst length is not valid, needs to be multiple of $$coldat_opshare.\n";
      return -1;
      }
    else {
      $$coldat_opshare = $bl * $io_period / $clock_period;
      }
    }

  if ($verbose) {
    printf "Pattern loop period: %.0fns\n", $loop_period;
    printf "Row operation period: %.0fns\n", $$row_period;
    printf "Operation share: %s %.0f%%\n", "activate", $$opshare_act * 100;
    printf "Operation share: %s %.0f%%\n", "precharge", $$opshare_pre * 100;
    printf "Operation share: %s %.0f%%\n", "read", $$opshare_rd * 100;
    printf "Operation share: %s %.0f%%\n", "write", $$opshare_wrt * 100;
    }

  }

# Return 1 at end of package file
1;
