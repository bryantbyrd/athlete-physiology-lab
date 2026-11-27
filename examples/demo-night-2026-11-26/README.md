# Demonstration night: real physiological data

**These files contain real physiological data from the project author, who
has voluntarily published them.** They are not synthetic. They are the
demonstration recording cached in the public workbook
([`excel/template/athlete-recovery-template.xlsm`](../../excel/template/athlete-recovery-template.xlsm)).

| | |
|---|---|
| Subject | The project author (one person) |
| Recording | One overnight recording, night of 26 November 2026 |
| Sensor | Polar H10 chest strap, recorded with SensorForge Pro |
| Duration | 422.8 minutes (7.05 h) from first to last notification |
| Contents | `hr.csv`: 25,371 heart-rate notifications. `rr.csv`: 22,739 R-R intervals |
| Validation | None. The project is an unvalidated prototype; see [../../README.md](../../README.md#known-limitations) |
| Licence | **[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)** (data only; the software is MIT, see below) |

## Licence: data versus software

This repository uses two licences. They cover different things.

| What | Licence |
|---|---|
| **This dataset**: `hr.csv`, `rr.csv`, the same values cached in the public workbook, the HRV values derived from them and the graphs of them (including `docs/images/demo-dashboard.png`) | **[Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)](https://creativecommons.org/licenses/by-nc/4.0/)** |
| **The software and documentation**: code, scripts, tools, tests, the workbook's formulas, queries, charts and macro, synthetic data | [MIT](../../LICENSE) |

Under CC BY-NC 4.0 you may share and adapt the data for **non-commercial**
purposes, provided you give attribution, link to the licence and indicate
any changes. Commercial use needs the author's separate permission.
Suggested attribution:

> Byrd B. Athlete Physiology Lab demonstration night (26 November 2026):
> overnight heart rate and R-R intervals from one participant. CC BY-NC 4.0.
> https://github.com/bryantbyrd/athlete-physiology-lab

The MIT licence of the software does **not** extend to this data, and the
data licence does not restrict the software: you may use the workbook and
code under MIT with your own recordings, commercially or not. The licence
grants permission to use these files; it is not consent to publish, and
does not authorise publication of, any other recording by the author.

## Scope of the authorisation

The author has authorised publication of **this one recording only**: its
heart rate, R-R intervals, the HRV values derived from them and the graphs
of those values. The authorisation does not extend to any other recording,
to recording metadata, or to future nights, and neither the CC BY-NC 4.0
licence nor the MIT licence implies it does. Every other recording remains
private and stays out of version control (see
[../../docs/privacy.md](../../docs/privacy.md)).

## How the files were prepared

The source was the archive of that night, staged by `scripts/sleep_import`.
The files here were produced from it by
[`tools/deidentify_recording.py`](../../tools/deidentify_recording.py):

```text
python3 tools/deidentify_recording.py --date 2026-11-26 <staged folder> examples/demo-night-2026-11-26
```

- **Values unchanged.** Heart rate, R-R intervals, frame counters and every
  flag column are copied byte for byte. Nothing is smoothed, filtered,
  corrected, trimmed or selected. Artefacts present in the recording are
  still present; the workbook's own screening is what flags them.
- **Clock time removed.** Every timestamp (`rx_unix_ms`) in both files was
  shifted by the same constant, so the recording now starts at exactly
  2026-11-26 00:00:00.000 UTC. The constant was not recorded. Differences
  between timestamps, and therefore elapsed time and the 5-minute windows,
  are exact to the millisecond. The start time of 00:00 and the UTC offset
  of 0 shown in the workbook are therefore conventions, not the real time of
  sleep.
- **Identifiers and metadata removed.** The sensor ID appeared only in the
  archive and file names; the files are renamed to `hr.csv` and `rr.csv`.
  `session.json` (body measurements, device serial number, phone, time zone)
  and `markers.csv` were not read and are not published.

The tool re-reads its output and checks that headers, row counts, every
non-timestamp value and every timestamp difference are identical to the
source.

## Verification against the author's working workbook

The public workbook was rebuilt from these files and compared, cell by cell,
with the author's private working workbook after it had loaded the same
night. All 14 whole-night values and all 840 values of the 84 five-minute
windows are identical to full precision, including:

| Metric | Value (rounded here; identical in full in both workbooks) |
|---|---|
| Mean heart rate | 54.18 bpm |
| Original RMSSD | 73.94 ms |
| Original lnRMSSD | 4.303 |
| Screened RMSSD | 56.00 ms |
| Screened lnRMSSD | 4.025 |
| Excluded R-R pairs | 1.53 % |
| Flagged intervals | 0.90 % |

`tools/prepublish_check.sh` confirms on every run that the files match
`SHA256SUMS` and that the workbook's cached HR and R-R columns are
identical, value for value, to these files.

## Files

| File | Contents |
|---|---|
| `hr.csv` | Heart-rate stream; layout in [../../docs/data-format.md](../../docs/data-format.md) |
| `rr.csv` | R-R interval stream |
| `SHA256SUMS` | Checksums of the two data files as published |
| `dashboard-note.txt` | The note shown on the workbook dashboard |
| `README.md` | This file |

## Not medical data in the clinical sense

This is one night from one person, recorded with a consumer chest strap and
processed by an unvalidated prototype. It shows how the software behaves on
a genuine recording. It is not a reference dataset, says nothing about anyone
else, and is not medical advice.
