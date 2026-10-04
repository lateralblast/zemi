# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.1] - 2026-10-04

### Changed
- Consistent indentation and comment formatting throughout.

## [1.2.0] - 2026-10-04

### Changed
- Unknown options print usage and exit with status 1.
- External command and file paths are held in variables at the top of the script and checked with `-x`.
- Main program flow moved to the end of the script, after all subroutines are defined.

## [1.1.9] - 2026-10-04

### Changed
- Added `run_cmd`, `read_first_line` and `pct_used` helpers to remove repeated code.
- Verbose output restructured so each branch prints its own results.

## [1.1.8] - 2026-10-04

### Changed
- Replaced shell pipelines (`cat`, `grep`, `awk`, `cut`, `head`, `tail`) with native Perl parsing.
- OS detection uses `POSIX::uname()` instead of parsing `uname -a`.

## [1.1.7] - 2026-10-04

### Changed
- Enabled `use warnings` and initialised ARC variables so they are never undefined.

## [1.1.6] - 2026-10-04

### Fixed
- Usage text now shows the leading dash on `-Z` and `-z`.

## [1.1.5] - 2026-10-04

### Fixed
- Corrected misleading verbose messages and comments about disabling ZFS and zone support.

## [1.1.4] - 2026-10-04

### Fixed
- Solaris 10/11 detection is anchored to the `uname -a` release field instead of matching anywhere in the output.

## [1.1.3] - 2026-10-04

### Fixed
- Version is read in Perl instead of via an unquoted `cat | grep | awk` shell pipeline.

## [1.1.2] - 2026-10-04

### Fixed
- `prtconf` memory sizes in Terabytes are handled; corrected the unit comment.

## [1.1.1] - 2026-10-04

### Fixed
- `prstat` memory values with `T` and `K` suffixes are converted correctly, and only numeric characters are kept.

## [1.1.0] - 2026-10-04

### Fixed
- ARC min, max and size are read by name with `kstat -p zfs:0:arcstats:*` instead of relying on output line order.

## [1.0.9] - 2026-10-04

### Fixed
- Zone memory calculation on releases other than 8/11, 10/08 and 5/09 treated `prstat` used memory as free memory and left the actual usage percentage unchanged. Free memory is now derived from it and actual usage is recalculated.

## [1.0.8] - 2026-10-04

### Fixed
- Exit with an error instead of dividing by zero when system memory cannot be determined.

## [1.0.7] - 2026-10-04

### Fixed
- Exit with status 1 when not running on Solaris.

## [1.0.6] - 2026-10-04

### Fixed
- Script failed to compile under `use strict` because `%option` was used in its own declaration.

## [0.0.5] - 2014-06-17

### Changed
- Updated documentation and license.

## [0.0.4] - 2012-12-20

### Changed
- Code cleanups.

## [0.0.3] - 2012-08-22

### Fixed
- Handle different zone output on different releases.

## [0.0.2] - 2012-08-08

### Added
- Check for ZFS and zones.

## [0.0.1]

### Added
- Initial version.
