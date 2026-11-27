# Workbook template

`athlete-recovery-template.xlsm` is the analysis workbook with all formulas,
queries, charts and macros. **The values shown when it opens are real
physiological data**: one overnight recording (night of 26 November 2026)
voluntarily published by the project author, who authorised publication of
that recording only. Clock time has been removed; elapsed time is exact.
Source files and preparation:
[../../examples/demo-night-2026-11-26/](../../examples/demo-night-2026-11-26/README.md).

Excel will show macro security warnings when you open a downloaded copy;
see [../../README.md](../../README.md#macro-security-warnings) before
enabling anything.

Before first use, set two things: the `DataFolder` parameter (Power Query)
and your UTC offset in the `TimeZone` table on the `Settings` sheet. Until
the offset is set, local dates are shown in UTC.

How to use it, how it was built, how it differs from the working workbook and
what was checked: [../README.md](../README.md#clean-template).

No other workbook may be placed here; `.gitignore` allows only that one file
name. Do not edit and re-save the template by hand: Excel writes the author
name and printer settings back into the file on every save. Rebuild it with
the tools instead.
