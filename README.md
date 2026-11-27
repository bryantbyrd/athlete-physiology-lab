# athlete-physiology-lab

An open, single-athlete monitoring project that aims to connect three things
that are usually analysed apart: laboratory-derived physiological thresholds,
day-to-day training load, and overnight cardiovascular and autonomic recovery.

> **Project status: early prototype.**
> The working part today is an overnight heart-rate and heart-rate-variability
> (HRV) pipeline built on a Polar H10 chest strap, a Bash import script and an
> Excel workbook. Everything else in this document is a plan. None of the
> methods has yet been validated against a reference method, and the
> longitudinal dataset is at an early stage. This is a personal research
> project, not a medical device, and nothing here is medical advice.

Features are labelled throughout as **Working** (implemented and in routine
use), **Planned** (not implemented) and, separately, by validation state.
"Working" never implies "validated".

---

## Scientific rationale

Endurance training is prescribed in intensity domains and judged by how the
athlete adapts to it. Both halves of that loop are usually measured loosely:
intensity by generic percentages of maximum heart rate, and recovery by a
single morning number from a consumer wearable whose algorithms are not
disclosed.

This project starts from three premises.

1. **Exercise intensity should be anchored to the individual's own
   physiology.** The first and second lactate thresholds (LT1, LT2) measured
   in a laboratory test separate the moderate, heavy and severe intensity
   domains. Time and work accumulated in each domain is a more defensible
   description of training dose than heart-rate percentages or pace alone.

2. **Sleep is a useful standardised window for measuring autonomic state.**
   Overnight recordings avoid most of the posture, activity, food and
   time-of-day confounders that affect short daytime measurements. Vagally
   mediated HRV indices such as RMSSD, and nocturnal heart rate, respond to
   the preceding day's training: several studies report suppressed nocturnal
   HRV and elevated heart rate after intense or prolonged exercise
   (Hynynen et al., 2010; Myllymäki et al., 2012; Stanley et al., 2013).

3. **Single values mislead; trends and kinetics inform.** Day-to-day HRV is
   noisy. Rolling averages and their relationship to an individual's own
   baseline are more informative than isolated readings (Plews et al., 2013;
   Buchheit, 2014). Beyond nightly averages, the *shape* of the overnight
   time course (how quickly heart rate falls and HRV rises after sleep onset)
   may carry information about incomplete recovery that a whole-night mean
   hides. Testing that idea is the long-term aim of this project.

The intended outcome is an individual dose-response description: given
training characterised in laboratory-anchored intensity domains, how do
overnight heart rate and HRV respond, and over what time course do they
return to baseline?

**Why build this in the open.** Consumer recovery scores cannot be inspected.
Here every calculation is written down ([docs/methods.md](docs/methods.md)),
every known weakness is listed, and each method is to be validated against an
established reference before conclusions are drawn from it.

**Measurement basis.** The Polar H10 was chosen because its R-R interval
output has been compared against ECG Holter recordings (Gilgen-Ammann et al.,
2019). That study concerns the sensor; it does not validate this project's
processing. HRV definitions follow the Task Force (1996) standards.

---

## Pipeline at a glance

```text
Polar H10  ──>  SensorForge Pro  ──>  cloud-synced archive (ZIP per recording)
(chest strap)   (phone app)                    │
                                               ▼
                                  scripts/sleep_import  (Bash)
                                  find newest archive, extract HR + RR,
                                  validate, stage as hr.csv / rr.csv
                                               │
                                               ▼
                                  Excel workbook (Power Query + formulas)
                                  whole-night summary, 5-minute windows,
                                  preliminary artefact screening, dashboard
                                               │
                                               ▼
                                  VBA macro: refresh, then store the night
                                  in a longitudinal log with 7- and 28-night
                                  rolling means
```

---

## Current capabilities

