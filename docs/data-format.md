# Recording file layout

This describes the SensorForge Pro export as observed in the recordings used
by this project (export `formatVersion` 1). It is a description of observed
files, not an official specification; the app may change its format.

`<ID>` is the 8-character sensor identifier printed on the Polar H10.

## Archive

One ZIP archive per recording:

```text
SF_<YYYYMMDD-HHMMSS>_Polar-H10-<ID>.zip
└── SF_<YYYYMMDD-HHMMSS>_Polar-H10-<ID>/
    ├── <ID>_hr.csv
    ├── <ID>_rr.csv
    ├── markers.csv
    └── session.json
```

The timestamp in the name is the recording start. Because it is
zero-padded and ordered year-first, sorting archive names alphabetically
sorts them chronologically; `sleep_import` relies on this to pick the newest.

Files are UTF-8 text with LF line endings and a single header row.

## `<ID>_hr.csv`: heart-rate stream

One row per heart-rate notification, approximately one per second.

| Column | Meaning (as understood) |
|---|---|
| `rx_unix_ms` | Time the notification was received by the phone, Unix epoch milliseconds (UTC) |
| `frame` | Notification counter, starting at 0 |
| `hr_bpm` | Heart rate reported by the sensor |
| `corrected_hr_bpm` | App-provided corrected heart rate. Not used by this project |
| `ppg_quality` | Not applicable to a chest strap; observed as 0 |
| `rr_available` | 1 if the notification carried at least one R-R interval |
| `contact` | Skin-contact flag |
| `contact_supported` | Whether the sensor reports skin contact |

The workbook uses `rx_unix_ms` and `hr_bpm`. The meanings of the remaining
columns are inferred from their names and values and have not been confirmed
against app documentation.

## `<ID>_rr.csv`: R-R interval stream

One row per R-R interval.

| Column | Meaning |
|---|---|
| `rx_unix_ms` | Receive time of the notification that carried the interval |
| `frame` | Counter of that notification (matches `frame` in the HR stream) |
| `rr_ms` | R-R interval in milliseconds |

`rx_unix_ms` is a *receive* time, not the time of the heartbeat. Several
intervals can share one timestamp. The current analysis reconstructs beat
timing by summing intervals (see [methods.md](methods.md)).

## `markers.csv`

Columns `unix_time_ms,label`. Event markers set in the app during a
recording. Not used yet.

## `session.json`

Recording metadata: start and end times, time zone, sensor model, serial
number, firmware and battery level, phone model and state, a list of recorded
streams, and a subject block that can include age, sex, height and weight.

**This file is personally identifying and is never committed.** It is not
read by any current code.

## Streams not yet handled

The H10 can also stream raw ECG and accelerometer data. Simultaneous
acquisition of ECG, accelerometer, heart rate and R-R intervals with
SensorForge Pro has been demonstrated in a separate 10-minute test recording.
Overnight ECG and accelerometer processing is still under development: this
project does not yet import those files, and their layout will be documented
here when that work begins.

## Staged files

`sleep_import` copies the two streams, unchanged, to fixed names so the
workbook's queries do not depend on the sensor ID or the date:

```text
<current-night-folder>/hr.csv
<current-night-folder>/rr.csv
```

## Demonstration recording

`examples/demo-night-2026-11-26/hr.csv` and `rr.csv` are staged files in the
layout above, from one real night the author has authorised for
publication. Their `rx_unix_ms` values are shifted by a constant so the
recording starts at 2026-11-26 00:00:00.000 UTC; they are not the real
receive times. All other columns are unchanged. See
`tools/deidentify_recording.py`.

## Synthetic recordings

`tools/make_synthetic_night.py` writes files in this layout from a random
model, for tests and demonstrations:

```bash
python3 tools/make_synthetic_night.py --out /tmp/demo/Archive --zip
```
