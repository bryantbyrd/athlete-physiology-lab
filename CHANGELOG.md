# Changelog

Notable changes to this project. Versions follow
[Semantic Versioning](https://semver.org/); while the version is below 1.0,
anything may change between releases.

## Unreleased

No change to any calculation. The scientific documentation changes below
are documentation only; the demonstration dataset changes the data the
public workbook opens with and its dashboard formatting.

### Added
- **Demonstration dataset with real physiological data**
  (`examples/demo-night-2026-11-26/`): one overnight recording voluntarily
  published by the project author, with authorisation limited to that
  recording. Values unchanged; clock time removed (start shifted to 00:00
  UTC, elapsed time exact); sensor ID and metadata left out. The data is
  licensed CC BY-NC 4.0; the software remains MIT.
- `tools/deidentify_recording.py`: prepares an authorised recording for
  publication and verifies that only timestamps changed.
- README: macro security warnings when opening a downloaded workbook, and
  a picture of the dashboard (`docs/images/demo-dashboard.png`).
- `tools/prepublish_check.sh`: exempts the two demonstration files by exact
  path, pins them to `SHA256SUMS`, checks they start at 00:00 UTC, requires
  stated terms of use, and compares the workbook's cached data with them.

### Changed
- Public workbook now opens with the demonstration night instead of a
  synthetic night. Verified against the author's working workbook: all 14
  whole-night values and all 840 five-minute values identical. Automated
  tests still use synthetic data only (`tests/test_template.ps1`: 50 of 50
  checks passed).
- Dashboard formatting: consistent decimals, banded summary table, charts
  drawn with straight segments instead of Excel's smoothed lines, resized
  charts, heart-rate axis from 30 bpm, a note describing the data. No
  formula or value changed.
- `tools/build_template.ps1`: accepts any authorised or synthetic data
  folder and a dashboard note (`-DataNoteFile`).
- README, privacy policy, workbook documentation and publishing checklist
  describe the demonstration dataset and its limits.
- README rationale: LT1 and LT2 described as individualised intensity
  anchors; LT2 explicitly not treated as equivalent to critical power or
  critical speed (also in the roadmap, milestone 4).
- README rationale: overnight monitoring described as reducing some
  confounders, not removing them; sleep stage, respiration, body position
  and circadian rhythm named, and added to Known Limitations.
- README: new paragraph relating the project to existing wearable-based
  training–recovery dose-response research.
- References: added Jamnick et al. (2020), Quigley et al. (2024) and Leota et
  al. (2025); every reference now links to PubMed, new ones also to their DOI.

### Fixed
- `docs/methods.md` said the `.xlsm` file is not under version control. The
  sanitised template is tracked; only the private working workbook is not.

### Known issues
- Building the workbook from the full 7-hour demonstration night crashed
  Excel during the R-R refresh in 18 of 21 attempts (see Known Limitations).

## 0.1.0 (2026-11-26)

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
- MIT License.

### Known limitations

- **Excel intermittently crashes while the workbook refreshes.** See
  "Known Limitations" in the README and
  [docs/test-report-v0.1.0.md](docs/test-report-v0.1.0.md).
- R-R artefact screening is preliminary and unvalidated.
- Overnight ECG and accelerometer processing is not implemented;
  simultaneous acquisition has only been demonstrated in a 10-minute test.
- Single participant; early-stage dataset; no personal data is published.
