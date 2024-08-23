#!/usr/local/bin/perl

package perlsubs::Syntax;

# This package contains subroutines to check the syntax of the description
# of a DRAM. It requires that the input file has been parsed and stored in
# a hash by the parser subroutine.

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

use FloorplanPhysical;
use FloorplanSignaling;
use Specification;
use Technology;
use BasicElectrical;
use Periphery;
use GlobalLoop;

# Global variables

# Legal sections
my %sections = (
  technology => 1,
  basicelectrical => 1,
  floorplanphysical => 1,
  floorplansignaling => 1,
  periphery => 1,
  specification => 1,
  globalloop => 1,
  );

sub Syntax::check_syntax {

  # Performs syntax checking of sections, keys and values
  # The input is a hash created by the parser subroutine
  # with each hash pair having the format corresponding
  # to a Perl assignment
  # <section>-<key>-<subkey> => <value>
  
  # External variables
  my ($input, $errflag, $errstr) = @_;
  # $input: reference to hash with keys and values
  # $errflag: set if error(s) occurs
  # $errstr: verbal description of errors
  
  # Initialize
  $$errflag = 0;
  $$errstr = "";
  
  # Create list of all used section names
  my %found_sections = ();
  foreach (sort keys %$input) {
    my @words = split (/-/, $_);
    $found_sections{$words[0]} = 1;
    }
    
  # Check if there are not valid section names
  foreach (sort keys %found_sections) {
    if (!(exists $sections{$_})) {
      $$errflag = 1;
      if ($_ eq "none") {
        # The parser sets the section to none if a key-subkey pair is defined
	# before the first section header
        $$errstr = "A section must be defined before key-subkey pairs.\n";
        }
      else {
        $$errstr .= "'" . $_ . "' is not a valid section name.\n";
	}
      }
    }
  # Abort if there are not valid sections as further syntax checking will
  # be of limited use.
  if ($$errflag==1) { return -1; }
  
  # Check syntax of floorplanphysical section
  if (exists $found_sections{floorplanphysical}) {
    # Create hash only for section floorplanphysical
    my %floorplanphysical = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^floorplanphysical-/) {
        $key =~ s/floorplanphysical-//;
        $floorplanphysical{$key} = $$input{$_};
	}
      }
    FloorplanPhysical::check_syntax (\%floorplanphysical, \$$errflag, \$$errstr);
    }
  
  # Check syntax of floorplansignaling section
  if (exists $found_sections{floorplansignaling}) {
    # Create hash only for section floorplansignaling
    my %floorplansignaling = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^floorplansignaling-/) {
        $key =~ s/floorplansignaling-//;
        $floorplansignaling{$key} = $$input{$_};
	}
      }
    FloorplanSignaling::check_syntax (\%floorplansignaling, \$$errflag, \$$errstr);
    }
  
  # Check syntax of specification section
  if (exists $found_sections{specification}) {
    # Create hash only for section specification
    my %specification = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^specification-/) {
        $key =~ s/specification-//;
        $specification{$key} = $$input{$_};
	}
      }
    Specification::check_syntax (\%specification, \$$errflag, \$$errstr);
    }
  
  # Check syntax of technology section
  if (exists $found_sections{technology}) {
    # Create hash only for section technology
    my %technology = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^technology-/) {
        $key =~ s/technology-//;
        $technology{$key} = $$input{$_};
	}
      }
    Technology::check_syntax (\%technology, \$$errflag, \$$errstr);
    }
  
  # Check syntax of basicelectrical section
  if (exists $found_sections{basicelectrical}) {
    # Create hash only for section basicelectrical
    my %basicelectrical = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^basicelectrical-/) {
        $key =~ s/basicelectrical-//;
        $basicelectrical{$key} = $$input{$_};
	}
      }
    BasicElectrical::check_syntax (\%basicelectrical, \$$errflag, \$$errstr);
    }
  
 
  # Check syntax of periphery section
  if (exists $found_sections{periphery}) {
    # Create hash only for section periphery
    my %periphery = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^periphery-/) {
        $key =~ s/periphery-//;
        $periphery{$key} = $$input{$_};
	}
      }
    Periphery::check_syntax (\%periphery, \$$errflag, \$$errstr);
    }
  
  # Check syntax of globalloop section
  if (exists $found_sections{globalloop}) {
    # Create hash only for section globalloop
    my %globalloop = ();
    foreach (sort keys %$input) {
      my $key = $_;
      if ($key  =~ /^globalloop-/) {
        $key =~ s/globalloop-//;
        $globalloop{$key} = $$input{$_};
	}
      }
    GlobalLoop::check_syntax (\%globalloop, \$$errflag, \$$errstr);
    }
  
  }
  
# Return 1 at end of package file
1;
