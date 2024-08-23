#!/usr/local/bin/perl

# Main program to calculate DRAM parameters from description language

# Calculate power, performance and die size sensitivities of all DRAM
# architectures based on a description in a standardized language.

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

# This needs to be set according to the location of the program
use lib "/home/ataberk/safari/PartialActivation/RambusModel/perlsubs";

use Parser;
use Syntax;
use FloorplanPhysical;
use FloorplanSignaling;
use Specification;
use Technology;
use BasicElectrical;
use Current;
use Power;

# General variables
my %input = ();
my $verbose = 0;
my $verbose_power = 0;
my $errflag = 0;
my $errstr = "None";

# Loop over variables for sensitivity analysis
my $loop_flag = 0;
my %loop = ();
my @variations = ();
my $cmd_loop = "none";

# Main program

# Command line error message
my $cmd_error = "\nCommand line entry needs to be 'dram_model [<options>] <file>' to read " . 
  "description file '<file>.dram'.\nValid options are\n" .
  "  -d<zero|one|multi>: dimension of global loop\n  -v: verbose output\n\n";

# Get name of description file from command line argument
if ($#ARGV<0) { die $cmd_error; }
my $dram_file = $ARGV[$#ARGV] . ".dram";

# Get the options in the command line
for (my $i=0;$i<$#ARGV;$i++) {
  if (($ARGV[$i] ne "-v")&&!($ARGV[$i] =~ /-d.*/)&&($ARGV[$i] ne "-p")) { die $cmd_error; }
  if ($ARGV[$i] eq "-v") { $verbose = 1; }
  if ($ARGV[$i] eq "-p") { $verbose_power = 1; }
  if ($ARGV[$i] =~ /-d.*/) { $cmd_loop = $ARGV[$i]; }
  }

# Parse description file and store in hash
Parser::parser ($dram_file, \%input, \$errflag, \$errstr);
if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

# Delete old result files
my $old_files = $ARGV[$#ARGV] . "_*";
unlink glob($old_files);

# Check syntax of description file
Syntax::check_syntax (\%input, \$errflag, \$errstr);
if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

# Check if global loop has been defined and if yes set loop variables
if (exists $input{"globalloop-loop0-section"}) {

  $loop_flag = 1;
  GlobalLoop::set_variables (\%input, \%loop, \$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Loops can be one or multi-dimensional. The default is multi-dimensional when
  # every possible combination of variables is being evaluated.
  
  my $type = "multi";
  if (exists $input{"globalloop-type-dimension"}) {
    $type = $input{"globalloop-type-dimension"};
    }

  # Overwrite global loop type with command line option if given
  if ($cmd_loop ne "none") {
    $cmd_loop =~ s/-d//;
    $type = $cmd_loop;
    $input{"globalloop-type-dimension"} = $cmd_loop;
    if (($type ne "zero") &&($type ne "one") && ($type ne "multi")) {
      $errstr = "Command line global loop option -d needs to be zero, one or multi.";
      die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n";
      }
      
    }
    
  if ($type eq "multi") {

    # The code below is tricky as a list containing all values of a multi-dimensional
    # space of variable variations has to be created for an arbitrary number of
    # dimensions (the number of loop entries in the input file), ruling out 'for' loops
    # per dimension as would be the normal way of coding.
    # The code solves the problem by using a while loop and incrementing the dimensions
    # from inside to outside until the last dimensions has reached its last value.
    # For each instance of the combined multi-dimensional variation an array is created
    # (local @instance) and stored as an entry in the global array @variations.

    my @max_counter = ();
    my @counter = ();
    my $loops = 0;
    foreach (keys %loop) {
      $max_counter[$loops] = $#{$loop{$_}};
      $loops++;
      }
    for (my $i=0;$i<$loops;$i++) { $counter[$i] = 0; }

    my @loop = %loop;
    while ($counter[$loops-1]<=$max_counter[$loops-1]) {
      my @instance = ();
      for (my $i=0;$i<$loops;$i++) {
	push @instance, $loop[2*$i];
	push @instance, ${$loop[2*$i+1]}[$counter[$i]];
	}
      push @variations, \@instance;
      for (my $i=0;$i<$loops;$i++) {
	$counter[$i]++;
	if ($counter[$i]<=$max_counter[$i]) {
	  last;
	  }
	else {
	  if ($i==$loops-1) {
            last;
	    }
	  else {
            $counter[$i]=0;
	    }
	  }
	}
      }

    }

  elsif ($type eq "one") {

    # Check that all loops have the same number of elements
    my @counter = ();
    my $loops = 0;
    foreach (keys %loop) {
      $counter[$loops] = $#{$loop{$_}};
      $loops++;
      }
    my $max = $counter[0];
    foreach (@counter) {
      if ($_ != $max) {
      $errstr .= "All loop<n> statements in one dimensional global loops must have the same number of elements.\n";
      die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n";
        }
      }
    
    # Add instances to variations array
    for (my $i=0;$i<=$max;$i++) {
      my @instance = ();
      foreach (keys %loop) {
        push @instance, $_;
	push @instance, $loop{$_}[$i];
 	}
      push @variations, \@instance;
      }
    }

  else {

    # Run only first combination
    my @instance = ();
    foreach (keys %loop) {
      push @instance, $_;
      push @instance, $loop{$_}[0];
      }
    push @variations, \@instance;
    $loop_flag = 0;

    }

  if ($verbose) {
    print "\nInstances of variations to be calculated:\n";
    foreach (@variations) {
      foreach (@{$_}) { print "$_ "; } print "\n";
      }
    }
  
  # Create file for loop output and write its header
  my $output_name = sprintf "%s_power.txt", $ARGV[$#ARGV];
  if (!(open (SUMMARY, ">" . $output_name))) {
    $errstr .= "Output file $output_name to export variations loop power to Excel could not be opened.\n";
    die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n";
    }
  $loop{"row_period"} = 1;
  Power::loop_header (\*SUMMARY, \%loop, \$errflag, \$errstr, $verbose);
  delete $loop{"row_period"};

  }

else {

  # if no loop has been defined set dummy loop over one element to evaluate program once
  
  my @instance = ();
  push @instance, "specification-io-width";
  push @instance, $input{"specification-io-width"};
  push @variations, \@instance;
  
  }

# Loop over all variations (dummy loop over one element in case no variation is defined)
my $loop_index = -1;
foreach my $instance (@variations) {
  $loop_index++;
  my $max = $#{$instance};
  my $description = "";
  my %description = ();
  for (my $i=0;$i<=$max;$i+=2) {
    my $key = $$instance[$i];
    my $value = $$instance[$i+1];
    $input{$key} = $value;
    $description .= $key . " = " . $value . ", ";
    $description{$key} = $value;
    if ($key eq "specification-control-bankadd") { delete $input{"specification-control-banks"}; }
    if ($key eq "specification-control-rowadd")  { delete $input{"specification-control-rows"}; }
    if ($key eq "specification-control-coladd")  { delete $input{"specification-control-columns"}; }
    if ($key eq "specification-control-banks")   { delete $input{"specification-control-bankadd"}; }
    if ($key eq "specification-control-rows")    { delete $input{"specification-control-rowadd"}; }
    if ($key eq "specification-control-columns") { delete $input{"specification-control-coladd"}; }
    }
  $description =~ s/, $//;
  if ($loop_flag) {
    print "\nEvaluating $description\n";
    }
  else {
    $description = "Single data point";
    }

  # Device description variables (need to be local to each loop iteration to be reset correctly)

  # FloorplanPhysical
  my $bl_dir;                       # bitline direction
  my @blk_coord_h; my @blk_coord_v; # block coordinates horizontal and vertical
  my @blk_type_h;  my @blk_type_v;  # block type (a for array or p for periphery)
                                    # horizontal and vertical
  # FloorplanSignaling
  # All arrays contain hashes with either a start / end pair or an inside / fraction
  # pair, the buffer values as defined in the input file and the swing and toggle.
  # The ending avg is used for average power calculation, the ending wc for worst
  # case.
  # Calculated fields per segment are length, (calculated in this section),
  # width and frequency (calculated in section Specification)
  my @data_r = ();
  my @data_w = ();
  my @coladd = ();
  my @rowadd = ();
  my @bankadd = ();
  my @control= ();
  my @clock = ();
  my ($coreboundary_read, $coreboundary_write);

  # Specification
  # Bus width and frequency for each signal segment is
  # calculated and stored with the signals segments in the variables of
  # FloorplanSignaling.
  my $prefetch;
  my $pagesize;
  my $wl_act_overhead;
  my $numberSWLstripes;
  my $n_subarray_par_bl;
  my $n_subarray_par_wl;
  my $n_subbanks;
  my $opshare_act;
  my $opshare_pre;
  my $opshare_rd;
  my $opshare_wrt;
  my $coldat_opshare;
  my $dev_density;
  my $dev_banks;
  my $dev_rows;
  my $dev_columns;
  my $dev_io;
  my $dev_prefetch;
  my $dev_granularity;
  my $row_period;
  my $pa_factor;
  my $core_frequency;

  # BasicElectrical
  # Voltages and generator / pump efficiencies
  my $vcc;
  my ($vperi, $vperi_eff);
  my ($varray, $varray_eff);
  my ($vpp, $vpp_eff);

  # Periphery
  # Logic circuitry and current sinks
  # periphery_logic is an array of hashes with each hash element storing entries for
  # device_width, wire_length, operation, component and toggle.
  my @periphery_logic;
  # periphery_sinks is an array of hashes with each hash element storing entries for
  # voltage and current.
  my @periphery_sinks;

  # Current
  # This hash variable stores the calculated current of the different parts
  # of the chip and supporting information. Each has five parts separated by a dash:
  # <component>-<location>-<operation>-<type>-<voltage>
  # <component> is row, column, senseamp, data, control or clock and baseload
  # <location> is array (cell array and on-pitch circuitry) or periphery (everything else)
  # <operation> is activate, precharge, read or write
  # <type> is device or wire
  # <voltage> is vcc, vperi, varray or vpp
  my %current = ();

  # Calculated current and power
  my %power;
  my ($idd, $power);

  # Check syntax of description file (needs to be done again as loop could have syntax errors)
  Syntax::check_syntax (\%input, \$errflag, \$errstr);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Set global variables for physical floorplan
  FloorplanPhysical::set_floorplan_variables (\%input, \$bl_dir, \@blk_coord_h,
    \@blk_coord_v, \@blk_type_h, \@blk_type_v, \$errflag, \$errstr, $verbose, $loop_flag, $loop_index);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Write text file to be imported into Excel to create drawing of physical floorplan
  my $output_name = $ARGV[$#ARGV] . "_physical.txt";
  FloorplanPhysical::draw_floorplan ($output_name, \@blk_coord_h, \@blk_coord_v,
    \%input, \$errflag, \$errstr);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Set global variables which describe signaling flow
  FloorplanSignaling::set_floorplan_variables (\%input, \@data_r, \@data_w,
    \@coladd, \@rowadd, \@bankadd, \@control,
    \@clock, \$coreboundary_read, \$coreboundary_write,
    \$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Write text file to be imported into Excel to create drawing of signal floorplan
  $output_name = $ARGV[$#ARGV] . "_signals.txt";
  FloorplanSignaling::draw_floorplan ($output_name, \%input, \@blk_coord_h, \@blk_coord_v,
    \@data_r, \@data_w, \@coladd, \@rowadd, \@bankadd,
    \@control, \@clock, \$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Add specification information to the signals
  Specification::add_specification_to_signals (\%input,
    \@data_r, \@data_w, \@coladd, \@rowadd, \@bankadd,
    \@control, \@clock, \$prefetch, \$core_frequency,
    \$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Set remaining global variables from specification not stored in signals
  Specification::set_specification_variables (\%input, $bl_dir, $prefetch, \$pagesize,
    \$wl_act_overhead, \$numberSWLstripes, \$n_subarray_par_bl, \$n_subarray_par_wl,
    \$n_subbanks, \$opshare_act, \$opshare_pre, \$opshare_rd, \$opshare_wrt, \$row_period, \$pa_factor,
    \$coldat_opshare, \$dev_density, \$dev_banks, \$dev_rows, \$dev_columns, \$dev_io, \$dev_prefetch,
    \$dev_granularity, \$errflag, \$errstr, $verbose);

  #printf("%f\n",$pa_factor);
  #exit(0);
  
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Sanity check for aspect ratio and page size
  # This section of the program does not change the physical size of an array block as the one given
  # with as the vertical repsectively horizontal size is used. Its purpose is to support a quick
  # user iteration to find the exact size
  my $nb = $n_subarray_par_bl * $input{"floorplanphysical-cellarray-bitsperbl"};
  if ($input{"floorplanphysical-cellarray-bltype"} eq "folded") { $nb *= 2; }
  my $nw = $n_subarray_par_wl * $input{"floorplanphysical-cellarray-cellsperswl"};
  my ($ab, $aw);
  if ($input{"floorplanphysical-cellarray-bl"} eq "h") {
    $ab = $input{"floorplanphysical-sizehorizontal-a1"};
    $aw = $input{"floorplanphysical-sizevertical-a1"};
    }
  else {
    $ab = $input{"floorplanphysical-sizevertical-a1"};
    $aw = $input{"floorplanphysical-sizehorizontal-a1"};
    }
  my $cell_side = sqrt ($ab * $aw / ($nb * $nw)) * 1000;
  # reduce cell side in case of 6f2 or 4f2 architectures to match real size better
  my $cell_side_mult = 0.65;
  if (exists $input{"floorplanphysical-cellarray-architecturefactor"}) {
    $cell_side_mult = $input{"floorplanphysical-cellarray-architecturefactor"};
    }
  if ($input{"floorplanphysical-cellarray-bltype"} eq "open") { $cell_side *= $cell_side_mult; }
  my $physical_cells_per_mwl = $aw * 1000 / $cell_side;
  $physical_cells_per_mwl = 2 ** (int (log ($physical_cells_per_mwl) / log (2) ));
  my $cells_per_mwl = $n_subarray_par_wl * $input{"floorplanphysical-cellarray-cellsperswl"};
  my $ecc_factor;
  if (exists $input{"floorplanphysical-cellarray-eccfactor"}) {
    $ecc_factor = $input{"floorplanphysical-cellarray-eccfactor"};
    }
  else {
    $ecc_factor = 1;
    }

  # Get basic electrical information
  BasicElectrical::set_voltages (\%input, \$vcc, \$vperi, \$vperi_eff, \$varray,
    \$varray_eff, \$vpp, \$vpp_eff, \$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Get additional blocks consuming current
  Periphery::set_variables (\%input, \@periphery_logic, \@periphery_sinks,
    \$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }
  
  # Calculate currents contributions for the average situation
  Current::calculate_current (\%input, \@data_r, \@data_w, \@coladd, \@rowadd,
    \@bankadd, \@control, \@clock, \@periphery_logic, \@periphery_sinks, 
    $prefetch, $pagesize, $wl_act_overhead, $numberSWLstripes, $n_subarray_par_bl,
    $n_subarray_par_wl, $n_subbanks, $row_period, $pa_factor, $core_frequency, $vcc, $vperi, $vperi_eff,
    $varray, $varray_eff, $vpp, $vpp_eff, $coreboundary_read, $coreboundary_write, 
    \%current,\$errflag, \$errstr, $verbose);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  if ($verbose) {
    print "\nAll calculated current components:\n";
    foreach (sort keys %current) {
      if ($current{$_}>0) { printf "%s %.2fmA\n", $_, $current{$_}; }
      }
    }

  # Standard output in normal run
  if (!$verbose&&!$loop_flag) {
    print "\nDevice Architecture Overview:\n";
    printf "Density %dMb\n", $dev_density;
    print "$dev_banks Banks, $dev_rows rows, $dev_columns columns, $dev_io IOs\n";
    my $datarate = $input{"specification-io-datarate"};
    $datarate =~ s/gbps//;
    printf "Aggregate bandwidth %.3fGB/s\n", $dev_io * $datarate / 8;
    printf "Prefetch %d bits\n", $dev_prefetch;
    printf "Granularity %d Bytes\n", $dev_granularity;
    printf "Subbanks per bank: %d\n", $n_subbanks;
    printf "Subarrays in array block parallel BL: %d\n", $n_subarray_par_bl / $physical_cells_per_mwl * $cells_per_mwl / $ecc_factor;
    printf "Subarrays in array block parallel WL: %d\n", $n_subarray_par_wl * $physical_cells_per_mwl / $cells_per_mwl * $ecc_factor;
    printf "Page size from specification: %.1fkB\n", $dev_columns*$dev_io/8192;
    printf "Sanity check: minimum page size estimated from architecture: %.1fkB\n", $physical_cells_per_mwl / 8192 / $n_subbanks;
    printf "Number of SWL driver stripes: %d\n", $numberSWLstripes;
    printf "Row activation overhead (>1 for open bitline): %.3f\n", $wl_act_overhead;
    printf "Full burst in control clock cycles: %.0f\n", $coldat_opshare;
    printf "Row period: %.1fns\n", $row_period;
    printf "Partial activation factor: %.2f\n", $pa_factor;
    }
  
  # Check if array details have been defined and if yes calculate array block size
  if (exists $input{"floorplanphysical-cellarray-blpitch"}) {
    if (!exists $input{"floorplanphysical-cellarray-wlpitch"} || 
      !exists $input{"floorplanphysical-cellarray-senseampwidth"} || 
      !exists $input{"floorplanphysical-cellarray-swldriverwidth"}) {
      $errstr = "Provide either all of 'blpitch', 'wlpitch', 'senseampwidth', 'swldriverwidth' in " .
	"section 'FloorplanSignaling' key 'cellarray' or none.";
      die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n";
      }
    my $blpitch = $input{"floorplanphysical-cellarray-blpitch"};
    my $wlpitch = $input{"floorplanphysical-cellarray-wlpitch"};
    my $sawidth = $input{"floorplanphysical-cellarray-senseampwidth"};
    my $swwidth = $input{"floorplanphysical-cellarray-swldriverwidth"};
    $blpitch =~ s/nm//;
    $wlpitch =~ s/nm//;
    $sawidth =~ s/um//;
    $swwidth =~ s/um//;
    $blpitch = $blpitch / 1000;
    $wlpitch = $wlpitch / 1000;
    my ($blwidth, $wlwidth);
    my $rowred_mult = 1;
    if (exists $input{"floorplanphysical-cellarray-rowredundancy"}) {
      $rowred_mult = $input{"floorplanphysical-cellarray-rowredundancy"};
      $rowred_mult =~ s/%//;
      $rowred_mult = 1 + $rowred_mult / 100;
      }
    my $colred_mult = 1;
    if (exists $input{"floorplanphysical-cellarray-columnredundancy"}) {
      $colred_mult = $input{"floorplanphysical-cellarray-columnredundancy"};
      $colred_mult =~ s/%//;
      $colred_mult = 1 + $colred_mult / 100;
      }
    if ($input{"floorplanphysical-cellarray-bltype"} eq "folded") {
      $blwidth = ($wlpitch * $input{"floorplanphysical-cellarray-bitsperbl"} * 2 * $rowred_mult + $sawidth) *
        $n_subarray_par_bl / $physical_cells_per_mwl * $cells_per_mwl / $ecc_factor + $sawidth;
      $wlwidth = ($blpitch * $input{"floorplanphysical-cellarray-cellsperswl"} * 2 * $colred_mult + $swwidth) *
	$n_subarray_par_wl * $physical_cells_per_mwl / $cells_per_mwl * $ecc_factor + $swwidth;
      }
    else {
      $blwidth = ($wlpitch * $input{"floorplanphysical-cellarray-bitsperbl"} * $rowred_mult + $sawidth) *
        ($n_subarray_par_bl / $physical_cells_per_mwl * $cells_per_mwl / $ecc_factor + 1) - $sawidth;
      $wlwidth = ($blpitch * $input{"floorplanphysical-cellarray-cellsperswl"} * $colred_mult + $swwidth) *
	$n_subarray_par_wl * $physical_cells_per_mwl / $cells_per_mwl * $ecc_factor + $swwidth;
      }
    my ($a_horizontal, $a_vertical);
    if ($input{"floorplanphysical-cellarray-bl"} eq "v") {
      $a_vertical = $blwidth;
      $a_horizontal = $wlwidth;
      }
    else {
      $a_vertical = $wlwidth;
      $a_horizontal = $blwidth;
      }
    my $a1_horizontal = $input{"floorplanphysical-sizehorizontal-a1"};
    my $a1_vertical = $input{"floorplanphysical-sizevertical-a1"};
    my $rel_horizontal = ($a_horizontal - $a1_horizontal) / $a_horizontal * 100;
    my $rel_vertical = ($a_vertical - $a1_vertical) / $a_vertical * 100;
    if (!$verbose&&!$loop_flag) {
      print "Calculated array block size:\n";
      printf "Horizontal: calculated %.0fum, defined %.0fum (difference %.1f%%)\n", $a_horizontal, $a1_horizontal, $rel_horizontal;
      printf "Vertical:   calculated %.0fum, defined %.0fum (difference %.1f%%)\n", $a_vertical, $a1_vertical, $rel_vertical;
      }
    if ((abs($rel_horizontal)>5)||(abs($rel_vertical)>5)) {
      unless (!$verbose&&!$loop_flag) {
	print "Calculated array block size:\n";
	printf "Horizontal: calculated %.0fum, defined %.0fum (difference %.1f%%)\n", $a_horizontal, $a1_horizontal, $rel_horizontal;
	printf "Vertical:   calculated %.0fum, defined %.0fum (difference %.1f%%)\n", $a_vertical, $a1_vertical, $rel_vertical;
	}
      $errstr = "Calculated and input file A1 size disagree by more than 5%. Please match.";
      die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n";
      }
    }

  # Calculate output power
  Power::power (\%input, \%current, $vcc, $vperi, $varray, $vpp, $vperi_eff, $varray_eff, $vpp_eff,
      $row_period, $core_frequency, $opshare_act, $opshare_pre, $opshare_rd, $opshare_wrt, $coldat_opshare, $pa_factor,
      \$idd, \$power, \$errflag, \$errstr, $verbose, $verbose_power, $loop_flag);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }

  # Write power contributors to Excel
  if ($loop_flag) {
    my $length = int(log($#variations)/log(10))+1;
    my $format = "%s_power_%0" . $length . "d.txt";
    $output_name = sprintf $format, $ARGV[$#ARGV], $loop_index;
    $description{"row_period"} = $row_period;
    }
  else {
    $output_name = sprintf "%s_power.txt", $ARGV[$#ARGV];
    }
  Power::output_power_to_excel ($output_name, $description, \%input, \%current, $vcc, \%power, \$errflag, \$errstr, $verbose, $loop_flag);
  if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }
  
  # Add line to file with variation loop summary
  if ($loop_flag) {
    Power::loop_line (\*SUMMARY, \%description, \%power, \$errflag, \$errstr, $verbose);
    if ($errflag) { die "\nError(s) occured:\n\n$errstr\nScript aborted.\n\n"; }
    }
  
  } # end of loop over all variations

if ($loop_flag) { close SUMMARY; }

print "\nSuccessful run of 'dram_model.pl'.\n\n";
