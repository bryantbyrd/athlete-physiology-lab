# Changelog

Notable changes to this project. Versions follow
[Semantic Versioning](https://semver.org/); while the version is below 1.0,
anything may change between releases.

## 0.1.0 — 2026-11-26

First public release: a proof of concept. Nothing in it has been validated
against a reference method.

### Included

- `scripts/sleep_import`: Bash script that stages the newest SensorForge Pro
  recording (heart rate and R-R intervals) for analysis.
- Excel workbook template with synthetic data: whole-night and 5-minute
  heart-rate and HRV metrics, preliminary R-R artefact screening, dashboard,
  nightly log with 7- and 28-night rolling means, trend charts, time-zone
  table.
- Power Query and VBA sources stored as text.
- Tools: synthetic recording generator, template build and scrub scripts,
  workbook audit, pre-publication privacy check.
- Tests: import script (17 checks) and workbook macro (50 checks), both on
  synthetic data.
- Documentation: methods as implemented, data format, roadmap, privacy
  policy, test report.

### Known limitations

- **Excel intermittently crashes while the workbook refreshes.** See
  "Known Limitations" in the README and
  [docs/test-report-v0.1.0.md](docs/test-report-v0.1.0.md).
- R-R artefact screening is preliminary and unvalidated.
- Overnight ECG and accelerometer processing is not implemented;
  simultaneous acquisition has only been demonstrated in a 10-minute test.
- Single participant; early-stage dataset; no personal data is published.