| Area | Feature | Implementation | Validation |
|---|---|---|---|
| Acquisition | Overnight heart rate (about 1 Hz) and beat-to-beat R-R intervals from a Polar H10 via SensorForge Pro | Working | Sensor validated by others; this pipeline not validated |
| Acquisition (feasibility) | Simultaneous ECG, three-axis accelerometer, heart rate and R-R interval acquisition with SensorForge Pro | Demonstrated in a separate 10-minute test recording; not yet part of overnight recordings or of any analysis | Not validated |
| Import | [`scripts/sleep_import`](scripts/sleep_import): selects the newest archive, extracts HR and RR streams, checks row counts and headers, stages them for the workbook | Working, covered by an automated test on synthetic data | Not applicable |
| Ingestion | Power Query loads the staged CSV files into the workbook | Working | Not applicable |
| Whole-night summary | Recording duration; mean, minimum and maximum heart rate; mean R-R interval; RMSSD; lnRMSSD; SDNN; pNN50 | Working | Not validated against reference software |
| Artefact screening | Rule-based flagging of implausible R-R intervals; "screened" RMSSD and lnRMSSD that exclude flagged pairs; percentage of intervals flagged and pairs excluded | Working, **preliminary and unvalidated** | Not compared with any reference method; flags and excludes only, no correction |
| Time course | Consecutive 5-minute windows: mean heart rate, RMSSD (original and screened), lnRMSSD, SDNN, pNN50, flagged percentage, interval count | Working | Not validated |
| Dashboard | Overnight summary panel; heart rate and RMSSD against elapsed time, sized automatically to the recording length | Working | Not applicable |
| Storage | VBA macro refreshes the data, checks the summary is complete, and adds or updates the night in a longitudinal log. A recording is identified by its UTC start time, so re-importing never duplicates a night and manual entries are kept | Working, covered by an automated functional test on synthetic data | Not applicable |
| Longitudinal | 7-night and 28-night rolling means of heart rate and lnRMSSD (original and screened); trend charts. Unavailable means are left as gaps, never plotted as zero | Working, functionally tested on synthetic data; with real data, outputs appear only once 7 and 28 nights have been logged | Not validated |
| Time zone | Local recording dates derived from a user-maintained table of dated UTC offsets; identification and duplicate prevention use UTC only | Working, functionally tested on synthetic data | Not applicable |
| Context | Manual log fields: bedtime, wake time, exercise type, duration, intensity and end time, last caffeine, sleep quality, fatigue, sleeping altitude, notes | Working (manual entry) | Subjective |

Exact formulas, thresholds and edge-case behaviour are in
[docs/methods.md](docs/methods.md). The workbook's structure, its Power Query
code and its VBA module are documented and stored as text in
[excel/](excel/README.md).

### Not yet implemented

**ECG and accelerometer: acquisition demonstrated, processing under
development.** Simultaneous acquisition of ECG, three-axis accelerometer,
heart rate and R-R intervals with SensorForge Pro was successfully
demonstrated in a separate 10-minute test recording. That test shows the four
streams can be captured together. It is not an overnight recording, and its
signals have not been analysed or checked against a reference.

Overnight ECG and accelerometer processing is still under development. The
overnight pipeline uses heart rate and R-R intervals only; no code in this
repository reads ECG or accelerometer data, and no result reported here
depends on those signals. Everything in the table below is a proposal.

| Proposed feature | Status | Reference method planned for validation |
|---|---|---|
| Python ECG signal processing | Planned | — |
| R-peak detection from raw ECG | Planned | Annotated open ECG databases; device R-R output |
| Validated R-R artefact correction | Planned | Published correction algorithms (e.g. Lipponen & Tarvainen, 2019); established HRV software |
| ECG-derived respiratory rate | Planned, unvalidated | Simultaneous respiration reference |
| Accelerometer-based movement and body position | Planned, unvalidated | Direct observation / annotated protocol |
| Sleep-stage classification | Planned, unvalidated; cardiorespiratory staging is an estimate at best | Polysomnography, if access can be arranged |
| Polar and Stryd training-data integration | Planned | — |
| Laboratory intensity domains (LT1, LT2) applied to training data | Planned | Laboratory lactate testing |
| Individual overnight recovery kinetics | Planned, exploratory | — |
| Training-recovery dose-response modelling | Planned, exploratory | Out-of-sample prediction |
| Public interactive website with selected data | Planned | — |

See the [roadmap](docs/roadmap.md) for ordering and for what "done" means for
each item.

---

## Limitations

These apply to the project as it stands and should be read before
interpreting any output.

**Design**

- **One participant.** This is an n-of-1 experiment by its author. Findings
  cannot be generalised and there is no blinding.
- **Observational.** Training, sleep, caffeine, altitude and illness vary
  together; associations found here are not causal estimates.
