#!/usr/local/bin/perl

package perlsubs::FloorplanPhysical;

# This package performs all operations specific to the section floorplanphysical

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
  vertical => 1,
  horizontal => 1,
  sizevertical => 1,
  sizehorizontal => 1,
  cellarray => 1,
  );

sub check_vh {
  
  # Performs syntax check of keys vertical and horizontal

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # $key: key
  # $subkey: subkey
  # $value: value of subkey
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors
  
  # Check subkey
  if ($subkey ne "blocks") {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'floorplanphysical'.\n";
    }

  # Check value
  my @words = split (/ /, $value);
  foreach (@words) {
    if (!(/["a"|"p"][0-9]+/)) {
      $$errflag = 1;
      $$errstr .= "'$_' is incorrect assignment to subkey 'blocks', key '$key' in section 'floorplanphysical'.\n";
      }
    }
  
  }

sub check_size_vh {
  
  # Performs syntax check of keys sizevertical and sizehorizontal

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # $key: key
  # $subkey: subkey
  # $value: value of subkey
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors
  
  # Check subkey
  if (!($subkey =~ /["a"|"p"][0-9]+/)) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'floorplanphysical'.\n";
    }

  # Check value
  $value =~ s/um$//;
  if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
    $$errflag = 1;
    $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
      " '$key' in section 'floorplanphysical'.\n";
    }
  
  }

