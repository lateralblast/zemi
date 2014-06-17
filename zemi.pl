#!/usr/bin/perl

# Name:         zemi (ZFS Enabled Memory Information)
# Version:      1.0.5
# Release:      1
# License:      CC-BA (Creative Commons By Attrbution)
#               http://creativecommons.org/licenses/by/4.0/legalcode
# Group:        System
# Source:       freemem.pl
# URL:          https://github.com/richardatlateralblast/freemem/blob/master/freemem.pl
# Distribution: Solaris
# Vendor:       UNIX
# Packager:     Richard Spindler <richard.spindler@lateralblast.com.au>
# Description:  Free memory script which takes ZFS ARC cache into account

use strict;
use Getopt::Std;

my $script_name    = $0;
my $script_version = `cat $script_name | grep '^# Version' |awk '{print \$3}'`;
my %option         = getopts("vVhpZz",\%option);

# If given -h print usage

if ($option{'h'}) {
  print_usage();
  exit;
}

sub print_usage {
  print "\n";
  print "Usage: $script_name -[v|h|V|p|z|Z]\n";
  print "\n";
  print "-V: Print version information\n";
  print "-v: Verbose output\n";
  print "-h: Print help\n";
  print "-p: Return percentage memory used (without %)\n";
  print "    (useful for monitoring)\n";
  print " Z: Ignore ZFS ARC cache (default for machines without ZFS)\n";
  print " z: Running in a zone (default for non global zone)\n";
  print "\n";
  return;
}

sub print_version {
  print "$script_version";
  return;
}

# Print script version

if ($option{'V'}) {
  print_version();
  exit;
}

# Check environment

check_env();

# Calculate actual memory

get_actual_free_mem();

# If run from a zone prstat is used to calculate available memory

sub process_prstat {

  # Process prstat output, grabbing fourth field:
  # ZONEID    NPROC  SWAP   RSS MEMORY      TIME  CPU ZONE
  # 0         92     355M  314M    15%   1:33:37 0.1% global

  my $prstat_info = `prstat -Z 1 1 |tail -2 |head -1`;
  my @values      = split(" ",$prstat_info);
  my $vms_mem     = $values[3];

  if ($vms_mem =~ /G/) {
    $vms_mem =~ s/[A-z]//g;
    $vms_mem = $vms_mem*1024;
  }
  else {
    $vms_mem =~ s/[A-z]//g;
  }
  return($vms_mem);
}

# Calculate actual memory

sub get_actual_free_mem {

  my $arc_min;
  my $arc_max;
  my $arc_now;
  my $vms_mem;
  my $sys_mem;
  my $act_mem;
  my $act_per;
  my $vms_per;
  my $release_check = `cat /etc/release |head -1`;

  # Add some handling for zones where memory available is
  # coming back as total system memory

  # If for some reason we get vmstat view of memory
  # being greater than actual, or we are running in
  # a zone, process prstat information

  $vms_mem = get_vms_mem();
  $sys_mem = get_sys_mem();
  if (!$option{'Z'}) {
    ($arc_min,$arc_max,$arc_now) = get_arc_inf();
    $act_mem = $arc_now-$arc_min+$vms_mem;
  }
  else {
    $act_mem = $vms_mem;
  }
  $act_per = sprintf '%.0f',100-(($act_mem/$sys_mem)*100);
  $vms_per = sprintf '%.0f',100-(($vms_mem/$sys_mem)*100);
  chomp($release_check);

  # Handling of memory in zones

  if (($vms_mem > $sys_mem)||($option{'z'})) {

    # Use prstat if available as this is more reliable for zones
    # Handle different prstat outputs on different releases

    if (-e "/usr/bin/prstat") {
      if ($release_check =~ /8\/11|10\/08|5\/09/) {
        $vms_mem = process_prstat();
        $vms_per = sprintf '%.0f',100-(($vms_mem/$sys_mem)*100);
      if (($arc_min > $sys_mem)||($act_per < 0)) {
          $act_mem = $vms_mem;
          $act_per = sprintf '%.0f',100-(($act_mem/$sys_mem)*100);
        }
      }
      else {
        $vms_mem = process_prstat();
        $vms_per = sprintf '%.0f',($vms_mem/$sys_mem)*100;
      }
    }

    # Support for when system has gone below min ARC cache
    # or we are not using ZFS

    if (($act_mem < 0)&&(!$option{'Z'})) {
      $act_mem = $vms_mem+$arc_now;
      $act_per = sprintf '%.0f',100-(($act_mem/$sys_mem)*100);
    }

    # Handle where the current ARC cache has dropped below min

    if ((!$option{'Z'})&&($arc_now < $arc_min)) {
      $act_mem = $vms_mem+$arc_now;
      $act_per = sprintf '%.0f',100-(($act_mem/$sys_mem)*100);
    }
  }
  else {

    # Handle global zone with ZFS

    if (($vms_mem > $act_mem)&&(!$option{'Z'})) {
      $act_mem = $vms_mem+$arc_now;
      $act_per = sprintf '%.0f',100-(($act_mem/$sys_mem)*100);
    }
  }

  # If given -v be verbose
  # Add processing for ZFS ARC cache if needed

  if ($option{'v'}) {
    print "System Memory: $sys_mem MB\n";
    if (!$option{'Z'}) {
      print "ARC Cache Now: $arc_now MB\n";
      print "ARC Cache Min: $arc_min MB\n";
      print "ARC Cache Max: $arc_max MB\n";
    }
    print "vmstat Free:   $vms_mem MB\n";
    if ($option{'Z'}) {
      print "Actual Free:   $vms_mem MB\n";
    }
    else {
      print "Actual Free:   $act_mem MB\n";
    }
    print "vmstat Usage:  $vms_per %\n";
    if ($option{'Z'}) {
      print "Actual Usage:  $vms_per %\n";
    }
    else {
      print "Actual Usage:  $act_per %\n";
    }
  }

  # If given -p display percentage memory used
  # Add processing for ZFS ARC cache if needed

  if ($option{'p'}) {
    if ($option{'Z'}) {
      print "$vms_per\n";
    }
    else {
      print "$act_per\n";
    }
  }
  return;
}

