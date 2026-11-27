# athlete-physiology-lab

An open, single-athlete monitoring project that aims to connect three things
that are usually analysed apart: laboratory-derived physiological thresholds,
day-to-day training load, and overnight cardiovascular and autonomic recovery.

> **Version 0.1.0 — proof of concept.**
> The working part today is an overnight heart-rate and heart-rate-variability
> (HRV) pipeline built on a Polar H10 chest strap, a Bash import script and an
> Excel workbook. Everything else in this document is a plan. None of the
> methods has yet been validated against a reference method, and the
> longitudinal dataset is at an early stage.
>
> **Excel intermittently crashes while the workbook refreshes**; see
> [Known Limitations](#known-limitations) before using it.
>
> This is a personal research project, not a medical device, and nothing here
> is medical advice. Feedback and collaboration are welcome: see
> [Feedback and collaboration](#feedback-and-collaboration).

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
   in a laboratory test provide individualised intensity anchors, and time
   and work accumulated relative to them is a more defensible description of
   training dose than fixed percentages of maximum heart rate or pace
   (Jamnick et al., 2020). The anchors are not equally well supported as
   domain boundaries. LT1 has reasonable support as the boundary between the
   moderate and heavy domains. LT2 should **not** be assumed to be
   equivalent to critical power or critical speed, which have stronger
   support as the boundary between the heavy and severe domains. LT2
   values depend on how the threshold is defined and determined, and there
   is little evidence that they reliably mark that boundary. In this
   project LT2 is treated as a laboratory reference point, and the
   heavy–severe boundary it implies is labelled as an approximation.

2. **Sleep is a useful standardised window for measuring autonomic state.**
   Overnight recordings reduce some of the confounders that affect short
   daytime measurements, such as physical activity, food, caffeine and
   mental stress during the recording. They do not remove confounding.
   Overnight heart rate and HRV still vary with sleep stage and awakenings,
   breathing rate and depth, body position and circadian rhythm (Quigley et
   al., 2024). Version 0.1 measures none of these; see
   [Known Limitations](#known-limitations). Vagally mediated HRV indices
   such as RMSSD, and nocturnal heart rate, respond to the preceding day's
   training: several studies report suppressed nocturnal
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

**Relation to existing dose-response research.** Training–recovery
dose-response relationships are already being studied at scale with
consumer wearables. For example, Leota et al. (2025) analysed about four
million nights from 14,689 people wearing a wrist-worn biometric device and
found that later and more strenuous evening exercise was associated with
higher nocturnal resting heart rate and lower nocturnal HRV. This project
does not replace that kind of work and cannot match its sample size. It
asks a narrower question with different measurements: one athlete, R-R
intervals from a chest-strap ECG sensor (with raw ECG processing planned),
openly documented calculations, and training dose expressed relative to
laboratory-determined thresholds rather than a device's proprietary strain
or load score. Whether that adds anything to population-level findings is
an open question this project is meant to test, not a claim.

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

## Platform: Excel now, Python next

Excel is the **initial proof-of-concept platform**, not the intended home of
this project. It was chosen to get from raw recordings to inspectable numbers
quickly: every intermediate value is visible in a cell, formulas can be
changed and their effect seen at once, and no software has to be written
before the first night can be looked at.

That choice has reached its limits, and this release documents them rather
than hiding them:

- **Reliability.** Excel intermittently crashes while this workbook refreshes
  (see [Known Limitations](#known-limitations)).
- **Computational efficiency.** A night of beat-to-beat data is tens of
  thousands of rows of interdependent formulas, some of them quadratic in the
  number of beats. Recalculation is slow and grows with recording length.
- **Testability.** Spreadsheet logic cannot be unit-tested or reviewed line
  by line; the functional test in this repository has to drive Excel from
  outside.
- **Signal processing.** ECG filtering, R-peak detection, artefact
  correction, respiration and movement analysis are not practical in a
  spreadsheet.

**Future development moves to Python**, for computational efficiency,
reliability and advanced physiological signal processing. The first
milestone is a tested Python implementation that reproduces the workbook's
numbers on the same recordings, so that the transition is verified rather
than assumed. ECG and accelerometer processing, validated artefact
correction and everything later on the [roadmap](docs/roadmap.md) will be
built in Python only. The workbook will remain in the repository as the
reference implementation of version 0.1 and as a way to inspect a single
night by eye.

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

## Known Limitations

These apply to the project as it stands and should be read before using the
workbook or interpreting any output.

### Intermittent Excel crashes during refresh

**Excel sometimes crashes, or the refresh fails, while the workbook loads a
recording.** This was found during release testing and is not yet fixed.

- **What happens.** While the R-R interval table is being refreshed, Excel
  can terminate with an access violation inside `EXCEL.EXE`, or the
  workbook's macro reports "Refresh failed" and saves nothing. The failure is
  intermittent: the same step succeeds when repeated.
- **How often.** In the functional test the refresh failed in 6 of 74 macro
  runs (about 8 %) across two complete runs. In separate trials that
  refreshed the tables repeatedly, Excel crashed in 14 of 20 sessions, after
  between 1 and 12 refresh cycles. Two earlier runs of the functional test
  were stopped by such a crash before the test was made to recover from it.
- **Where it comes from.** It occurs in the workbook as originally built, not
  only in the published template, and with the window visible or hidden,
  automatic or manual calculation, new or unchanged data. Refreshing the
  heart-rate table alone never failed. No single formula has been identified
  as the cause.
- **What it does not do.** The failure happens before anything is written to
  the nightly log. No partial, incorrect or duplicate log entry was produced
  in any run, and repeating the import after a restart gave the correct
  result every time.
- **What it can cost you.** Any edit made since the workbook was last saved,
  including manually typed context fields.
- **What is not known.** Testing was done by automation on a single Excel
  version (Microsoft 365, 16.0.20625.20108, 64-bit). Whether it occurs at a
  similar rate when the dashboard button is pressed by hand, or on other
  versions, has not been established. Reports are welcome.
- **What to do meanwhile.** Save the workbook before pressing the dashboard
  button. If Excel closes, reopen the workbook and press the button again.

Full details: [docs/test-report-v0.1.0.md](docs/test-report-v0.1.0.md) and
[excel/README.md](excel/README.md#known-issue-excel-can-crash-during-a-refresh).
This is the main practical reason for moving the calculations to Python.

### Design

- **One participant.** This is an n-of-1 experiment by its author. Findings
  cannot be generalised and there is no blinding.
- **Observational.** Training, sleep, caffeine, altitude and illness vary
  together; associations found here are not causal estimates.
- **Short history.** Rolling baselines need weeks of data before they mean
  anything.

### Measurement

- Only the device's own heart rate and R-R interval outputs are used. Beat
  detection happens inside the sensor and cannot be inspected until raw ECG
  processing exists. Simultaneous ECG and accelerometer acquisition has been
  demonstrated only in a 10-minute test; overnight processing of those
  signals is still under development.
- Whole-night metrics mix sleep stages, awakenings and movement. No sleep
  staging, no sleep-onset detection and no movement exclusion is applied.
  Respiration, body position and circadian timing are not measured or
  adjusted for either, so night-to-night differences may reflect them as
  well as recovery.
- Recording start and end are whatever the athlete pressed, not sleep onset
  and wake time.

### Processing

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
- The analysis lives in a spreadsheet: flexible for prototyping, but slow,
  hard to test and hard to review. Moving the calculations to tested Python
  code is the first development priority.

A fuller, itemised list is in [docs/methods.md](docs/methods.md#known-limitations).

---

## Test results for this release

Software tests only, on synthetic data. They show that the software does
what it is specified to do; they do not validate any metric physiologically.

| Test | Outcome |
|---|---|
| Import script, 17 checks | 17 passed |
| Workbook template and macro, 50 checks over 30 synthetic nights (final run) | 50 passed. The refresh failed in 2 of 36 macro runs; each passed on the first retry |
| Same test, previous complete run (47 checks at that time) | 47 passed. The refresh failed in 4 of 38 macro runs; one recording needed three retries |
| Earlier runs of the workbook test | 2 stopped when Excel crashed; 2 stopped on errors in the test script, since fixed |
| Repeated-refresh trials, 20 Excel sessions | Excel crashed in 14 |
| Privacy checks on the release files and the template | Passed |

What the workbook test covers: a new recording adds one log entry;
re-importing an existing recording never adds a duplicate; manually entered
notes survive a re-import; recordings are identified by UTC start time and
local dates follow the time-zone table; rolling means are `#N/A` until 7 or
28 nights exist and then match an independent calculation; trend charts grow
with the log and show every value.

The test recovers from Excel failures by saving after each step, restarting
Excel and repeating the failed step, and it reports how many times it had to.
The full account, including every failed run, is in
[docs/test-report-v0.1.0.md](docs/test-report-v0.1.0.md).

---

## Repository layout

```text
.
├── README.md
├── CHANGELOG.md
├── LICENSE                     MIT
├── CONTRIBUTING.md             How to give feedback and contribute
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
│   ├── test-report-v0.1.0.md   What was tested for this release, and what failed
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
   show the two agree on the same nights. This also retires the Excel
   refresh problem.
2. **Signal quality** — overnight ECG and accelerometer recording and import;
   R-peak detection; validated artefact correction.
3. **Richer overnight physiology** — respiration, movement, body position,
   sleep-stage estimates.
4. **Training integration** — Polar and Stryd data; LT1/LT2 intensity domains.
5. **Modelling** — overnight recovery kinetics; dose-response.
6. **Communication** — public interactive website.

Details and validation gates: [docs/roadmap.md](docs/roadmap.md).

---

## Feedback and collaboration

This project is published early, with its weaknesses listed, because outside
criticism is more useful now than after the methods have hardened.
Suggestions and collaboration from researchers and developers are welcome,
in particular on:

- **Methods** — anything in [docs/methods.md](docs/methods.md) that is wrong,
  weak or better done another way: HRV definitions, windowing, artefact
  handling, rolling baselines.
- **Validation** — reference methods, open datasets and study designs that
  would make the planned comparisons convincing.
- **The Excel refresh crash** — reproductions on other Excel versions, or a
  diagnosis.
- **The move to Python** — architecture, libraries, and later code review.
- **Related work** — if you study athlete monitoring, wearable validation,
  HRV methodology or sleep physiology and see common ground.

Open an issue on GitHub to start a conversation; there are templates for
scientific feedback and for bug reports. See
[CONTRIBUTING.md](CONTRIBUTING.md) for details, including one firm rule:
never post personal physiological data, crash dumps or workbooks containing
real recordings.

---

## References

- Buchheit M. Monitoring training status with HR measures: do all roads lead
  to Rome? *Front Physiol.* 2014;5:73. [PMID 24578692](https://pubmed.ncbi.nlm.nih.gov/24578692/).
- Gilgen-Ammann R, Schweizer T, Wyss T. RR interval signal quality of a heart
  rate monitor and an ECG Holter at rest and during exercise. *Eur J Appl
  Physiol.* 2019;119(7):1525-1532. [PMID 31004219](https://pubmed.ncbi.nlm.nih.gov/31004219/).
- Hynynen E, Vesterinen V, Rusko H, Nummela A. Effects of moderate and heavy
  endurance exercise on nocturnal HRV. *Int J Sports Med.* 2010;31(6):428-432.
  [PMID 20419617](https://pubmed.ncbi.nlm.nih.gov/20419617/).
- Jamnick NA, Pettitt RW, Granata C, Pyne DB, Bishop DJ. An examination and
  critique of current methods to determine exercise intensity. *Sports Med.*
  2020;50(10):1729-1756.
  doi:[10.1007/s40279-020-01322-8](https://doi.org/10.1007/s40279-020-01322-8).
  [PMID 32729096](https://pubmed.ncbi.nlm.nih.gov/32729096/).
- Leota J, Presby DM, Le F, Czeisler MÉ, Mascaro L, Capodilupo ER, et al.
  Dose-response relationship between evening exercise and sleep. *Nat
  Commun.* 2025;16(1):3297.
  doi:[10.1038/s41467-025-58271-x](https://doi.org/10.1038/s41467-025-58271-x).
  [PMID 40234380](https://pubmed.ncbi.nlm.nih.gov/40234380/).
- Lipponen JA, Tarvainen MP. A robust algorithm for heart rate variability
  time series artefact correction using novel beat classification. *J Med Eng
  Technol.* 2019;43(3):173-181. [PMID 31314618](https://pubmed.ncbi.nlm.nih.gov/31314618/).
- Myllymäki T, Rusko H, Syväoja H, Juuti T, Kinnunen ML, Kyröläinen H. Effects
  of exercise intensity and duration on nocturnal heart rate variability and
  sleep quality. *Eur J Appl Physiol.* 2012;112(3):801-809. [PMID 21667290](https://pubmed.ncbi.nlm.nih.gov/21667290/).
- Plews DJ, Laursen PB, Stanley J, Kilding AE, Buchheit M. Training adaptation
  and heart rate variability in elite endurance athletes: opening the door to
  effective monitoring. *Sports Med.* 2013;43(9):773-781. [PMID 23852425](https://pubmed.ncbi.nlm.nih.gov/23852425/).
- Quigley KS, Gianaros PJ, Norman GJ, Jennings JR, Berntson GG, de Geus EJC.
  Publication guidelines for human heart rate and heart rate variability
  studies in psychophysiology—Part 1: Physiological underpinnings and
  foundations of measurement. *Psychophysiology.* 2024;61(9):e14604.
  doi:[10.1111/psyp.14604](https://doi.org/10.1111/psyp.14604).
  [PMID 38873876](https://pubmed.ncbi.nlm.nih.gov/38873876/).
- Stanley J, Peake JM, Buchheit M. Cardiac parasympathetic reactivation
  following exercise: implications for training prescription. *Sports Med.*
  2013;43(12):1259-1277. [PMID 23912805](https://pubmed.ncbi.nlm.nih.gov/23912805/).
- Task Force of the European Society of Cardiology and the North American
  Society of Pacing and Electrophysiology. Heart rate variability: standards
  of measurement, physiological interpretation and clinical use.
  *Circulation.* 1996;93(5):1043-1065. [PMID 8598068](https://pubmed.ncbi.nlm.nih.gov/8598068/).

---

## Disclaimer

This project is for research and education. It is not a medical device and is
not intended to diagnose, treat or prevent any condition. Polar, Stryd and
SensorForge Pro are products of their respective owners; this project is not
affiliated with or endorsed by them.

## License

Released under the [MIT License](LICENSE): you may use, modify and
redistribute the code, documentation, workbook template and synthetic
examples, provided the copyright notice is kept.

Personal data published later for the project website is not covered by this
license and will carry its own terms.