sub check_cellarray {
  
  # Performs syntax check of key cellarray

  # External variables
  my ($subkey, $value, $errflag, $errstr) = @_;
  # $subkey: subkey
  # $value: value of subkey
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors

  my %valid_subkeys = (
    bl => 1,
    bitsperbl => 1,
    cellsperswl => 1,
    bltype => 1,
    cslblocks => 1,
    eccfactor => 1,
    wlpitch => 1,
    blpitch => 1,
    senseampwidth => 1,
    swldriverwidth => 1,
    rowredundancy => 1,
    columnredundancy => 1,
    architecturefactor => 1,
    );
  
  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key 'cellarray' in section 'floorplanphysical'.\n";
    }

  # Check value
  if ($subkey eq "bl") {
    if (!($value =~ /^[h|v]$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be an 'h' or 'v' for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
  if (($subkey eq "bitsperbl")||($subkey eq "cellsperwl")||($subkey eq "cslblocks")) {
    if (!($value =~ /^[0-9]+$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive integer for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
  if (($subkey eq "eccfactor")||($subkey eq "architecturefactor")) {
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
  if ($subkey eq "bltype") {
    if (($value ne "open")&&($value ne "folded")) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be 'open' or 'folded' for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
  if (($subkey eq "wlpitch")||($subkey eq "blpitch")) {
    $value =~ s/nm$//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
  if (($subkey eq "senseampwidth")||($subkey eq "swldriverwidth")) {
    $value =~ s/um$//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
  if (($subkey eq "rowredundancy")||($subkey eq "columnredundancy")) {
    $value =~ s/%$//;
    if (!($value =~ /^[0-9]*\.*[0-9]*$/)) {
      $$errflag = 1;
      $$errstr .= "'$value' needs to be a positive number for subkey '$subkey' of key" .
	" 'cellarray' in section 'floorplanphysical'.\n";
      }
    }
      
  }

sub FloorplanPhysical::check_syntax {

  # Performs syntax checking in section FloorplanPhysical
  
  # External variables
  my ($input, $errflag, $errstr) = @_;
  # $input: reference to hash with keys and values
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors
  
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
      $$errstr .= "'" . $_ . "' is not a valid key in section 'floorplanphysical'.\n";
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
        if ($key eq "vertical")       { check_vh        ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "horizontal")     { check_vh        ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "sizevertical")   { check_size_vh   ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "sizehorizontal") { check_size_vh   ($key, $subkey, $value, $errflag, $errstr); last CASE; }
        if ($key eq "cellarray")      { check_cellarray ($subkey, $value, $errflag, $errstr);       last CASE; }
        }
      }
      
    }
  
  }

sub FloorplanPhysical::set_floorplan_variables {

  # Sets the global variables containing the floorplan
  # information defined in the description file.
  # It is assumed that the description of the DRAM is
  # syntactically correct.
  
  # External variables
  my ($input, $bl_dir, $blk_coord_h, $blk_coord_v, $blk_type_h, $blk_type_v,
    $errflag, $errstr, $verbose, $loop_flag, $loop_index) = @_;
  # input: reference to hash with keys and values
  # bl_dir: reference to bitline direction (h for horizontal, v for vertical)
  # blk_coord_h: reference to array of block coordinates in horizontal direction
  # blk_type_h:reference to array block types (a for array, p for periphery) in horizontal direction
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  # loop_flag: flag for program run in loop
  # loop_index: loop counter if run in loop
  
  # Variables
  my @horizontal;
  my @horizontal_coordinates;
  my @vertical;
  my @vertical_coordinates;
  
  # Get records from input hash
  if (exists $$input{"floorplanphysical-horizontal-blocks"}) {
    @horizontal = split (/ /, $$input{"floorplanphysical-horizontal-blocks"});
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'blocks', key 'horizontal' in section 'floorplanphysical' is required.\n";
    }
  if (exists $$input{"floorplanphysical-vertical-blocks"}) {
    @vertical = split (/ /, $$input{"floorplanphysical-vertical-blocks"});
    }
  else {
    $$errflag = 1;
    $$errstr .= "Subkey 'blocks', key 'vertical' in section 'floorplanphysical' is required.\n";
    }
  if ($$errflag) { return -1; }
  
  # Create list of horizontal coordinates
  push (@horizontal_coordinates, 0);
  foreach (@horizontal) {
    my $block = "floorplanphysical-sizehorizontal-" . $_;
    if (exists $$input{$block}) {
      my $previous = $horizontal_coordinates[$#horizontal_coordinates];
      $$input{$block} =~ s/um$//;
      push (@horizontal_coordinates, $previous + $$input{$block});
      }
    else {
      $$errflag = 1;
      $$errstr .= "Subkey $_, key 'sizehorizontal' in section 'floorplanphysical' is required.\n";
      }
    }
  
  # Create list of vertical coordinates
  push (@vertical_coordinates, 0);
  foreach (@vertical) {
    my $block = "floorplanphysical-sizevertical-" . $_;
    if (exists $$input{$block}) {
      my $previous = $vertical_coordinates[$#vertical_coordinates];
      $$input{$block} =~ s/um$//;
      push (@vertical_coordinates, $previous + $$input{$block});
      }
    else {
      $$errflag = 1;
      $$errstr .= "Subkey $_, key 'sizevertical' in section 'floorplanphysical' is required.\n";
      }
    }

  # Sanity check for die size
  my $width = $horizontal_coordinates[$#horizontal_coordinates];
  my $height = $vertical_coordinates[$#vertical_coordinates];
  if ((1000<$width)&&($width>20000)) {
    $$errflag = 1;
    $$errstr .= "FloorplanPhysical sanity check: die width <1mm or >20mm\n";
    }
  if ((1000<$height)&&($height>20000)) {
    $$errflag = 1;
    $$errstr .= "FloorplanPhysical sanity check: die height <1mm or >20mm\n";
    }
  if (($width*$height/1e6<1)||($width*$height/1e6>300)) {
    $$errflag = 1;
    $$errstr .= "FloorplanPhysical sanity check: die area <1mm2 or >300mm2\n";
    }
  if (($width/$height<0.16667)||($width/$height>6)) {
    $$errflag = 1;
    $$errstr .= "FloorplanPhysical sanity check: aspect ratio more than 6:1\n";
    }

  # Set return variables
  if (exists $$input{"floorplanphysical-cellarray-bl"}) {
    $$bl_dir = $$input{"floorplanphysical-cellarray-bl"};
    }
  else {
    $$errflag = 1;
    $$errstr .= "Section 'FloorplanPhysical' key 'cellarray' setting 'bl=<h|v>' is required\n";
    }
  @$blk_coord_h = @horizontal_coordinates;
  @$blk_coord_v = @vertical_coordinates;
  @$blk_type_h = ();
  foreach (@horizontal) {
    push (@$blk_type_h, substr ($_,0,1));
    }
  @$blk_type_v = ();
  foreach (@vertical) {
    push (@$blk_type_v, substr ($_,0,1));
    }

  # Additional output
  if ($verbose||!$loop_flag||($loop_flag&&($loop_index==0))) {
    print "\nPhysical floorplan:\n";
    printf "die width = %.0fum, die height = %.0fum\n\n", $width, $height;
    }

  }

sub FloorplanPhysical::draw_floorplan {

  # Creates text files with coordinates to be used in Excel
  # to draw physical floorplan of the die.
  # It is assumed that the description of the DRAM is
  # syntactically correct.
  
  # External variables
  my ($output_name, $horizontal_coordinates, $vertical_coordinates,
    $input, $errflag, $errstr) = @_;
  # output_name: file name of output file;
  # horizontal_coordinates: reference to array of coordinates of blocks in horizontal direction
  # vertical_coordinates: reference to array of coordinates of blocks invertical direction
  # input: reference to hash with keys and values
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors

  # Write file for export to Excel
  if (!(open (OUTPUT, ">" . $output_name))) {
    $$errflag = 1;
    $$errstr .= "Output file $output_name to export physical floorplan to Excel could not be opened.\n";
    return;
    }
    
  # Horizontal lines
  my $min = $$horizontal_coordinates[0];
  my $max = $$horizontal_coordinates[$#{$horizontal_coordinates}];
  my $is_at_min = 1;
  my $x;
  for (my $i=0; $i<=$#{$vertical_coordinates}; $i+=2) {
    $x = $$vertical_coordinates[$i];
    printf OUTPUT "%8.3e\t%8.3e\n", $min, $x;
    printf OUTPUT "%8.3e\t%8.3e\n", $max, $x;
    $is_at_min = 0;
    if ($i+1 <= $#{$vertical_coordinates}) {
      $x = $$vertical_coordinates[$i+1];
      printf OUTPUT "%8.3e\t%8.3e\n", $max, $x;
      printf OUTPUT "%8.3e\t%8.3e\n", $min, $x;
      $is_at_min = 1;
      }
    }
  # Return to origin
  if (!$is_at_min) {
    printf OUTPUT "%8.3e\t%8.3e\n", $min, $x;
    }
  # Vertical lines
  $min = $$vertical_coordinates[0];
  $max = $$vertical_coordinates[$#{$vertical_coordinates}];
  $is_at_min = 1;
  for (my $i=0; $i<=$#{$horizontal_coordinates}; $i+=2) {
    $x = $$horizontal_coordinates[$i];
    printf OUTPUT "%8.3e\t%8.3e\n", $x, $min;
    printf OUTPUT "%8.3e\t%8.3e\n", $x, $max;
    $is_at_min = 0;
    if ($i+1 <= $#{$horizontal_coordinates}) {
      $x = $$horizontal_coordinates[$i+1];
      printf OUTPUT "%8.3e\t%8.3e\n", $x, $max;
      printf OUTPUT "%8.3e\t%8.3e\n", $x, $min;
      $is_at_min = 1;
      }
    }
  # close file
  close OUTPUT;

  }

# Return 1 at end of package file
1;
