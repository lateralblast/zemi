#!/usr/bin/perl

# Name:         zemi (ZFS Enabled Memory Information)
# Version:      1.2.1
# Release:      1
# License:      CC BY-NC-SA 4.0 (Creative Commons Attribution-NonCommercial-ShareAlike)
#               http://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
# Group:        System
# Source:       freemem.pl
# URL:          https://github.com/richardatlateralblast/freemem/blob/master/freemem.pl
# Distribution: Solaris
# Vendor:       UNIX
# Packager:     Richard Spindler <richard.spindler@lateralblast.com.au>
# Description:  Free memory script which takes ZFS ARC cache into account


use strict;
use warnings;
use Getopt::Std;
use POSIX qw(uname);

my $script_name  = $0;
my $release_file = '/etc/release';
my $mnttab_file  = '/etc/mnttab';
my $zonename_cmd = '/usr/bin/zonename';
my $zfs_cmd      = '/usr/sbin/zfs';
my $kstat_cmd    = '/usr/bin/kstat';
my $prtconf_cmd  = '/usr/sbin/prtconf';
my $prstat_cmd   = '/usr/bin/prstat';
my $sar_cmd      = '/usr/bin/sar';
my $vmstat_cmd   = '/usr/bin/vmstat';
my $pagesize_cmd = '/usr/bin/pagesize';
my %option;

# Run a command and return its output, or an empty string on failure

sub run_cmd {
  my ($cmd) = @_;
  my $output = `$cmd`;
  return defined $output ? $output : '';
}

# Return the first line of a file, or an empty string if it can't be read

sub read_first_line {
  my ($file) = @_;
  my $line = '';
  if (open(my $fh,'<',$file)) {
    $line = <$fh>;
    close($fh);
  }
  $line = '' if !defined $line;
  chomp($line);
  return $line;
}

# Return the percentage of total memory in use, given free memory

sub pct_used {
  my ($free,$total) = @_;
  return sprintf '%.0f',100-(($free/$total)*100);
}

# Read the version from the script header

sub get_version {
  my $version = "unknown";
  if (open(my $fh,'<',$0)) {
    while (my $line = <$fh>) {
      if ($line =~ /^# Version:\s+(\S+)/) {
        $version = $1;
        last;
      }
    }
    close($fh);
  }
  return "$version\n";
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
  print "-Z: Ignore ZFS ARC cache (default for machines without ZFS)\n";
  print "-z: Running in a zone (default for non global zone)\n";
  print "\n";
  return;
}

sub print_version {
  print get_version();
  return;
}

# Check environment
#
# Do some OS release checks
# If we are not on Solaris 10 or 11 set -Z (no ZFS) by default
# If we are in a non global zone set -z by default

sub check_env {
  my ($sysname,undef,$release) = uname();

  # Check we are running on Solaris

  if ($sysname ne 'SunOS') {
    print "This script will only run on Solaris\n";
    exit 1;
  }

  # Check if running on Solaris 10 or 11, if not disable ZFS and zone support

  if ($release !~ /^5\.1[01]$/) {
    if ($option{'v'}) {
      print "This does not appear to be Solaris 10 or 11\n";
      print "Disabling ZFS and zone support\n";
    }
    $option{'Z'} = 1;
    return;
  }
  my $zone_check = run_cmd($zonename_cmd);
  chomp($zone_check);
  if ($zone_check ne 'global') {
    if ($option{'v'}) {
      print "Running in a non global zone\n";
    }
    $option{'z'} = 1;
  }
  if (! -x $zfs_cmd) {
    if ($option{'v'}) {
      print "ZFS is not installed\n";
      print "Disabling ZFS support\n";
    }
    $option{'Z'} = 1;
    return;
  }

  # Check whether we have any ZFS filesystems mounted
  # If no ZFS filesystems are mounted ZFS cache is not used

  my $has_zfs = 0;
  if (open(my $fh,'<',$mnttab_file)) {
    while (my $line = <$fh>) {
      if ($line =~ /zfs/) {
        $has_zfs = 1;
        last;
      }
    }
    close($fh);
  }
  if (!$has_zfs) {
    if ($option{'v'}) {
      print "No ZFS file systems\n";
      print "Disabling ZFS support\n";
    }
    $option{'Z'} = 1;
  }
  return;
}

# Get a ZFS ARC cache statistic in MB
# Example output of kstat -p zfs:0:arcstats:size:
# zfs:0:arcstats:size     425138704

sub get_arc_stat {
  my ($name) = @_;
  my $output = run_cmd("$kstat_cmd -p zfs:0:arcstats:$name");
  my @values = split(' ',$output);
  my $bytes  = @values ? $values[-1] : 0;
  return sprintf '%.0f',$bytes/(1024*1024);
}

# If running on a machine with ZFS get ARC cache information
# Return the min, max and actual memory used

sub get_arc_inf {
  my $arc_min = get_arc_stat('c_min');
  my $arc_max = get_arc_stat('c_max');
  my $arc_now = get_arc_stat('size');
  return($arc_min,$arc_max,$arc_now);
}

# Get the total system/zone memory in MB

sub get_sys_mem {

  # prtconf can be run from a zone, but need to handle stderr

  my $output     = run_cmd("$prtconf_cmd 2>&1");
  my $multiplier = 1;
  my $sys_mem    = 0;

  # System memory is generally returned in MB
  # so multiply to convert larger units to MB

  if ($output =~ /Memory size:\s*([0-9.]+)\s*(\w+)/) {
    $sys_mem = $1;
    if ($2 =~ /Terabyte/) {
      $multiplier = 1024*1024;
    }
    elsif ($2 =~ /Gigabyte/) {
      $multiplier = 1024;
    }
  }
  return $sys_mem*$multiplier;
}

