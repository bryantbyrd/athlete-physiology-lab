# Methods, as implemented

This document describes what the current prototype actually computes. It was
written by reading the workbook's formulas, Power Query code and VBA module,
not from memory or intent. Where the implementation has a weakness, it is
stated here rather than smoothed over.

It describes the published workbook template. The author's private working
workbook differs in the points listed in
[../excel/README.md](../excel/README.md#corrections-made-in-the-template).

**Validation status: none of the calculations below has been validated
against reference software or a reference device.** The workbook's behaviour
(log entries, duplicate prevention, rolling means, time-zone handling) is
covered by functional tests on synthetic data, described under
[Functional verification](#functional-verification); those tests are not a
scientific validation.

Notation: `RR[i]` is the i-th R-R interval in milliseconds, in file order.
`N` is the number of intervals in the recording.

---

## 1. Inputs

Two CSV files per night, staged by `scripts/sleep_import`
(layout in [data-format.md](data-format.md)):

- **HR stream**: one row per heart-rate notification from the sensor,
  approximately one per second, with a receive timestamp (`rx_unix_ms`) and
  the sensor-reported heart rate (`hr_bpm`).
- **RR stream**: one row per R-R interval (`rr_ms`), with the receive
  timestamp of the notification that carried it.

Beat detection is performed inside the Polar H10. The raw ECG is not used.

Simultaneous acquisition of ECG, three-axis accelerometer, heart rate and R-R
intervals with SensorForge Pro was successfully demonstrated in a separate
10-minute test recording. Overnight ECG and accelerometer processing is still
under development: nothing described in this document uses those signals.

## 2. Per-interval derived columns (RR sheet)

| Column | Definition |
|---|---|
| Elapsed time (s) | Running sum of `RR[1..i]` divided by 1000 |
| HR (bpm) | `60000 / RR[i]` |
| Successive difference | `RR[i] − RR[i−1]` (blank for the first interval) |
| Squared difference | `(RR[i] − RR[i−1])²` |
| Artefact flag | see section 3 |
| Screened squared difference | squared difference, kept only if neither `RR[i]` nor `RR[i−1]` is flagged |

For the HR stream, elapsed time is `(rx_unix_ms − first rx_unix_ms) / 1000`.

## 3. Preliminary artefact screening

**Status: preliminary and unvalidated.** This is a first-pass screen intended
to keep gross errors out of the screened metrics. It has not been compared
with manual beat review, with a published correction algorithm or with
reference HRV software, and its sensitivity, its false-positive rate and its
effect on the reported values are unknown. The original (unscreened) values
are always reported alongside the screened ones for that reason.

An interval is **flagged** when any of the following is true:

1. `RR[i] < 300 ms` (above 200 bpm)
2. `RR[i] > 2000 ms` (below 30 bpm)
3. `|RR[i] − RR[i−1]| / RR[i−1] > 0.20`

The first interval is assessed on rules 1 and 2 only.

A successive difference is **excluded** from screened metrics when either of
its two intervals is flagged. Flagged intervals are removed from the
calculation; they are **not corrected, interpolated or replaced**.

Consequences worth knowing:

- Rule 3 compares against the previous *raw* interval. One isolated bad
  interval therefore usually flags two intervals (the bad one, and the normal
  one that follows it) and excludes three successive differences.
- A genuine abrupt change in heart rate, for example at an arousal, can be
  flagged as an artefact.
- A run of similar wrong intervals is not detected by rule 3.
- The thresholds are conventional round numbers, not values tuned or
  validated for this sensor or this athlete.

## 4. Whole-night summary (HRV Analysis sheet)

| Metric | Definition | Screened? |
|---|---|---|
| Recording start (UTC) | First HR receive timestamp (Unix epoch milliseconds) converted to a UTC date-time. Identifies the recording | Not applicable |
| UTC offset (h) | Offset in effect at the recording start, from the time-zone table (section 4.1) | Not applicable |
| Recording date (local) | Recording start (UTC) + UTC offset | Not applicable |
| Recording duration (min) | Last HR elapsed time / 60 | Not applicable |
| Mean / minimum / maximum heart rate (bpm) | Mean / min / max of sensor-reported `hr_bpm` (HR stream, not derived from RR) | No |
| Mean RR interval (ms) | Mean of all `RR[i]` | No |
| RMSSD (ms) | `sqrt(mean(squared differences))` over all successive differences | No |
| lnRMSSD | Natural log of RMSSD | No |
| SDNN (ms) | Sample standard deviation of all `RR[i]` | No |
| pNN50 (%) | Share of successive differences with absolute value > 50 ms | No |
| Flagged intervals (%) | Share of intervals flagged in section 3 | Not applicable |
| Total RR intervals | `N` | Not applicable |
| Screened RMSSD (ms) | `sqrt(mean(screened squared differences))` | Yes |
| Excluded RR pairs (%) | `100 × (1 − screened differences / all differences)` | Not applicable |
| Screened lnRMSSD | Natural log of screened RMSSD | Yes |

Notes:

- "Original" metrics include every interval the sensor reported, artefacts
  included. They are kept alongside the screened values so the effect of
  screening is visible every night.
- Whole-night SDNN reflects all sources of variability across the recording,
  including the slow overnight trend in heart rate. It is not comparable with
  short-term (5-minute) SDNN.
- A successive difference is taken between adjacent *rows*. If the sensor
  drops beats, two rows that are adjacent in the file may not be adjacent in
  time; that case is not detected.

### 4.1 Recording identity and local time

A recording is identified by its **start time in UTC**, taken directly from
the first heart-rate timestamp. No time-zone setting enters that value, so it
is the same wherever and whenever the file is processed. The nightly log uses
it to decide whether a recording has already been stored (section 6).

Local time is derived for display and for chart axes only:

- The `TimeZone` table on the `Settings` sheet has one row per period:
  `Effective from (UTC)` and `UTC offset (h)`.
- A recording uses the latest row whose `Effective from (UTC)` is not after
  its UTC start. If no row applies the offset is 0.
- `local = UTC + offset / 24`. Offsets are hours east of Greenwich: negative
  in the Americas, positive in Asia; fractions such as 5.5 are allowed.
- When the offset changes (daylight-saving time, travel) the user adds a row
  with the UTC time of the change. Earlier nights keep the offset that was in
  effect for them, because the lookup is by each night's own UTC start.
- Editing the table changes displayed local dates. It cannot change which
  recordings are treated as the same.

The table is maintained by hand. There is no time-zone database in a
spreadsheet; a forgotten change gives local dates that are off by the
difference until the row is added. The template ships with a single row,
offset 0, so local dates equal UTC until the user sets their own offset.

## 5. Five-minute time course (Overnight Analysis sheet)

The recording is divided into consecutive, non-overlapping 5-minute windows
counted from the start of the recording. The number of windows is
`floor(total RR elapsed time / 300 s)`; a trailing partial window is dropped.

| Column | Definition |
|---|---|
| Mean HR (bpm) | Mean sensor-reported `hr_bpm` with HR elapsed time in the window |
| RMSSD (ms) | From squared differences whose later interval both starts and ends inside the window |
| lnRMSSD | Natural log of the window RMSSD |
| SDNN (ms) | Sample SD of intervals whose end time falls in the window (unscreened) |
| pNN50 (%) | From the same differences as RMSSD (unscreened) |
| Flagged intervals (%) | Share of intervals in the window flagged in section 3 |
| RR count | Number of intervals ending in the window |
| Screened RMSSD (ms) | As RMSSD, using screened squared differences only |

Notes:

- HR windows use receive-time elapsed seconds; RR windows use summed-interval
  elapsed seconds. The two clocks drift apart if beats are missing.
- Windows are positioned by time since recording start. They are not aligned
  to sleep onset or to clock time.
- No minimum number of valid intervals is required for a window to be
  reported.
- Formulas reference fixed row limits (about 100 000 intervals) and the
  dashboard charts cover at most 144 windows (12 hours).

## 6. Longitudinal log and rolling means (Nightly Log sheet)

A VBA macro copies the night's summary into a table, one row per recording.

- A night is identified by its recording start in UTC (column 1 of the log).
  If a row with the same start (within half a second) exists, its measured
  values are overwritten; otherwise a row is appended. Re-running the macro
  therefore does not duplicate a night.
- Only the 15 measured columns are written. Manually entered fields in an
  existing row are left as they are.
- The macro refuses to save if any summary value is non-numeric.
- Contextual fields (bedtime, wake time, exercise type, duration, intensity,
  end time, last caffeine, sleep quality 1-10, fatigue 1-10, sleeping
  altitude, notes) are typed in by hand.

Rolling means, for mean heart rate, lnRMSSD and screened lnRMSSD:

- **7-night mean** = mean of the current row and the six rows above it.
- **28-night mean** = mean of the current row and the 27 rows above it.
- A value is calculated only when all 7 (or 28) rows contain a number.
  Otherwise the cell holds `#N/A` (shown in grey). Line charts leave `#N/A`
  as a gap; an unavailable mean is never plotted as zero.
- Rolling lnRMSSD is the mean of nightly ln values, not the log of a mean.

Rows are consecutive *log entries*. A missed night does not leave a gap, so a
"7-night" mean may span more than seven calendar days.

## 7. Dashboard and trend charts

- **Dashboard**: summary panel for the current night; scatter charts of
  5-minute mean heart rate and of original and screened RMSSD against elapsed
  time. Chart ranges resize to the number of windows in the recording.
- **Longitudinal Trends**: three charts against local recording date:
  mean overnight heart rate with its 7- and 28-night rolling means; screened
  lnRMSSD with its 7- and 28-night rolling means; and nightly screened RMSSD
  in milliseconds on its own. Rolling means are computed on the ln scale
  only, so none is drawn on the millisecond chart. Value axes scale
  automatically.

---

## Functional verification

`tests/test_template.ps1` runs the workbook's own `RefreshAndSaveNight` macro
on a disposable copy of the template with 30 synthetic nights and checks:

- a new recording adds exactly one row to the nightly log;
- re-importing a recording that is already in the log (an earlier one, the
  one currently loaded, and after an edit to the time-zone table) never adds
  a duplicate row;
- manually entered context fields are preserved when a night is re-imported;
- column 1 holds each recording's UTC start, and local dates follow the
  time-zone table across an offset change part-way through the series;
- every rolling mean is `#N/A` until 7 (or 28) nights exist and afterwards
  equals a mean computed independently of the workbook;
- the trend charts and their named ranges grow with the log, hold the
  expected series, show every nightly value within their axes, and plot no
  unavailable mean as zero.

The test saves its disposable copy after every step and restarts Excel if it
crashes during a refresh (limitation 15), so the checks complete either way;
the number of such failures is reported with the results.

`tests/test_sleep_import.sh` covers the import script in the same way.

These tests establish that the software behaves as specified. They use
random synthetic series and say nothing about whether the metrics are
physiologically correct: that requires the validation work in
[roadmap.md](roadmap.md).

## Known limitations

Collected from the sections above, plus general ones.

1. No validation against reference HRV software or a reference ECG.
2. Sensor-internal beat detection; raw ECG not examined.
3. Artefact handling is rule-based exclusion without correction, and its
   thresholds are not validated (section 3).
4. SDNN and pNN50 are unscreened, both whole-night and per window.
5. Adjacent-row differences assume no missing beats; gaps are not detected.
6. RR elapsed time is a running sum of intervals and shortens when beats are
   missing; HR and RR windows use different clocks.
7. No sleep-onset detection, sleep staging or movement exclusion: metrics
   cover the whole recording, including any time awake.
8. Fixed 5-minute windows from recording start; no overlap, no minimum data
   requirement, trailing partial window dropped.
9. Local dates rely on a hand-maintained table of UTC offsets; there is no
   time-zone database, and an offset change that is not entered gives wrong
   local dates (identification by UTC is unaffected).
10. Rolling means are row-based, not calendar-based.
11. Fixed row limits in window formulas and charts.
12. Spreadsheet implementation: no unit tests, limited reviewability. The
    sanitised template (`excel/template/athlete-recovery-template.xlsm`) is
    under version control, but as a binary file whose changes Git cannot
    show line by line; its Power Query and VBA code are therefore also
    stored as text in `excel/`. The author's private working workbook is
    not under version control.
13. No frequency-domain or non-linear HRV indices are computed.
14. Respiration is not measured, so the respiratory contribution to RMSSD
    cannot be accounted for.
15. Stability: Excel sometimes crashes while the R-R table is refreshed; see
    the known issue in
    [../excel/README.md](../excel/README.md#known-issue-excel-can-crash-during-a-refresh).

## Planned replacements

Each item above maps to roadmap work in [roadmap.md](roadmap.md). The first
milestone is a tested Python implementation of sections 2-6 that reproduces
the workbook's numbers on the same input, so that later changes to the
methods can be made deliberately and measured.
