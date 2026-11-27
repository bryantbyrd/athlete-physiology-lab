# Publishing checklist

Steps to take before this repository is pushed to a public GitHub remote.
Nothing here has been done automatically.

## Before the first commit

- [ ] Read every file in the repository. Correct anything that misdescribes
      the project.
- [ ] Confirm the capability table in `README.md` matches what you actually
      run.
- [ ] Choose a license and add a `LICENSE` file. Consider one license for
      code (for example MIT, BSD-3-Clause or Apache-2.0) and, later, a
      separate one for published data and text (for example CC BY 4.0).
      Until a license is added, others have no right to reuse the work.
- [ ] Decide whether to add a `CITATION.cff` so the project can be cited.
- [ ] Tag the release: `git tag -a v0.1.0 -m "v0.1.0"` once the license is in.

## Before every push

- [ ] `bash tools/prepublish_check.sh` passes.
- [ ] `bash tests/test_sleep_import.sh` passes.
- [ ] `git status` shows no unexpected files; `git diff --cached` has been
      read.
- [ ] (Recommended) `config/private_terms.txt` exists locally and lists your
      sensor ID, operating-system user names and any other strings that must
      never appear. It is git-ignored.

## Workbook template

The template has been built and has passed the automated checks described
in `excel/README.md`. Still to do by hand, and again after every rebuild:

- [ ] Template rebuilt by the procedure in `excel/README.md` (not edited and
      re-saved by hand).
- [ ] `python3 tools/audit_workbook.py excel/template/athlete-recovery-template.xlsm`
      reports no failures (`tools/prepublish_check.sh` runs it, and compares
      the cached data with the synthetic night).
- [ ] `tests\test_template.ps1` passes (Windows with Excel).
- [x] Known intermittent Excel crash during refresh: ships documented in
      v0.1.0 (README "Known Limitations", `docs/test-report-v0.1.0.md`).
- [ ] Template opened in Excel and inspected by eye: every sheet, the Power
      Query editor, the VBA editor, File > Info. Close without saving.
- [ ] Dashboard button clicked once by hand on synthetic data; a row appears
      in the nightly log. (The automated test runs the macro, not the click.)

## Creating the GitHub repository

- [ ] Repository name: `athlete-physiology-lab`.
- [ ] Create it **private** first; push; review how it renders on GitHub;
      then switch to public.
- [ ] Confirm the commit author name and email shown on GitHub are the ones
      you intend.
- [ ] Add a description and topics (for example `heart-rate-variability`,
      `sports-science`, `polar-h10`, `sleep`, `physiology`).
- [ ] Enable secret scanning and push protection in the repository settings.

Suggested commands, once everything above is done (the GitHub CLI creates the
remote repository as private):

```bash
git commit -m "Initial project structure, import script and documentation"
gh repo create athlete-physiology-lab --private --source . --remote origin --push
```

## After publication

- [ ] Open the public page in a private browser window and read it as a
      stranger would.
- [ ] Search the repository on GitHub for your sensor ID and user names.
