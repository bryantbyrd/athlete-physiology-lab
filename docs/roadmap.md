# Roadmap

Status key: **Working** (in routine use), **Planned** (not started),
**Exploratory** (research question; may not succeed).

Nothing in milestones 1-6 is implemented. Each has a validation gate: the
feature is not described as working until the gate has been met and the
result written up in `docs/`.

## Milestone 0 — Prototype (Working)

- Polar H10 overnight HR and R-R acquisition through SensorForge Pro.
- Bash import and validation script.
- Excel analysis: whole-night and 5-minute HR/HRV, preliminary (unvalidated)
  artefact screening, dashboard, longitudinal log with 7- and 28-night
  rolling means.
- Simultaneous ECG, accelerometer, heart rate and R-R acquisition with
  SensorForge Pro demonstrated in a separate 10-minute test recording
  (acquisition only; no processing).

Open items in this milestone:

- [x] Build a clean workbook template (see `excel/README.md`).
- [x] In the template: separate RMSSD and lnRMSSD scales on the trend charts,
      correct the lnRMSSD labels, plot unavailable rolling means as gaps,
      let chart axes scale automatically, and replace the fixed UTC offset
      with a time-zone table.
- [x] Functional test of the template and its macro on synthetic data.
- [ ] Resolve the intermittent Excel crash during refresh of the R-R table
      (see `excel/README.md`, "Known issue").
- [x] Choose a license (MIT).
- [ ] Accumulate enough nights for the rolling baselines to be populated.

## Milestone 1 — Reproducible core in Python (Planned)

Goal: the calculations in `docs/methods.md` exist as tested Python code.

Excel was the proof-of-concept platform for version 0.1. From this milestone
on, development moves to Python for computational efficiency, reliability
(Excel intermittently crashes while the workbook refreshes) and the signal
processing that later milestones need. The workbook stays as the reference
implementation of 0.1.

- Read SensorForge archives directly (HR, RR, markers, metadata).
- Reimplement per-interval columns, screening, whole-night and 5-minute
  metrics, rolling means.
- Unit tests on synthetic data with known answers.
- Local dates from the IANA time-zone database, replacing the
  hand-maintained offset table; calendar-based rolling windows; gap detection
  from receive timestamps.

**Gate:** Python output matches the workbook on the same nights to within
rounding, with any intended differences documented.

## Milestone 2 — ECG and signal quality (Planned)

- Overnight ECG and accelerometer recording and import. Under development:
  so far only a 10-minute simultaneous-acquisition test exists.
- R-peak detection from ECG.
- Artefact *correction* (not only exclusion) using a published algorithm.
- Signal-quality indices per window; minimum-data rules for reporting.

**Gates:**
- R-peak detection: sensitivity and positive predictive value against
  annotated open ECG databases, and agreement with the sensor's own R-R
  output on the project's recordings.
- HRV metrics: agreement (bias and limits of agreement) with established HRV
  analysis software on identical R-R series.

## Milestone 3 — Richer overnight physiology (Planned, unvalidated)

- ECG-derived respiratory rate.
- Movement and body position from the accelerometer.
- Sleep/wake and sleep-stage *estimates* from cardiorespiratory and movement
  features.

**Gates:**
- Respiratory rate: comparison with a simultaneous respiration reference.
- Body position: comparison with an annotated position protocol.
- Sleep staging: comparison with polysomnography if access can be arranged.
  Without it, stage outputs stay labelled as unvalidated estimates and are
  not used as inputs to conclusions.

## Milestone 4 — Training data and intensity domains (Planned)

- Import Polar and Stryd training sessions.
- Record laboratory test results (LT1, LT2) with test date and protocol.
- Express each session as time and work relative to LT1 and LT2. LT1 is
  used as the moderate–heavy boundary. LT2 is not assumed to equal critical
  power or critical speed, so any heavy–severe boundary based on it is
  labelled as an approximation; estimating critical power or critical speed
  directly is a candidate addition.

**Gate:** documented laboratory protocol; domain boundaries traceable to a
dated test; re-test policy stated.

## Milestone 5 — Recovery kinetics and dose-response (Exploratory)

- Describe the overnight time course of heart rate and HRV with fitted
  parameters (for example, time to nadir, rate of change after sleep onset).
- Relate those parameters, and nightly means, to the preceding training dose
  and to contextual factors.

**Gates:**
- Analysis plan written before modelling; model checks reported.
- Out-of-sample evaluation; uncertainty reported for every estimate.
- Explicit statement that results describe one individual.

## Milestone 6 — Public website (Planned)

- Interactive pages demonstrating the methods on selected data from the
  longitudinal experiment.
- Each chart links to the method that produced it and states its validation
  status.

**Gate:** data release reviewed against `docs/privacy.md`; only deliberately
selected, de-identified data published.

## Ordering principle

Measurement quality before interpretation. Milestones 1 and 2 come first
because every later analysis inherits their errors.
