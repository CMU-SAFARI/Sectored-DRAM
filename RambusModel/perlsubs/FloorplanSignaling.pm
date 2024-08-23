#!/usr/local/bin/perl

package perlsubs::FloorplanSignaling;

# This package performs all operations specific to the section floorplansignaling

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
  datar => 1,
  dataw => 1,
  coladd => 1,
  rowadd => 1,
  bankadd => 1,
  control => 1,
  clock => 1,
  coreboundary => 1,
  );

sub check_core_boundary {

  # performs syntax check of key coreboundary

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # $key: key
  # $subkey: subkey
  # $value: value of subkey
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors
  
  my %valid_subkeys = (
    read => 1,
    write => 1,
    );

  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'floorplansignaling'.\n";
    }

  # Check values
  if (!($value =~ /^[0-9]+$/)) {
    $$errflag = 1;
    $$errstr .= "The value of subkey '$subkey' of key '$key' in section 'floorplansignaling' needs " .
      "to be a positive integer.\n";
    }
     
  }
  
sub check_signal_keys {

  # performs syntax check of keys datar, dataw, coladd, rowadd, bankadd,
  # control and clock

  # External variables
  my ($key, $subkey, $value, $errflag, $errstr) = @_;
  # $key: key
  # $subkey: subkey
  # $value: value of subkey
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors
  
  my %valid_subkeys = (
    direction => 1,
    start => 1,
    end => 1,
    inside => 1,
    fraction => 1,
    nchw => 1,
    pchw => 1,
    load => 1,
    mux => 1,
    swing => 1,
    toggle => 1,
    p_eff => 1,
    );
  
  # Check subkey
  if (!(exists $valid_subkeys{$subkey})) {
    $$errflag = 1;
    $$errstr .= "'$subkey' is not a valid subkey of key '$key' in section 'floorplansignaling'.\n";
    }

  # Values in this section are checked during evaluation

  }

