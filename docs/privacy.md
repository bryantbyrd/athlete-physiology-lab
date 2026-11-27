# Data and privacy policy

The subject of this project is a real person. Physiological recordings are
health data, and several of the files involved identify that person or their
equipment. This document states what is published and how the rest is kept
out.

## What this repository contains

- Source code and scripts
- Documentation
- Synthetic example data produced by `tools/make_synthetic_night.py`, used
  by every automated test
- **One real recording**, explicitly authorised for publication by the
  author (see [Authorised demonstration dataset](#authorised-demonstration-dataset))
- The public workbook, which caches that recording and has passed
  `tools/audit_workbook.py`
- (Later) deliberately selected data for the public website

## What must never be committed

| Item | Why |
|---|---|
| Raw recordings (`*_hr.csv`, `*_rr.csv`, ECG, accelerometer, `SF_*` archives) | Health data; timestamps reveal sleep schedule |
| `session.json` | Contains age, sex, height, weight, sensor serial number, phone model, time zone |
| Working Excel workbooks | Hold cached recordings, the nightly log, author metadata and absolute file paths, even when sheets look empty |
| Training files (`.fit`, `.tcx`, `.gpx`) | GPS tracks reveal home and routine |
| Laboratory reports | Health data; often carry name and date of birth |
| Local configuration (`config/*` other than `*.example`) | Sensor ID and personal paths |
| Credentials and API tokens (Polar, Stryd, cloud storage) | Account access |
| Screenshots of personal dashboards | Readable data and dates |
| Crash dumps and Excel recovery copies | A dump is a copy of the program's memory and contains whatever recording or workbook was open |
| Review drafts, notes and exports | Often quote or summarise personal data |

## Identifiers to keep out of code and documentation

- Sensor serial numbers and Bluetooth identifiers
- User names in file paths (`/home/<name>/`, `C:\Users\<name>\`)
- Cloud-drive paths
- Email addresses and account names
- Exact dates of birth, addresses, and precise location
- Your time zone or UTC offset (the workbook template ships with offset 0)

Use placeholders in examples: `<ID>`, `XXXXXXXX`, `/path/to/Sleep`. The
synthetic generator and the tests use the sensor ID `00000000`.

## Safeguards

1. **`.gitignore`** denies data formats, workbooks, local configuration and
   credential files by default. Exceptions are narrow and explicit.
2. **`tools/prepublish_check.sh`** scans every tracked file for forbidden file
   types, identifier patterns, absolute personal paths and secret-like
   strings. It also reads an optional, git-ignored list of private terms
   (`config/private_terms.txt`, one per line: for example the sensor ID and
   the author's user names) and fails if any appears.
3. **`tools/scrub_workbook.py`** removes what Excel writes into a workbook on
   every save (save path, author fields, printer settings), and
   **`tools/audit_workbook.py`** inspects the result for author metadata,
   absolute paths, identifier-like names and cached data before it is allowed
   into `excel/template/`. Its cached HR and R-R columns must equal the
   authorised demonstration files value for value, so the workbook cannot
   carry any other night.
4. **Review before push.** See [publishing-checklist.md](publishing-checklist.md).

These are aids, not guarantees. A pattern scan cannot recognise every private
detail; read the diff before every push.

## Authorised demonstration dataset

The author has explicitly authorised publication of **one** recording: the
overnight recording of 26 November 2026, its heart rate and R-R intervals,
the HRV values derived from it and the graphs of those values. It is
published so that the software can be shown working on genuine physiology.
It lives in [`examples/demo-night-2026-11-26/`](../examples/demo-night-2026-11-26/)
and is the data cached in the public workbook.

**Scope.** The authorisation covers that recording only. It does not cover
any other night, recording metadata, training or laboratory data, or future
recordings. Each of those would need its own explicit decision, its own
folder and its own exception; nothing in this policy implies consent for
them. All other recordings, the working workbook and the archive remain
private.

**Preparation** ([`tools/deidentify_recording.py`](../tools/deidentify_recording.py)):

- physiological values are copied unchanged: no smoothing, editing, trimming
  or selection;
- all timestamps are shifted by one constant, not recorded anywhere, so the
  recording starts at 00:00:00 UTC on its date; elapsed time is exact;
- the sensor ID (archive and file names), `session.json`, `markers.csv` and
  all file paths are left out;
- the workbook is built from these files, so its time zone is UTC and it
  reveals neither the real clock time nor the author's offset.

What remains visible, by the author's decision: the date of the night, its
length (about 7 hours) and the course of heart rate and HRV across it.

**Enforcement** (`tools/prepublish_check.sh`):

- `.gitignore` and the check exempt the two data files by exact path, not by
  pattern; any other file in that folder, or any other data file anywhere,
  fails;
- the data files must match `SHA256SUMS`, so a different or longer recording
  cannot be substituted under the same authorisation;
- both files must start at exactly 2026-11-26 00:00:00.000 UTC;
- the workbook's cached data must equal the files exactly;
- the folder's README must state the terms of use.

**Licence.** The dataset is published under CC BY-NC 4.0, separately from
the MIT-licensed software; see its README. A licence governs reuse of these
files only and never extends the authorisation to other recordings.

**Withdrawal.** The author can withdraw the dataset by deleting the folder
and rebuilding the workbook from synthetic data. Published history, forks
and caches may keep copies; see the next section.

## If something private is committed

Removing a file in a later commit does not remove it from history.

- **Not yet pushed:** amend or rebuild the commit, then re-run the checks.
- **Already pushed:** treat the data as disclosed. Rewrite history
  (`git filter-repo`), force-push, rotate any exposed credential immediately,
  and remember that forks and caches may retain copies.

## Releasing selected data

The demonstration dataset above follows these rules. Data published for the
website will be:

- chosen deliberately, file by file;
- reduced to what the demonstration needs (derived series rather than raw
  streams where possible);
- stripped of sensor identifiers and metadata;
- reviewed for what the timestamps themselves reveal (sleep and training
  schedule), with dates shifted or coarsened if that matters;
- placed under an explicit path with its own `.gitignore` exception and a
  note describing how it was prepared.

## Git identity

Commits are public. Before the first push, confirm that the Git author name
and email are ones you are content to publish (a GitHub `noreply` address
keeps your personal email out of the history).