- **Short history.** Rolling baselines need weeks of data before they mean
  anything.

**Measurement**

- Only the device's own heart rate and R-R interval outputs are used. Beat
  detection happens inside the sensor and cannot be inspected until raw ECG
  processing exists. Simultaneous ECG and accelerometer acquisition has been
  demonstrated only in a 10-minute test; overnight processing of those
  signals is still under development.
- Whole-night metrics mix sleep stages, awakenings and movement. No sleep
  staging, no sleep-onset detection and no movement exclusion is applied.
- Recording start and end are whatever the athlete pressed, not sleep onset
  and wake time.

**Processing**

- **The R-R artefact screening is preliminary and unvalidated.** It is a
  simple rule (absolute limits plus a 20 % change criterion). It flags and
  excludes; it does not correct. It can flag genuine
  rapid changes and can miss artefacts, and it has not been compared with any
  reference method.
- SDNN and pNN50 are computed without artefact screening.
- Elapsed time for R-R data is the running sum of intervals, so missing beats
  shorten the time axis.
- Rolling means are taken over consecutive log rows, not calendar days;
  missed nights are not accounted for.
- Local dates depend on a hand-maintained table of UTC offsets. There is no
  time-zone database, so daylight-saving changes and travel must be entered
  by the user. Recording identification uses UTC and is unaffected.
