# Test report — v0.1.0

Date: 2026-11-26. The functional tests used synthetic recordings and
disposable copies of the workbook template. One diagnostic trial (section 3)
used a scratch copy of the author's working workbook, to establish whether
the refresh problem predates the template; nothing from that copy is part of
this release.

This report records what was run and what happened, including the runs that
failed. It covers software behaviour only. Nothing here is a scientific
validation of the metrics; see [methods.md](methods.md).

## Environment

| Component | Version |
|---|---|
| Operating system | Windows 11 (64-bit); Ubuntu under WSL 2 for the Bash test |
| Excel | Microsoft 365, version 16.0.20625.20108, 64-bit |
| Python | 3.13 (Windows), 3.14 (WSL) |
| How Excel was driven | COM automation from PowerShell, one Excel instance per session |

## Summary

| Test | Result |
|---|---|
| Import script (`tests/test_sleep_import.sh`) | 17 of 17 checks passed |
| Workbook template and macro (`tests/test_template.ps1`), final run | 50 of 50 checks passed; the refresh failed in 2 of 36 macro runs and each passed on the first retry |
| Workbook template and macro, previous full run | 47 of 47 checks passed; the refresh failed in 4 of 38 macro runs; one recording needed three retries |
| Earlier runs of the workbook test | 2 stopped when Excel crashed; 2 stopped on errors in the test script itself |
| Repeated-refresh trials (no macro) | Excel crashed in 14 of 20 sessions |
| Privacy checks | Passed; see the last section |

**The functional checks all pass. Excel itself is not reliable while this
workbook refreshes.** Both statements are true and both matter.

## 1. Import script

`bash tests/test_sleep_import.sh` under WSL: 17 passed, 0 failed, on every
run. Covered: selection of the newest archive, header and row-count
validation, refusal to replace staged files after a failed import, missing
or malformed configuration, configuration file versus environment.

## 2. Workbook template and macro

`tests/test_template.ps1` generates 30 synthetic one-hour recordings and, for
each, stages the files and runs the workbook's own `RefreshAndSaveNight`
macro on a disposable copy of the template.

### What is checked

| Area | Checks |
|---|---|
| New recording | One nightly-log row per new recording; all 15 measured values stored as numbers; macro reports success |
| Duplicate prevention | No new row when re-importing an earlier recording, the recording currently loaded, or any recording after the time-zone table has been edited; existing rows stay in place |
| Manual entries | All 11 manually entered context fields unchanged after a re-import and after 30 imports |
| Recording identity | Column 1 holds each recording's UTC start (within 1 s); identifiers unique and in import order; unchanged when the time-zone table is edited |
| Time zone | Each night uses the offset in effect at its UTC start, across an offset change after night 14; local date = UTC + offset |
| Rolling means | For all six rolling columns: `#N/A` for the first 6 (or 27) nights, then equal to an independently computed mean to within 1e-9 |
| Trend charts | Expected series per chart (3, 1, 3); every series has one point per night; every nightly value inside the value axis; no unavailable mean plotted as zero; "lnRMSSD" spelled correctly; date axis uses local date |
| Dashboard | Number of 5-minute windows matches the recording; chart range matches; local recording date shown |
| Safety | The template in the repository is byte-identical after the test |

Exported chart images from the final run were also inspected by eye.

### Runs, in order

1. **Stopped: test-script error.** A value was passed to Excel in a form it
   rejected. Fixed in the script. No workbook behaviour was involved.
2. **Stopped: test-script error** of the same kind when writing the manual
   fields. Fixed. The six checks reached before it had passed.
3. **Stopped: Excel crashed** on the third macro run of the session. This is
   how the refresh problem was found.
4. **Stopped: Excel failed** on the 13th recording (the macro reported
   "Refresh failed") and was gone by the 14th.

   After run 4 the test was changed to save its disposable copy after every
   step, restart Excel when a step fails, repeat the step, and count the
   failures.