sub get_signal {

  # Puts together data structure describing one signal
  
  # External variables
  my ($input, $key, $output, $errflag, $errstr, $verbose) = @_;
  # input: reference to hash with keys and values
  # key: key (e.g. datar)
  # output: reference to array of hashes describing signal
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  # find all entries belonging to the signal
  my %found_entries = ();
  my %numbers = ();
  foreach (sort keys %$input) {
    my $full_key = $_;
    if (/$key[0-9]+/) {
      s/floorplansignaling-$key//;
      $found_entries{$_} = $$input{$full_key};
      s/-.*//;
      $numbers{$_} = 1;
      }
    }
  
  # Check if entries with continuous numbering are available
  my @numbers = %numbers;
  my $max = ($#numbers + 1) / 2 - 1;
  foreach (my $seg=0;$seg<=$max;$seg++) {
    if (!(exists $numbers{$seg})) {
      $$errflag = 1;
      $$errstr .= "Section 'floorplansignaling': entries for key '$key" . $seg . "' are missing.\n";
      }
    }
  if ($errflag==1) { return; }
  
  # Put description of signal segments together
  for (my $seg=0;$seg<=$max;$seg++) {
    # Create key for lookup in input hash
    my $full_key = "floorplansignaling-" . $key . $seg;
    # Check if signal layout is described correctly and store if yes
    my $search = $full_key . "start";
    if ((exists $$input{$full_key . "-" . "start"})&&(exists $$input{$full_key . "-" . "end"})) {
      # Signal goes from one block to another
      $$output[$seg]{start} = $$input{$full_key . "-" . "start"};
      $$output[$seg]{end} = $$input{$full_key  . "-" . "end"};
      }
    elsif ((exists $$input{$full_key . "-" . "inside"})&&(exists $$input{$full_key . "-" . "fraction"})&&
      (exists $$input{$full_key . "-" . "direction"})) {
      # Signal is contained in one block
      $$output[$seg]{inside} = $$input{$full_key . "-" . "inside"};
      $$output[$seg]{fraction} = $$input{$full_key  . "-" . "fraction"};
      $$output[$seg]{direction} = $$input{$full_key . "-" . "direction"};
      }
    else {
      $$errflag = 1;
      $$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' requires either " .
        "'start' and 'end' or 'inside', 'fraction' and 'direction' to describe layout.\n";
      }
    if ($errflag==1) { return; }
    # Add information on buffers, multiplexing, swing and toggling if available
    if (exists $$input{$full_key . "-" . "nchw"})   { $$output[$seg]{nchw} =   $$input{$full_key . "-" . "nchw"}; }
    if (exists $$input{$full_key . "-" . "pchw"})   { $$output[$seg]{pchw} =   $$input{$full_key . "-" . "pchw"}; }
    if (exists $$input{$full_key . "-" . "mux"})    { $$output[$seg]{mux} =    $$input{$full_key . "-" . "mux"}; }
    if (exists $$input{$full_key . "-" . "swing"})  { $$output[$seg]{swing} =  $$input{$full_key . "-" . "swing"}; }
    if (exists $$input{$full_key . "-" . "toggle"}) { $$output[$seg]{toggle} = $$input{$full_key . "-" . "toggle"}; }
    if (exists $$input{$full_key . "-" . "load"})   { $$output[$seg]{load} =   $$input{$full_key . "-" . "load"}; }
    if (exists $$input{$full_key . "-" . "p_eff"})  { $$output[$seg]{p_eff} =  $$input{$full_key . "-" . "p_eff"}; }
    }
  
    
  }

sub draw_signal {
  
  # Creates coordinates for drawing of a signal as a continouous line in Excel
  # It also stores the length of the signal segments in the global signal description

  # External variables
  my ($key, $hc, $vc, $signal, $x, $y, $errflag, $errstr, $verbose) = @_;
  # key: key describing signal
  # hc: reference to array of horizontal block coordinates  
  # vc: reference to array of vertical block coordinates
  # signal: reference to signal description (array of hashes
  # with either a start / end pair or an inside / fraction
  # pair).
  # x: reference to array of x-ccordinates to draw the signal
  # y: reference to array of y-coordinates to draw the signal
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # To create a continuous line the segments always start and end in the center of a block.
  # For an inside segment that means that it has three parts (center to one side, to other
  # side and back to center).
  
  # Calculate points for all segments
  foreach (my $seg=0;$seg<=$#{$signal};$seg++) {
    
    if (exists $$signal[$seg]{start}) {
      # Block to block
      
      # Start
      my @blk_coords = split (/_/, $$signal[$seg]{start});
      if (($blk_coords[0]<0)||($blk_coords[0]+1>$#{$hc})) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' has block " .
          "number in start x which is not inside the physical floorplan.\n";
	return -1;
	}
      if (($blk_coords[1]<0)||($blk_coords[1]+1>$#{$vc})) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' has block " .
          "number in start y which is not inside the physical floorplan.\n";
        return -1;
	}
      my ($s1x, $s1y) = ($$hc[$blk_coords[0]], $$vc[$blk_coords[1]]);
      my ($s2x, $s2y) = ($$hc[$blk_coords[0]+1], $$vc[$blk_coords[1]+1]);
      my ($sx, $sy) = (($s1x+$s2x)/2, ($s1y+$s2y)/2);
      
      # End
      @blk_coords = split (/_/, $$signal[$seg]{end});
      if (($blk_coords[0]<0)||($blk_coords[0]+1>$#{$hc})) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' has block " .
          "number in end x which is not inside the physical floorplan.\n";
        return -1;
	}
      if (($blk_coords[1]<0)||($blk_coords[1]+1>$#{$vc})) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' has block " .
          "number in end y which is not inside the physical floorplan.\n";
        return -1;
	}
      my ($e1x, $e1y) = ($$hc[$blk_coords[0]], $$vc[$blk_coords[1]]);
      my ($e2x, $e2y) = ($$hc[$blk_coords[0]+1], $$vc[$blk_coords[1]+1]);
      my ($ex, $ey) = (($e1x+$e2x)/2, ($e1y+$e2y)/2);
      
      # Verify that orientation is either horizontal or vertical
      if (($sx!=$ex)&&($sy!=$ey)) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' is diagonal.\n";
        return -1;
	}
      
      # Add line segment to output and check that line is continuous
      if ($#{$x}>=0) {
        if (($$x[$#{$x}]!=$sx)||($$y[$#{$y}]!=$sy)) {
	  $$errflag = 1;
	  $$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' is not continuous to previous segment.\n";
        return -1;
	  }
        }
      else {
        push (@$x, $sx); push (@$y, $sy);
	}
      push (@$x, $ex); push (@$y, $ey);
      
      # Store length for later use in electrical section
      $$signal[$seg]{length} = sqrt(($ex - $sx)*($ex - $sx) + ($ey - $sy)*($ey - $sy));
      
      }

    else {
      # Inside block
      
      # Inside
      my @blk_coords = split (/_/, $$signal[$seg]{inside});
      if (($blk_coords[0]<0)||($blk_coords[0]+1>$#{$hc})) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' has block " .
          "number in inside x which is not inside the physical floorplan.\n";
        return -1;
	}
      if (($blk_coords[1]<0)||($blk_coords[1]+1>$#{$vc})) {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' has block " .
          "number in inside y which is not inside the physical floorplan.\n";
        return -1;
	}
      my ($c1x, $c1y) = ($$hc[$blk_coords[0]], $$vc[$blk_coords[1]]);
      my ($c2x, $c2y) = ($$hc[$blk_coords[0]+1], $$vc[$blk_coords[1]+1]);
      my ($cx, $cy) = (($c1x+$c2x)/2, ($c1y+$c2y)/2);
      
      # Fraction
      my $f = $$signal[$seg]{fraction};
      $f =~ s/\%$//;
      if ($f =~ /[0-9]+/) {
        if (($f<0)||($f>100)) {
	  $$errflag = 1;
	  $$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' fraction is not between 0% and 100%\n";
          return -1;
	  }
	}
      else {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' fraction is not between 0% and 100%\n";
        return -1;
	}

      # Calculate length of segment
      my $l = 0;
      if ($$signal[$seg]{direction} eq "h") {
        $l = ($c2x - $c1x) * $f/100;
	}
      elsif ($$signal[$seg]{direction} eq "v") {
        $l = ($c2y - $c1y) * $f/100;
	}
      else {
	$$errflag = 1;
	$$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' direction is not h or v\n";
        return -1;
	}

      # Add line segment to output and check that line is continuous
      if ($#{$x}>=0) {
        if (($$x[$#{$x}]!=$cx)||($$y[$#{$y}]!=$cy)) {
	  $$errflag = 1;
	  $$errstr .= "Section 'floorplansignaling': key '$key" . $seg . "' is not continuous to previous segment.\n";
          return -1;
	  }
        }
      else {
        push (@$x, $cx); push (@$y, $cy);
	}
      if ($$signal[$seg]{direction} eq "h") {
        push (@$x, $cx-$l/2); push (@$y, $cy);
        push (@$x, $cx+$l/2); push (@$y, $cy);
        push (@$x, $cx); push (@$y, $cy);
	}
      else {
        push (@$x, $cx); push (@$y, $cy-$l/2);
        push (@$x, $cx); push (@$y, $cy+$l/2);
        push (@$x, $cx); push (@$y, $cy);
	}

      # Store length for later use in electrical section
      $$signal[$seg]{length} = $l;
      
      }
    
    }
    
  # Shift signals if they overlap in the same direction so that the attach at the ends
  for (my $i=4;$i<=$#{$x};$i++) {
    # check for vertical overlap with previous
    if (($$x[$i-4]==$$x[$i-3])&&($$x[$i-3]==$$x[$i-2])&&($$x[$i-2]==$$x[$i-1])&&($$x[$i-1]==$$x[$i])) {
      if ($$y[$i-4]==$$y[$i-1]) {
        my $l = abs($$y[$i-3] - $$y[$i-2]);
	if ($$y[$i]<=$$y[$i-1]) {
	  # next line is down, shift previous line up
	  $$y[$i-3] = $$y[$i-4] + $l/2;
	  $$y[$i-2] = $$y[$i-4] + $l;
	  }
	else {
	  # next line is up, shift previous line down
	  $$y[$i-3] = $$y[$i-4] - $l/2;
	  $$y[$i-2] = $$y[$i-4] - $l;
	  }
	}
      if ($$y[$i-3]==$$y[$i]) {
        my $l = abs($$y[$i-2] - $$y[$i-1]);
	if ($$y[$i-4]<=$$y[$i-3]) {
	  # next line is down, shift previous line up
	  $$y[$i-2] = $$y[$i-3] + $l/2;
	  $$y[$i-1] = $$y[$i-3] + $l;
	  }
	else {
	  # next line is up, shift previous line down
	  $$y[$i-2] = $$y[$i-3] - $l/2;
	  $$y[$i-1] = $$y[$i-3] - $l;
	  }
	}
      }
    # check for horizontal overlap with previous
    if (($$y[$i-4]==$$y[$i-3])&&($$y[$i-3]==$$y[$i-2])&&($$y[$i-2]==$$y[$i-1])&&($$y[$i-1]==$$y[$i])) {
      if ($$x[$i-4]==$$x[$i-1]) {
        my $l = abs($$x[$i-3] - $$x[$i-2]);
	if ($$x[$i]<=$$x[$i-1]) {
	  # next line is left, shift previous line to right
	  $$x[$i-3] = $$x[$i-4] + $l/2;
	  $$x[$i-2] = $$x[$i-4] + $l;
	  }
	else {
	  # next line is right, shift previous line to left
	  $$x[$i-3] = $$x[$i-4] - $l/2;
	  $$x[$i-2] = $$x[$i-4] - $l;
	  }
	}
      if ($$x[$i-3]==$$x[$i]) {
        my $l = abs($$x[$i-2] - $$x[$i-1]);
	if ($$x[$i-4]<=$$x[$i-3]) {
	  # next line is left, shift previous line to right
	  $$x[$i-2] = $$x[$i-3] + $l/2;
	  $$x[$i-1] = $$x[$i-3] + $l;
	  }
	else {
	  # next line is right, shift previous line to left
	  $$x[$i-2] = $$x[$i-3] - $l/2;
	  $$x[$i-1] = $$x[$i-3] - $l;
	  }
	}
      }
    }
  
  # Additional output
  if ($verbose) {

    # Add up total length
    my $total_length = 0;
    foreach (my $seg=0;$seg<=$#{$signal};$seg++) { $total_length += $$signal[$seg]{length}; }

    # Print total length
    printf "Signal '$key' has a total length of %.0fum\n", $total_length;

    }
  
  }

sub FloorplanSignaling::check_syntax {

  # Performs syntax checking in section FloorplanSignaling
  
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
    if ($_ eq "coreboundary") {
      }
    elsif (!($_ =~ /[0-9]+$/)) {
      $$errflag = 1;
      $$errstr .= "'" . $_ . "' is not a valid key in section 'floorplansignaling'.\n" .
        "It needs to end with a number\n";
      }
    else {
      my $key_stem = $_;
      $key_stem =~ s/[0-9]+$//;
      if (!(exists $valid_keys{$key_stem})) {
	$$errflag = 1;
	$$errstr .= "'" . $_ . "' is not a valid key in section 'floorplansignaling'.\n";
	}
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
    if ($key eq "coreboundary") {
      check_core_boundary ($key, $subkey, $value, $errflag, $errstr);
      }
    elsif (exists $valid_keys{$key_stem}) {
      check_signal_keys ($key, $subkey, $value, $errflag, $errstr);
      }
      
    }
  
  }

sub FloorplanSignaling::set_floorplan_variables {

  # Performs syntax checking in section FloorplanSignaling
  
  # External variables
  my ($input, $data_r, $data_w, $coladd, $rowadd,
    $bankadd, $control, $clock, $coreboundary_read, $coreboundary_write,
    $errflag, $errstr, $verbose) = @_ ;
  # input: reference to hash with keys and values
  # data_r, data_w, coladd, rowadd,
  # bankadd, control, clock: references to arrays
  # of hashes with either a start / end pair or an inside / fraction
  # pair, the buffer values as defined in the input file and the swing and toggle.
  # coreboundary_read/write: last respectively first segment number for data path read and write 
  # which is considered part of the core when assigning currents to location
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output

  # Create list of used keys
  my %used_keys = ();
  my %numbers = ();
  foreach (sort keys %$input) {
    if (/floorplansignaling/) {
      s/floorplansignaling-//;
      s/-.*$//;
      s/[0-9]+//;
      $used_keys{$_} = 1;
      }
    };
  
  # Additional output
  if ($verbose) {
    print "\nSignaling floorplan:\n";
    }

  # Set return variables
  if (exists $used_keys{datar})    { get_signal ($input, "datar",   $data_r,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{dataw})    { get_signal ($input, "dataw",   $data_w,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{coladd})   { get_signal ($input, "coladd",  $coladd,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{rowadd})   { get_signal ($input, "rowadd",  $rowadd,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{bankadd})  { get_signal ($input, "bankadd", $bankadd, $errflag, $errstr, $verbose); }
  if (exists $used_keys{control})  { get_signal ($input, "control", $control, $errflag, $errstr, $verbose); }
  if (exists $used_keys{clock})    { get_signal ($input, "clock",   $clock,   $errflag, $errstr, $verbose); }
  
  my $data_write_max = -1;
  if ($#{$data_w}>=0) {
    $data_write_max = $#{$data_w};
    }
  else {
    $$errflag = 1;
    $$errstr .= "Error in specification of write data path in section 'floorplansignaling'.\n";
    return -1;
    }
  my $data_read_max = -1;
  if ($#{$data_r}>=0) {
    $data_read_max = $#{$data_r};
    }
  else {
    $$errflag = 1;
    $$errstr .= "Error in specification of read data path in section 'floorplansignaling'.\n";
    return -1;
    }

  if (exists $$input{"floorplansignaling-coreboundary-read"}) {
    $$coreboundary_read = $$input{"floorplansignaling-coreboundary-read"};
    }
  else {
    $$coreboundary_read = 0;
    }
  if (exists $$input{"floorplansignaling-coreboundary-write"}) {
    $$coreboundary_write = $$input{"floorplansignaling-coreboundary-write"};
    }
  else {
    $$coreboundary_write = $data_write_max;
    }
  if (($$coreboundary_read<0)||($$coreboundary_read>$data_read_max)) {
    $$errflag = 1;
    $$errstr .= "'coreboundary read' out of range in section 'floorplansignaling'.\n";
    }
  if (($$coreboundary_write<0)||($$coreboundary_write>$data_write_max)) {
    $$errflag = 1;
    $$errstr .= "'coreboundary write' out of range in section 'floorplansignaling'.\n";
    }

  }

sub FloorplanSignaling::draw_floorplan {

  # Creates text files with coordinates to be used in Excel
  # to draw signaling floorplan of the die.
  # It is assumed that the description of the DRAM is
  # syntactically correct.
  
  # External variables
  my ($output_name, $input, $hc, $vc,
    $data_r, $data_w, $coladd, $rowadd,
    $bankadd, $control, $clock, $errflag, $errstr, $verbose) = @_ ;
  # input: reference to hash with keys and values
  # output_name: file name of output file;
  # hc: reference to array of coordinates of blocks in horizontal direction
  # vc: reference to array of coordinates of blocks invertical direction
  # data_r, data_w, coladd, rowadd,
  # bankadd, control, clock: references to arrays
  # of hashes with either a start / end pair or an inside / fraction
  # pair, the buffer values as defined in the input file and the swing and toggle.
  # errflag: set if error(s) occurs
  # errstr: verbal description of errors
  # verbose: flag for verbose output
  
  # Variables
  my @data_r_x = ();
  my @data_w_x = ();
  my @coladd_x = ();
  my @rowadd_x = ();
  my @bankadd_x = ();
  my @control_x = ();
  my @clock_x = ();
  my @data_r_y = ();
  my @data_w_y = ();
  my @coladd_y = ();
  my @rowadd_y = ();
  my @bankadd_y = ();
  my @control_y = ();
  my @clock_y = ();

  # Write file for export to Excel
  if (!(open (OUTPUT, ">" . $output_name))) {
    $$errflag = 1;
    $$errstr .= "Output file $output_name to export signaling floorplan to Excel could not be opened.\n";
    return;
    }

  # Create list of used keys
  my %used_keys = ();
  my %numbers = ();
  foreach (sort keys %$input) {
    if (/floorplansignaling/) {
      s/floorplansignaling-//;
      s/-.*$//;
      s/[0-9]+//;
      $used_keys{$_} = 1;
      }
    };
  
  # Create signal coordinate arrays
  if (exists $used_keys{datar})   { draw_signal ("datar",   $hc, $vc, $data_r,  \@data_r_x,  \@data_r_y,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{dataw})   { draw_signal ("dataw",   $hc, $vc, $data_w,  \@data_w_x,  \@data_w_y,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{coladd})  { draw_signal ("coladd",  $hc, $vc, $coladd,  \@coladd_x,  \@coladd_y,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{rowadd})  { draw_signal ("rowadd",  $hc, $vc, $rowadd,  \@rowadd_x,  \@rowadd_y,  $errflag, $errstr, $verbose); }
  if (exists $used_keys{bankadd}) { draw_signal ("bankadd", $hc, $vc, $bankadd, \@bankadd_x, \@bankadd_y, $errflag, $errstr, $verbose); }
  if (exists $used_keys{control}) { draw_signal ("control", $hc, $vc, $control, \@control_x, \@control_y, $errflag, $errstr, $verbose); }
  if (exists $used_keys{clock})   { draw_signal ("clock",   $hc, $vc, $clock,   \@clock_x,   \@clock_y,   $errflag, $errstr, $verbose); }
  
  # Find longest coordinate array and number of coordinate arrays
  my $number_of_lines = 0;
  if (exists $used_keys{datar})   { if ($#data_r_x  > $number_of_lines) { $number_of_lines = $#data_r_x;  }}
  if (exists $used_keys{dataw})   { if ($#data_w_x  > $number_of_lines) { $number_of_lines = $#data_w_x;  }}
  if (exists $used_keys{coladd})  { if ($#coladd_x  > $number_of_lines) { $number_of_lines = $#coladd_x;  }}
  if (exists $used_keys{rowadd})  { if ($#rowadd_x  > $number_of_lines) { $number_of_lines = $#rowadd_x;  }}
  if (exists $used_keys{bankadd}) { if ($#bankadd_x > $number_of_lines) { $number_of_lines = $#bankadd_x; }}
  if (exists $used_keys{control}) { if ($#control_x > $number_of_lines) { $number_of_lines = $#control_x; }}
  if (exists $used_keys{clock})   { if ($#clock_x   > $number_of_lines) { $number_of_lines = $#clock_x;   }}

  # Write output file

  # Write header
  my $line = "";
  if (exists $used_keys{datar})   { $line .= "datar_x\tdatar_y\t";     }
  if (exists $used_keys{dataw})   { $line .= "dataw_x\tdataw_y\t";     }
  if (exists $used_keys{coladd})  { $line .= "coladd_x\tcoladd_y\t";   }
  if (exists $used_keys{rowadd})  { $line .= "rowadd_x\trowadd_y\t";   }
  if (exists $used_keys{bankadd}) { $line .= "bankadd_x\tbankadd_y\t"; }
  if (exists $used_keys{control}) { $line .= "control_x\tcontrol_y\t"; }
  if (exists $used_keys{clock})   { $line .= "clock_x\tclock_y\t";     }
  $line =~ s/\t$/\n/;
  print OUTPUT $line;
  
  # Write body
  for (my $i=0;$i<=$number_of_lines;$i++) {
    my @numbers = ();
    # data_r
    if (exists $used_keys{datar}) { if ($i <= $#data_r_x) { push (@numbers, $data_r_x[$i]);  push (@numbers, $data_r_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    # data_w
    if (exists $used_keys{dataw}) { if ($i <= $#data_w_x) { push (@numbers, $data_w_x[$i]);  push (@numbers, $data_w_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    # coladd
    if (exists $used_keys{coladd}) { if ($i <= $#coladd_x) { push (@numbers, $coladd_x[$i]);  push (@numbers, $coladd_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    # rowadd
    if (exists $used_keys{rowadd}) { if ($i <= $#rowadd_x) { push (@numbers, $rowadd_x[$i]);  push (@numbers, $rowadd_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    # bankadd
    if (exists $used_keys{bankadd}) { if ($i <= $#bankadd_x) { push (@numbers, $bankadd_x[$i]);  push (@numbers, $bankadd_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    # control
    if (exists $used_keys{control}) { if ($i <= $#control_x) { push (@numbers, $control_x[$i]);  push (@numbers, $control_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    # clock
    if (exists $used_keys{clock}) { if ($i <= $#clock_x) { push (@numbers, $clock_x[$i]);  push (@numbers, $clock_y[$i]); }
      else { push (@numbers, ""); push (@numbers, ""); } }
    my $line = "";
    foreach (@numbers) {
      $line .= "$_\t";
      }
    $line =~ s/\t$/\n/;
    print OUTPUT $line;
    }
  
  # Close file
  close OUTPUT;

  }

# Return 1 at end of package file
1;
