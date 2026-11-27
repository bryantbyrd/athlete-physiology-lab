# data/

Local working data. **Everything in this folder except this file is
git-ignored.**

Personal recordings do not need to live here; the import script reads from
wherever `SLEEP_BASE_DIR` points. Use this folder for scratch copies and for
synthetic recordings while developing:

```bash
python3 tools/make_synthetic_night.py --out data/synthetic/Archive --zip
```

See [../docs/privacy.md](../docs/privacy.md).