- **Known stability issue.** Excel sometimes crashes while the workbook's
  R-R table is being refreshed (observed on one Excel version, under
  automation). No log entry is lost or duplicated, and repeating the import
  works, but unsaved edits are lost. See
  [excel/README.md](excel/README.md#known-issue-excel-can-crash-during-a-refresh).
- The analysis lives in a spreadsheet: flexible for prototyping, but hard to
  test and to review. Moving the calculations to tested Python code is the
  first development priority.

A fuller, itemised list is in [docs/methods.md](docs/methods.md#known-limitations).

---

## Repository layout

```text
.
├── README.md
├── scripts/
│   └── sleep_import            Import script (Bash)
├── config/
│   └── sleep_import.env.example  Configuration template (no real values)
├── excel/
│   ├── README.md               Workbook structure, template plan
│   ├── power-query/            Power Query (M) source, as text
│   ├── vba/                    VBA module, as text
│   └── template/               Clean workbook template (synthetic data only)
├── tools/
│   ├── make_synthetic_night.py Synthetic recording generator
│   ├── build_template.ps1      Builds the workbook template (drives Excel)
│   ├── scrub_workbook.py       Removes save-time residue from a workbook
│   ├── audit_workbook.py       Checks a workbook for private residue
│   └── prepublish_check.sh     Checks tracked files before pushing
├── tests/
│   ├── test_sleep_import.sh    End-to-end import test (synthetic data)
│   └── test_template.ps1       Workbook and macro functional test (Excel)
├── docs/
│   ├── methods.md              Every calculation, as implemented
│   ├── data-format.md          Recording file layout
│   ├── roadmap.md              Development plan and validation gates
│   ├── privacy.md              What is and is not published
│   └── publishing-checklist.md Steps before the repository goes public
├── data/                       Local data only; contents are git-ignored
├── analysis/                   Planned Python package (empty)
└── site/                       Planned public website (empty)
```

---

## Getting started

### Requirements

- A Polar H10 and the SensorForge Pro app, exporting one ZIP archive per
  recording to a folder the computer can read.
- Bash with `unzip` (Linux, macOS, or Windows via WSL).
- Microsoft Excel for Windows (Microsoft 365) for the workbook: it relies on
  Power Query, dynamic arrays (`LET`, `FILTER`, `SEQUENCE`) and VBA.
- Python 3.9+ for the tools and tests (standard library only).

### Import script

```bash
mkdir -p ~/.config/athlete-physiology-lab
cp config/sleep_import.env.example ~/.config/athlete-physiology-lab/sleep_import.env
# edit the copy: set SLEEP_BASE_DIR and POLAR_DEVICE_ID

install -m 755 scripts/sleep_import ~/bin/sleep_import
sleep_import
```

The script expects this layout under `SLEEP_BASE_DIR` (both folder names can
be overridden):

```text
Archive/         SF_<YYYYMMDD-HHMMSS>_Polar-H10-<ID>.zip   (one per recording)
Current Night/   hr.csv, rr.csv                            (overwritten each import)
```

### Run the tests

Import script (Linux, macOS or WSL):

```bash
bash tests/test_sleep_import.sh
```

Workbook template and its macro (Windows with Excel):

```powershell
powershell -ExecutionPolicy Bypass -File tests\test_template.ps1
```

Both tests generate synthetic recordings in a temporary folder and work on
disposable copies; they never read real data. The workbook test enables
macros only inside the Excel instance it starts.

### Workbook

[`excel/template/athlete-recovery-template.xlsm`](excel/template/athlete-recovery-template.xlsm)
is the analysis workbook loaded with synthetic data. Open it, enable macros,
set the `DataFolder` parameter in Power Query to the folder holding your
staged `hr.csv` and `rr.csv`, enter your UTC offset on the `Settings` sheet,
and press the dashboard button. Details, and
the workbook's structure, are in [excel/README.md](excel/README.md); its
Power Query and VBA sources are stored as text in `excel/`.

---

## Data and privacy

This repository contains code, documentation and synthetic examples. It does
not contain the author's recordings. Raw recordings, working workbooks,
session metadata (which includes body measurements and device serial numbers)
and all credentials are excluded by [.gitignore](.gitignore) and checked by
[tools/prepublish_check.sh](tools/prepublish_check.sh). The one workbook in
the repository is a template that holds synthetic values only. Selected, deliberately
chosen data will be published later with the planned website. The policy is
described in [docs/privacy.md](docs/privacy.md).

---

## Roadmap summary

1. **Reproducible core** — port the workbook calculations to tested Python and
   show the two agree on the same nights.
2. **Signal quality** — overnight ECG and accelerometer recording and import;
   R-peak detection; validated artefact correction.
3. **Richer overnight physiology** — respiration, movement, body position,
   sleep-stage estimates.
4. **Training integration** — Polar and Stryd data; LT1/LT2 intensity domains.
5. **Modelling** — overnight recovery kinetics; dose-response.
6. **Communication** — public interactive website.

Details and validation gates: [docs/roadmap.md](docs/roadmap.md).

---

## References

- Buchheit M. Monitoring training status with HR measures: do all roads lead
  to Rome? *Front Physiol.* 2014;5:73. PMID 24578692.
- Gilgen-Ammann R, Schweizer T, Wyss T. RR interval signal quality of a heart
  rate monitor and an ECG Holter at rest and during exercise. *Eur J Appl
  Physiol.* 2019;119(7):1525-1532. PMID 31004219.
- Hynynen E, Vesterinen V, Rusko H, Nummela A. Effects of moderate and heavy
  endurance exercise on nocturnal HRV. *Int J Sports Med.* 2010;31(6):428-432.
  PMID 20419617.
- Lipponen JA, Tarvainen MP. A robust algorithm for heart rate variability
  time series artefact correction using novel beat classification. *J Med Eng
  Technol.* 2019;43(3):173-181. PMID 31314618.
- Myllymäki T, Rusko H, Syväoja H, Juuti T, Kinnunen ML, Kyröläinen H. Effects
  of exercise intensity and duration on nocturnal heart rate variability and
  sleep quality. *Eur J Appl Physiol.* 2012;112(3):801-809. PMID 21667290.
- Plews DJ, Laursen PB, Stanley J, Kilding AE, Buchheit M. Training adaptation
  and heart rate variability in elite endurance athletes: opening the door to
  effective monitoring. *Sports Med.* 2013;43(9):773-781. PMID 23852425.
- Stanley J, Peake JM, Buchheit M. Cardiac parasympathetic reactivation
  following exercise: implications for training prescription. *Sports Med.*
  2013;43(12):1259-1277. PMID 23912805.
- Task Force of the European Society of Cardiology and the North American
  Society of Pacing and Electrophysiology. Heart rate variability: standards
  of measurement, physiological interpretation and clinical use.
  *Circulation.* 1996;93(5):1043-1065. PMID 8598068.

---

## Disclaimer

This project is for research and education. It is not a medical device and is
not intended to diagnose, treat or prevent any condition. Polar, Stryd and
SensorForge Pro are products of their respective owners; this project is not
affiliated with or endorsed by them.

## License

No license has been chosen yet. One will be added before the repository is
made public (see [docs/publishing-checklist.md](docs/publishing-checklist.md)).
