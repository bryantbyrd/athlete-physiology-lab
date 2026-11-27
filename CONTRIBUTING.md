# Feedback and contributions

This is an early, single-author research project, published so that its
methods can be inspected and improved. Criticism is as welcome as code.

## What would help most

**Scientific review**

- Errors or weak choices in [docs/methods.md](docs/methods.md): definitions,
  windowing, the artefact-screening rule, how rolling baselines are formed.
- Better-founded alternatives, with a reference where there is one.
- Advice on validation: reference methods, open datasets, agreement
  statistics, what a convincing comparison would look like.
- Pitfalls in overnight HRV, respiration, movement or sleep-stage estimation
  that the [roadmap](docs/roadmap.md) does not yet anticipate.
- Experience with the Polar H10, SensorForge Pro, Stryd or laboratory
  threshold testing that bears on the plan.

**Engineering**

- The intermittent Excel crash during refresh (see "Known Limitations" in the
  [README](README.md)): reproductions on other Excel versions, a diagnosis,
  or a workbook structure that avoids it.
- The planned move of the calculations to Python: design suggestions, and
  later, code review.
- Bugs in the import script, the tools or the tests.
- Reports of how the template behaves on other systems.

**Collaboration**

If you work on athlete monitoring, HRV methodology, wearable validation or
sleep physiology and see common ground, open an issue describing what you
have in mind.

## How to give feedback

- **Issues** are the main channel. There are templates for scientific
  feedback and for bug reports; a plain issue is fine too.
- **Pull requests** are welcome for documentation, the Bash script, the
  Python tools and the tests. For anything larger than a small fix, please
  open an issue first so the approach can be agreed.
- Say what you know and how you know it. "This threshold differs from the
  one in X (reference)" is more useful than "this looks wrong".

## Ground rules

1. **Never post personal physiological data.** Do not attach recordings,
   `session.json` files, workbooks containing real data, crash dumps or
   screenshots of personal dashboards to issues or pull requests. Reproduce
   problems with `tools/make_synthetic_night.py` instead.
2. **If you notice private information in this repository,** open an issue
   saying where it is without quoting it.
3. Keep claims and their evidence separate. New methods are described as
   proposed until they have met the validation gate in the roadmap.
4. Be civil. Disagreement about methods is expected and useful; disrespect
   is not.

## Documentation style

All human-readable documentation (READMEs, methods, roadmap, changelog,
test reports, dataset notes, issue templates and other Markdown) follows
these rules:

- **No em dashes (U+2014).** Use a comma, colon, semicolon, parentheses or a
  separate sentence, whichever reads most naturally. Labels in lists and
  headings take a colon: `**Methods**: ...`, `## Milestone 1: ...`. Empty
  table cells are written out (for example "Not applicable").
- **En dashes (U+2013, –) only where they carry meaning:** numerical and date ranges
  (`20–30 min`) and paired terms such as `moderate–heavy` or
  `training–recovery`. Ordinary hyphenated compounds and established terms
  keep the hyphen (`R-R interval`, `dose-response`).
- **Plain, academic register.** State what was done, what was found and
  what is not known. Avoid promotional or emphatic language; keep claims
  separate from evidence (ground rule 3).
- **Leave verbatim material as it is:** quotations, reference titles as
  given in PubMed, file contents, command output, checksums and generated
  manifests.
- Source code and its comments are not covered by these rules; change them
  only with the code.

Before committing documentation, this should print nothing:

```bash
git grep -n -P '\x{2014}' -- '*.md'
```

## Before opening a pull request

```bash
bash tests/test_sleep_import.sh
bash tools/prepublish_check.sh
```

If you changed the workbook template or the tools that build it, on Windows
with Excel:

```powershell
powershell -ExecutionPolicy Bypass -File tests\test_template.ps1
```

The workbook test restarts Excel if it crashes and reports how often that
happened; please include that line in your pull request.

## What to expect

This project is maintained by one person alongside other work. Replies may
take time, and not every suggestion will be adopted, but every one will be
read.
