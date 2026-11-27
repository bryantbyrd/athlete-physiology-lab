# Data and privacy policy

The subject of this project is a real person. Physiological recordings are
health data, and several of the files involved identify that person or their
equipment. This document states what is published and how the rest is kept
out.

## What this repository contains

- Source code and scripts
- Documentation
- Synthetic example data produced by `tools/make_synthetic_night.py`
- A workbook template loaded with synthetic data, which has passed
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
   into `excel/template/`.
4. **Review before push.** See [publishing-checklist.md](publishing-checklist.md).

These are aids, not guarantees. A pattern scan cannot recognise every private
detail; read the diff before every push.

## If something private is committed

Removing a file in a later commit does not remove it from history.

- **Not yet pushed:** amend or rebuild the commit, then re-run the checks.
- **Already pushed:** treat the data as disclosed. Rewrite history
  (`git filter-repo`), force-push, rotate any exposed credential immediately,
  and remember that forks and caches may retain copies.

## Releasing selected data

Data published for the website will be:

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
