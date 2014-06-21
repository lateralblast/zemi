![alt tag](https://raw.githubusercontent.com/lateralblast/zemi/master/zemi.jpg)

> A zemi or cemi is a deity or ancestral spirit, and a sculptural object that houses the spirit, among the Taíno.

ZEMI
====

ZFS Enabled Memory Information

Information
-----------

Solaris freemem with ZFS ARC cache support.

Script to determine free memory based on output of zfs cache and vmstat
Additional handling has been added so the script can be run on machines
without ZFS, of ZFS can be discounted via the -Z option.

Additional handling has been added for running in zones where
prstat -Z is used to calculate available memory.

The -Z and -z options can be set manually to simulate those
otherwise they are set depending on what the environment check finds.


License
-------

This software is licensed as CC-BA (Creative Commons By Attrbution)

http://creativecommons.org/licenses/by/4.0/legalcode

Usage
-----

```
$ zemi.pl -[v|h|V|p|z|Z]

-V: Print version information
-v: Verbose output
-h: Print help
-p: Return percentage memory used (without %)
    (useful for monitoring)
-Z: Ignore ZFS ARC cache (default for machines without ZFS)
-z: Running in a zone (default for non global zone)
```