# Check environment

sub check_env {

  # Do some OS release checks
  # If we are on Solaris 10 and ZFS is being used set -Z by default
  # If we are on Solaris 10 and running in a zone set -z by default

  my $os_check = `uname -a`;
  my $zone_check;

  # Check we are running on Solaris

  if ($os_check !~ /SunOS/) {
    print "This script will only run on Solaris\n";
    exit;
  }

  # Check if running on Solaris 10, if not disable zone support

  if ($os_check !~ /5\.10|5\.11/) {
    if ($option{'v'}) {
      print "This does not appear to be Solaris 10 or 11\n";
      print "Disabling ZFS support\n";
    }
    $option{'Z'} = 1;
  }
  else {
    $zone_check = `/usr/bin/zonename`;
    chomp($zone_check);
    if ($zone_check !~ /^global$/) {
      if ($option{'v'}) {
        print "Running in a non global zone\n";
      }
      $option{'z'} = 1;
    }
    if (! -e "/usr/sbin/zfs") {
      if ($option{'v'}) {
        print "This does not appear to be Solaris 10 or 11\n";
        print "Disabling ZFS support\n";
      }
      $option{'Z'} = 1;
    }
    else {

      # Check whether we have any ZFS filesystems mounted
      # If no ZFS filesystems are mounted ZFS cache is not used

      $os_check = `cat /etc/mnttab |grep zfs`;
      chomp($os_check);
      if ($os_check !~ /zfs/) {
        if ($option{'v'}) {
          print "No ZFS file systems\n";
          print "Disabling ZFS support\n";
        }
        $option{'Z'} = 1;
      }
    }
  }
}

# If running on a machine with ZFS get ARC cache information
# Return the min, max and actual memory used
# Example output:
#        c_max                           1572526080
#        c_min                           196565760
#        size                            425138704


sub get_arc_inf {

  my @arc_inf = `/usr/bin/kstat -m zfs |egrep 'c_|size' |grep -v '_size' |awk '{print \$2}'`;
  my $arc_min = $arc_inf[1];
  my $arc_max = $arc_inf[0];
  my $arc_now = $arc_inf[2];

  chomp($arc_min);
  chomp($arc_max);
  chomp($arc_now);
  $arc_min = sprintf '%.0f',$arc_min/(1024*1024);
  $arc_max = sprintf '%.0f',$arc_max/(1024*1024);
  $arc_now = sprintf '%.0f',$arc_now/(1024*1024);
  return($arc_min,$arc_max,$arc_now);
}

# Get the total system/zone memory

sub get_sys_mem {

  # prtconf can be run from a zone, but need to handle stderr

  my $sys_mem    = `/usr/sbin/prtconf 2>&1 |grep Memory |cut -f2 -d":"`;
  my @values     = split(' ',$sys_mem);
  my $multiplier = 1;

  # System memory is generally returned in MB
  # so multiply by 1024 to get memory in KB

  if ($values[1] =~ /Gigabyte/) {
    $multiplier = 1024;
  }
  $sys_mem = $values[0]*$multiplier;
  return($sys_mem);
}

# Get free memory from sar or vmstat

sub get_vms_mem {

  my $vms_mem;
  my $page_size;

  # If sar is present use it instead of vmstat
  # as it seems to be a little more accurate

  if (-e "/usr/bin/sar") {
    $vms_mem   = `sar -r 1 1 |tail -1 |awk '{print \$2}'`;
    $page_size = `/usr/bin/pagesize`;
    chomp($page_size);
    $page_size = $page_size/1024;
    $vms_mem   = $vms_mem*$page_size;
  }
  else {
    $vms_mem = `/usr/bin/vmstat |tail -1 |awk '{print \$5}'`;
  }
  chomp($vms_mem);
  $vms_mem = sprintf '%.0f',$vms_mem/1024;
  return($vms_mem);
}