# Get free memory in MB from sar or vmstat

sub get_vms_mem {
  my $vms_mem = 0;

  # If sar is present use it instead of vmstat
  # as it seems to be a little more accurate

  if (-x $sar_cmd) {
    my @lines     = split(/\n/,run_cmd("$sar_cmd -r 1 1"));
    my @values    = split(' ',$lines[-1] || '');
    my $page_size = run_cmd($pagesize_cmd);
    chomp($page_size);

    # Free memory is in pages, convert to KB

    $vms_mem = ($values[1] || 0)*(($page_size || 0)/1024);
  }
  else {
    my @lines  = split(/\n/,run_cmd($vmstat_cmd));
    my @values = split(' ',$lines[-1] || '');
    $vms_mem   = $values[4] || 0;
  }
  return sprintf '%.0f',$vms_mem/1024;
}

# If run from a zone prstat is used to calculate memory in use in MB

sub process_prstat {

  # Process prstat output, grabbing fourth field:
  # ZONEID    NPROC  SWAP   RSS MEMORY      TIME  CPU ZONE
  # 0         92     355M  314M    15%   1:33:37 0.1% global

  my @lines      = split(/\n/,run_cmd("$prstat_cmd -Z 1 1"));
  my @values     = split(' ',(@lines > 1) ? $lines[-2] : '');
  my $vms_mem    = defined $values[3] ? $values[3] : 0;
  my $multiplier = 1;

  if ($vms_mem =~ /T/) {
    $multiplier = 1024*1024;
  }
  elsif ($vms_mem =~ /G/) {
    $multiplier = 1024;
  }
  elsif ($vms_mem =~ /K/) {
    $multiplier = 1/1024;
  }
  $vms_mem =~ s/[^0-9.]//g;
  $vms_mem = 0 if $vms_mem eq '';
  return $vms_mem*$multiplier;
}

# Calculate actual memory

sub get_actual_free_mem {
  my ($arc_min,$arc_max,$arc_now) = (0,0,0);
  my $release_check = read_first_line($release_file);
  my $vms_mem       = get_vms_mem();
  my $sys_mem       = get_sys_mem();
  my $act_mem;

  if (!$sys_mem) {
    print "Unable to determine system memory\n";
    exit 1;
  }
  if (!$option{'Z'}) {
    ($arc_min,$arc_max,$arc_now) = get_arc_inf();
    $act_mem = $arc_now-$arc_min+$vms_mem;
  }
  else {
    $act_mem = $vms_mem;
  }
  my $act_per = pct_used($act_mem,$sys_mem);
  my $vms_per = pct_used($vms_mem,$sys_mem);

  # Add some handling for zones where memory available is
  # coming back as total system memory

  # If for some reason we get vmstat view of memory
  # being greater than actual, or we are running in
  # a zone, process prstat information

  if (($vms_mem > $sys_mem)||($option{'z'})) {

    # Use prstat if available as this is more reliable for zones
    # Handle different prstat outputs on different releases

    if (-x $prstat_cmd) {
      if ($release_check =~ /8\/11|10\/08|5\/09/) {
        $vms_mem = process_prstat();
        $vms_per = pct_used($vms_mem,$sys_mem);
        if (($arc_min > $sys_mem)||($act_per < 0)) {
          $act_mem = $vms_mem;
          $act_per = pct_used($act_mem,$sys_mem);
        }
      }
      else {

        # prstat reports memory used, so derive free memory from it

        $vms_mem = $sys_mem-process_prstat();
        $vms_per = pct_used($vms_mem,$sys_mem);
        $act_mem = $vms_mem;
        if ((!$option{'Z'})&&($arc_now > $arc_min)) {
          $act_mem = $act_mem+$arc_now-$arc_min;
        }
        $act_per = pct_used($act_mem,$sys_mem);
      }
    }

    # Support for when system has gone below min ARC cache
    # or we are not using ZFS

    if (($act_mem < 0)&&(!$option{'Z'})) {
      $act_mem = $vms_mem+$arc_now;
      $act_per = pct_used($act_mem,$sys_mem);
    }

    # Handle where the current ARC cache has dropped below min

    if ((!$option{'Z'})&&($arc_now < $arc_min)) {
      $act_mem = $vms_mem+$arc_now;
      $act_per = pct_used($act_mem,$sys_mem);
    }
  }
  else {

    # Handle global zone with ZFS

    if (($vms_mem > $act_mem)&&(!$option{'Z'})) {
      $act_mem = $vms_mem+$arc_now;
      $act_per = pct_used($act_mem,$sys_mem);
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
      print "vmstat Usage:  $vms_per %\n";
      print "Actual Usage:  $vms_per %\n";
    }
    else {
      print "Actual Free:   $act_mem MB\n";
      print "vmstat Usage:  $vms_per %\n";
      print "Actual Usage:  $act_per %\n";
    }
  }

  # If given -p display percentage memory used
  # Add processing for ZFS ARC cache if needed

  if ($option{'p'}) {
    print(($option{'Z'}) ? "$vms_per\n" : "$act_per\n");
  }
  return;
}

# Main

if (!getopts("vVhpZz",\%option)) {
  print_usage();
  exit 1;
}

# If given -h print usage

if ($option{'h'}) {
  print_usage();
  exit 0;
}

# Print script version

if ($option{'V'}) {
  print_version();
  exit 0;
}

check_env();
get_actual_free_mem();
