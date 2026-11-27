# Publishing checklist

Steps to take before this repository is pushed to a public GitHub remote.
Nothing here has been done automatically.

## Before the first commit

- [ ] Read every file in the repository. Correct anything that misdescribes
      the project.
- [ ] Confirm the capability table in `README.md` matches what you actually
      run.
- [x] License: MIT (`LICENSE`). Personal data published later needs its own
      terms (for example CC BY 4.0).
- [ ] Decide whether to add a `CITATION.cff` so the project can be cited.
- [x] Release tagged locally: `v0.1.0`.

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

Steps, once everything above is done:

1. On GitHub, create a new **empty** repository named
   `athlete-physiology-lab` (no README, no .gitignore, no license: the
   repository already has them). Choose **Private** for the first push.
2. Connect and push, replacing `<user>` with your GitHub user name:

   ```bash
   git remote add origin https://github.com/<user>/athlete-physiology-lab.git
   git push -u origin main
   git push origin v0.1.0
   ```

3. Review the rendered pages on GitHub, then change the visibility to Public
   in Settings > General > Danger Zone.
4. Optionally create a GitHub Release from the `v0.1.0` tag, using the
   `CHANGELOG.md` entry as its notes.

## After publication

- [ ] Open the public page in a private browser window and read it as a
      stranger would.
- [ ] Search the repository on GitHub for your sensor ID and user names.
