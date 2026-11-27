# Excel workbook

The working analysis lives in a macro-enabled workbook that is kept outside
this repository because it contains personal recordings. This folder holds
what can be version-controlled and published:

```text
excel/
├── README.md            this file
├── power-query/         Power Query (M) source for the data queries
├── vba/                 the workbook's VBA module, exported as text
└── template/            the clean, publishable workbook template
```

Two workbooks are referred to below:

- the **working workbook** — private, contains real recordings, never
  modified by anything in this repository;
- the **template** — built from a copy of the working workbook, loaded with
  synthetic data, with the corrections listed under
  [Corrections made in the template](#corrections-made-in-the-template).

## Template structure

| Sheet | Contents |
|---|---|
| `RR` | Query table of R-R intervals (3 imported columns) plus 6 calculated columns: elapsed time, instantaneous heart rate, successive difference, squared difference, artefact flag, screened squared difference |
| `HR` | Query table of heart-rate notifications (8 imported columns) plus elapsed time |
| `HRV Analysis` | One row of whole-night summary values: recording start (UTC), 14 metrics, then local recording date and the UTC offset applied |
| `Overnight Analysis` | 5-minute windows; a dynamic array sets the number of rows from the recording length |
| `Dashboard` | Summary panel, two scatter charts (heart rate; original and screened RMSSD against elapsed time), and a button that runs `RefreshAndSaveNight` |
| `Nightly Log` | Table `Nightlog`, one row per night: recording start (UTC), 11 original metrics, 11 manual context fields, 6 rolling-mean columns, 3 screened metrics, then derived local date and UTC offset |
| `Longitudinal Trends` | Three line charts: mean overnight heart rate and screened lnRMSSD (each with 7- and 28-night rolling means), and nightly screened RMSSD |
| `Settings` | Table `TimeZone`: dated UTC offsets used to derive local dates |

Named ranges: `NightTime`, `NightHR`, `NightRMSSD`, `NightScreenedRMSSD`
(dynamic ranges sized to the number of 5-minute windows, feeding the dashboard
charts) and `LogDate`, `LogHR`, `LogHR7`, `LogHR28`, `LogRMSSD`, `LogLnRMSSD`,
`LogLnRMSSD7`, `LogLnRMSSD28` (columns of `Nightlog`, feeding the trend
charts).

All formulas are documented in [../docs/methods.md](../docs/methods.md).

## Code stored here

### `power-query/`

`hr_stream.pq` and `rr_stream.pq` are the two data queries. They differ from
the working workbook's queries in one respect: the absolute path to the
staged CSV files is replaced by the `DataFolder` parameter (`DataFolder.pq`).

### `vba/Module1.bas`

Exported verbatim from the working workbook; the template carries the same
module unchanged. It contains no personal information.

- `SaveNight` — checks the summary row is complete, then adds the night to
  `Nightlog` or overwrites the existing row for the same recording.
- `RefreshAndSaveNight` — refreshes both query tables, waits for calculation
  to finish, then calls `SaveNight`. Bound to the dashboard button.

The module addresses sheets by name and log columns by position (1-12 and
28-30), which is why the template adds its new log columns at the end of the
table and keeps the recording identifier in column 1.

## Corrections made in the template

These exist in the template only. The working workbook has not been changed;
it can adopt them by hand, or be replaced by a copy of the template.

1. **Time-zone handling.** The working workbook subtracts a fixed number of
   hours inside a formula. In the template:
   - column 1 of the summary and of the nightly log is the recording start in
     **UTC**; this is what identifies a recording and prevents duplicates;
   - the `TimeZone` table on the `Settings` sheet lists UTC offsets with the
     UTC time from which each applies; a night uses the latest row that is
     not after its start;
   - `Recording date (local)` and `UTC offset (h)` are derived columns, and
     the trend charts use the local date for their axis.

   Editing the table changes displayed local dates only. It cannot create or
   hide a duplicate. The template ships with a single row, offset 0 (UTC).
2. **Unavailable rolling means are `#N/A`, not empty text.** Line charts plot
   empty text as zero; they leave `#N/A` as a gap. In the log these cells are
   shown in grey until enough nights exist.
3. **Screened RMSSD trend chart shows RMSSD only.** The working workbook
   overlays 7- and 28-night means of **ln**RMSSD on an RMSSD (ms) axis. Those
   two series are removed from this chart; they remain on the lnRMSSD chart.
   The mean heart-rate and screened lnRMSSD charts keep their rolling means.
4. **"lnRMSSD" labels** on the third trend chart are spelled with a lowercase
   L (they read "InRMSSD").
5. **Chart value axes scale automatically.** Three charts in the working
   workbook have fixed axis bounds chosen for one person's values. With other
   data the series falls outside the axis and the chart appears empty (this
   is how it was found: the RMSSD trend chart was blank in the functional
   test). Fixed bounds also hint at the range of the author's own values.

`tools/build_template.ps1` applies each correction only if it finds the old
form, so it keeps working once the working workbook has been updated.

### Remaining observations

Not changed; noted for a later revision.

- The 5-minute formulas use two different fixed row limits (about 100 000 and
  120 000 intervals). Harmless at overnight recording lengths.
- A 5-minute window with no valid data returns empty text, which the
  dashboard scatter charts would plot as zero.
- Rolling means of the original (unscreened) lnRMSSD are calculated in the
  log but not charted.
- Rolling means are taken over consecutive log rows, not calendar days.
- The time-zone table is maintained by hand; there is no time-zone database.

### Known issue: Excel can crash during a refresh

Found while testing, with Excel for Microsoft 365 version 16.0.20625.20108
(64-bit) driven through automation.

**What happens.** While the R-R query table is being refreshed, Excel
sometimes terminates with an access violation inside `EXCEL.EXE`
(exception `0xc0000005`). The failure is intermittent: the same step
succeeds when repeated.

**What was observed.**

- Across two full runs of the functional test, 6 of 74 macro runs (about 8 %) did not
  complete. Either Excel terminated, or the macro's own error handler
  reported "Refresh failed" and saved nothing. Every failed step succeeded
  when repeated in a fresh Excel session; one needed three repeats.
- It happened with new data and with data identical to what was already
  loaded, with the Excel window hidden and visible, and with automatic and
  manual calculation.
- It also happened on the first refresh of a scratch copy of the working
  workbook, and in the template as it was before the corrections above. The
  cause therefore predates the template; it is not introduced by it.
- Refreshing the HR table never triggered it. Removing the R-R table's
  calculated columns, or the 5-minute formulas that depend on them, appeared
  to help in single trials, but no individual formula could be isolated.

**What is not known.** Whether it happens at a similar rate when the button
is pressed by hand rather than through automation, and whether other Excel
versions are affected.

**Consequences.** The failure occurs during the refresh, before the macro
writes anything to the nightly log. No partial, wrong or duplicate entry was
ever produced; after a restart the import can simply be repeated. Any change
made since the workbook was last saved is lost.

**Until it is resolved.** Save the workbook before pressing the button, in
particular after typing in the manual context fields.

**Likely direction for a fix.** Reduce what Excel has to rebuild during the
refresh: move the per-interval calculations out of the query table (into
Power Query or, as planned, into Python), so the table holds values only.
This is one more reason for roadmap milestone 1.

## Clean template

[`template/athlete-recovery-template.xlsm`](template/athlete-recovery-template.xlsm)
keeps the workbook's formulas, queries, charts and macro but contains no
personal data. The cached values it opens with come from a synthetic
recording (`tools/make_synthetic_night.py`, seed 1, 7 hours). The numbers on
its dashboard are not physiological measurements.

### Differences from the working workbook

- The five corrections above.
- Queries, query tables and connections are named `hr_stream` and
  `rr_stream` (no sensor ID).
- The source path is the `DataFolder` parameter, set to a placeholder.
- The nightly log is empty.
- Author names, the saved-in folder and printer settings are removed.

All other formulas, the dashboard charts, the named ranges for the 5-minute
windows and the VBA module are unchanged.

### Using the template

1. Stage a recording with `scripts/sleep_import` (or generate a synthetic
   one) so that a folder contains `hr.csv` and `rr.csv`.
2. Open the template and enable macros.
3. Data > Get Data > Launch Power Query Editor > Manage Parameters: set
   `DataFolder` to that folder, with a trailing backslash.
4. On the `Settings` sheet, replace the offset `0` with your own UTC offset
   in hours (for example `-7`, or `5.5`). When your offset changes
   (daylight-saving time, travel), add a row giving the UTC time of the
   change and the new offset. Do not edit earlier rows: past nights keep the
   offset that was in effect.
5. Press the dashboard button (refresh and save), or use Data > Refresh All.

### How it was built

```text
tools/make_synthetic_night.py   synthetic hr.csv / rr.csv
tools/build_template.ps1        drives Excel on a COPY of the working workbook:
                                replaces and renames the queries, refreshes from
                                the synthetic files, applies the corrections,
                                empties the log, removes document properties
tools/scrub_workbook.py         removes what Excel writes on every save
                                (save path, author fields, printer settings)
tools/audit_workbook.py         checks the result
tests/test_template.ps1         functional test on a disposable copy
```

The working workbook is only read (it is copied first). Macros and events
are disabled while the template is built.

### What was checked

Privacy:

- `audit_workbook.py`: no failures and no warnings, with a private-terms list
  covering the sensor ID, user names, drive and profile paths.
- With `--expect-data`, the cached HR and RR columns are identical, value for
  value, to the synthetic CSV files. No timestamp from a real recording is
  present.
- Package integrity after scrubbing: all XML parts well-formed, no dangling
  relationships; Excel opens the file without repair.

Function (`tests/test_template.ps1`, 30 synthetic nights, run on a
disposable copy with the workbook's own `RefreshAndSaveNight` macro):

- a new recording creates one nightly-log entry;
- re-importing a recording that is already in the log (an earlier one, the
  one currently loaded, and after a time-zone edit) never creates a
  duplicate;
- manually entered context fields are preserved on re-import;
- recordings are identified by UTC start; local dates follow the time-zone
  table, including an offset change part-way through the series;
- 7- and 28-night rolling means are `#N/A` until enough nights exist and
  afterwards equal an independently computed mean;
- trend charts and named ranges grow with the log; every nightly value lies
  within its chart's axis; unavailable means are not plotted as zero; the
  RMSSD chart has a single series.

In two full runs, 6 of 74 macro runs (about 8 %) failed during the refresh (see the known
issue above); each failed step was repeated in a fresh session and then
passed. All functional checks passed in both runs.

These are software checks on synthetic data. They show the workbook does what
its formulas say; they are not a scientific validation of the metrics.

**Not checked automatically:** the click on the dashboard button itself (the
macro it is bound to was run through Excel automation), and the visual
appearance of the charts beyond an exported image review.

### Why "clear the sheets" is not enough

A workbook that looks empty can still carry cached query results and chart
caches, the absolute path it was last saved to, the source path in each
query, author and last-modified-by names, printer settings naming a local
printer, and object names (here, the sensor ID in query and table names).
That is why the build refreshes from known synthetic files and the audit
compares the cached data against them.

### Rebuilding

Rebuild whenever the working workbook's formulas, charts or macros change.
Each command is one line:

```powershell
python tools\make_synthetic_night.py --out <scratch>\syn
```

Copy the two generated CSV files to `<scratch>\data` as `hr.csv` and
`rr.csv`, then:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_template.ps1 -Source "<working workbook>" -DataFolder "<scratch>\data" -Output "<scratch>\template-raw.xlsm"
```

```powershell
python tools\scrub_workbook.py "<scratch>\template-raw.xlsm" excel\template\athlete-recovery-template.xlsm
```

```powershell
python tools\audit_workbook.py --terms config\private_terms.txt --expect-data "<scratch>\data" excel\template\athlete-recovery-template.xlsm
```

```powershell
powershell -ExecutionPolicy Bypass -File tests\test_template.ps1
```

Keep `<scratch>` outside the repository and outside any synced folder. Do not
edit and re-save the template by hand: Excel writes the author name and
printer settings back into the file on every save.