5. **Completed: 47 of 47 checks passed.** 38 macro runs; the refresh failed
   in 4. Recording 17 failed once ("Refresh failed") and passed on retry.
   Recording 21 failed three times in a row (once with Excel terminating,
   twice with "Refresh failed") and passed on the fourth attempt.

   Reviewing the exported charts from this run showed the RMSSD trend chart
   empty: its axis had fixed bounds that did not contain the synthetic
   values. The template was corrected (automatic axes), rebuilt, and three
   checks were added so that this is tested.
6. **Completed, final template: 50 of 50 checks passed.** 36 macro runs; the
   refresh failed in 2 (recordings 15 and 22, "Refresh failed"), and each
   passed on the first retry.

Across the two completed runs the refresh failed in 6 of 74 macro runs
(about 8 %). In every case nothing was written to the nightly log by the
failed run, and the repeated run produced the correct single row.

When the macro reported "Refresh failed", the test restarted Excel without
finding out whether Excel would have kept working. In run 4, Excel did not.

## 3. Repeated-refresh trials

To find the cause, the query tables were refreshed repeatedly without the
macro, in a fresh Excel session per trial, up to 16 refresh cycles each.

| Trial | Cycles attempted | Outcome |
|---|---|---|
| Template, same data each cycle | 5 | Crashed on cycle 4 |
| Template, one log row added | 5 | Crashed on cycle 5 |
| Template as built before the corrections | 5 | Crashed on cycle 4 |
| Template before the corrections, one log row added | 5 | Completed |
| Template, different recording each cycle | 8 | Completed |
| Template, single-threaded calculation | 8 | Crashed on cycle 6 |
| Template, manual calculation | 8 | Crashed on cycle 4 |
| Scratch copy of the working workbook | 8 | Crashed on cycle 1 |
| Template, 5-minute formulas removed | 10 | Completed |
| Template, all R-R calculated columns removed | 10 | Completed |
| Template, cumulative-time column removed | 10 | Crashed on cycle 6 |
| Template, previous-row columns removed | 10 | Completed |
| Template, four 5-minute columns removed | 12 | Crashed on cycle 12 |
| Template, one 5-minute column removed | 12 | Crashed on cycle 4 |
| Template, three 5-minute columns removed | 12 | Crashed on cycle 7 |
| Template, three other 5-minute columns removed | 12 | Crashed on cycle 2 |
| Template, 5-minute window list made static | 12 | Crashed on cycle 3 |
| Template, Excel window visible | 16 | Crashed on cycle 2 |
| Template, Excel window visible (repeat) | 16 | Completed |
| Template, screen updating off | 16 | Crashed on cycle 2 |

Excel crashed in 14 of 20 sessions. Every crash was on a refresh of the R-R
table; the HR table never failed. Windows recorded an access violation
(`0xc0000005`) inside `EXCEL.EXE` at more than one address.

### What this does and does not show

- The problem is not introduced by the template or its corrections: it
  occurs in the template as first built and in a copy of the working
  workbook.
- It does not depend on whether the window is visible, on calculation mode,
  or on whether the data changed.
- Removing all R-R calculated columns, or all 5-minute formulas, was followed
  by 10 clean cycles in one trial each. With a failure that is intermittent,
  one clean trial is weak evidence; no single formula was isolated.
- It has not been tested by hand in an interactive session, or on any other
  Excel version. Whether an ordinary user sees it at a similar rate is
  unknown.

## 4. Privacy checks

Run on the files of this release:

- `tools/prepublish_check.sh`: no problems. It scans every tracked file for
  data files, workbooks, crash dumps, identifiers, personal paths and
  secret-like strings, and for a private list of terms kept outside the
  repository.
- `tools/audit_workbook.py` on the template: no failures, no warnings. The
  cached HR and R-R columns are identical, value for value, to the synthetic
  recording the template is built from.
- An independent byte-level scan of every part of the template, including
  the Power Query package and the VBA project, for the same private terms:
  no matches, and no timestamp from a real recording.

## Side effects of testing

The Excel crashes produced Windows crash dumps and document-recovery files
on the test machine. These are outside the repository and are not part of
the release. `.gitignore` and the pre-publication check exclude crash dumps
in case one is ever copied into the working tree.
