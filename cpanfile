# zemi.pl only uses core modules (strict, Getopt::Std), so there is nothing
# to install from CPAN. Solaris tools it shells out to: uname, zonename, zfs,
# kstat, prtconf, sar, vmstat, prstat, pagesize.

requires 'perl', '5.006';
requires 'Getopt::Std';
