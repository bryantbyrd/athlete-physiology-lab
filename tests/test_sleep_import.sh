#!/usr/bin/env bash
#
# End-to-end test for scripts/sleep_import using synthetic data only.
# Runs in a temporary directory; it never reads or writes real recordings.
#
# Requirements: bash, unzip, python3.
# Usage: bash tests/test_sleep_import.sh

set -uo pipefail
export LC_ALL=C

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo/scripts/sleep_import"
maker="$repo/tools/make_synthetic_night.py"
id="00000000"

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

pass=0
fail=0
check() {  # check <description> <command...>
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then
        echo "ok    $desc"; pass=$((pass + 1))
    else
        echo "FAIL  $desc"; fail=$((fail + 1))
    fi
}

run_import() {  # run_import <base-dir> [device-id]
    env -u SLEEP_ARCHIVE_DIR -u SLEEP_CURRENT_DIR -u SLEEP_DRVFS_DRIVE -u SLEEP_DRVFS_MOUNT \
        SLEEP_IMPORT_CONFIG="$work/none.env" \
        SLEEP_BASE_DIR="$1" POLAR_DEVICE_ID="${2-$id}" \
        bash "$script"
}

new_base() {  # new_base <name> -> prints path
    local base="$work/$1"
    mkdir -p "$base/Archive" "$base/Current Night"
    echo "$base"
}

# --- 1. Normal import: newest of two archives is staged ----------------------
base=$(new_base normal)
python3 "$maker" --out "$base/Archive" --zip --hours 0.2 --seed 1 --start 2020-01-01T06:00:00 >/dev/null
python3 "$maker" --out "$base/Archive" --zip --hours 0.3 --seed 2 --start 2020-01-02T06:00:00 >/dev/null
newest="SF_20200102-060000_Polar-H10-$id"

check "import succeeds on valid archives" run_import "$base"
check "hr.csv has the expected header" \
    grep -q '^rx_unix_ms,frame,hr_bpm,' <(head -n 1 "$base/Current Night/hr.csv")
check "rr.csv has the expected header" \
    grep -qx 'rx_unix_ms,frame,rr_ms' <(head -n 1 "$base/Current Night/rr.csv")
check "staged hr.csv is the newest recording" \
    cmp "$base/Current Night/hr.csv" "$base/Archive/$newest/${id}_hr.csv"
check "staged rr.csv is the newest recording" \
    cmp "$base/Current Night/rr.csv" "$base/Archive/$newest/${id}_rr.csv"

# --- 2. Missing configuration -------------------------------------------------
check "fails without POLAR_DEVICE_ID" \
    bash -c "! env -u POLAR_DEVICE_ID SLEEP_IMPORT_CONFIG='$work/none.env' SLEEP_BASE_DIR='$base' bash '$script'"
check "rejects a malformed device ID" bash -c "! SLEEP_IMPORT_CONFIG='$work/none.env' SLEEP_BASE_DIR='$base' POLAR_DEVICE_ID='not/an id' bash '$script'"

# --- 3. No archive for this device -------------------------------------------
check "fails when no archive matches the device" \
    bash -c "! SLEEP_IMPORT_CONFIG='$work/none.env' SLEEP_BASE_DIR='$base' POLAR_DEVICE_ID='FFFFFFFF' bash '$script'"

# --- 4. Missing folders -------------------------------------------------------
check "fails when the sleep folders do not exist" \
    bash -c "! SLEEP_IMPORT_CONFIG='$work/none.env' SLEEP_BASE_DIR='$work/does-not-exist' POLAR_DEVICE_ID='$id' bash '$script'"

# --- 5. Invalid archive never replaces staged files --------------------------
base=$(new_base badheader)
echo "previous hr" > "$base/Current Night/hr.csv"
echo "previous rr" > "$base/Current Night/rr.csv"
bad="SF_20200103-060000_Polar-H10-$id"
mkdir -p "$work/stage/$bad"
printf 'time,bpm\n1,60\n' > "$work/stage/$bad/${id}_hr.csv"
printf 'rx_unix_ms,frame,rr_ms\n1,0,1000\n' > "$work/stage/$bad/${id}_rr.csv"
(cd "$work/stage" && python3 -m zipfile -c "$base/Archive/$bad.zip" "$bad")

check "fails on unexpected CSV headers" bash -c "! SLEEP_IMPORT_CONFIG='$work/none.env' SLEEP_BASE_DIR='$base' POLAR_DEVICE_ID='$id' bash '$script'"
check "staged hr.csv is untouched after a failed import" \
    grep -qx 'previous hr' "$base/Current Night/hr.csv"
check "staged rr.csv is untouched after a failed import" \
    grep -qx 'previous rr' "$base/Current Night/rr.csv"

base=$(new_base empty)
echo "previous rr" > "$base/Current Night/rr.csv"
empty="SF_20200104-060000_Polar-H10-$id"
mkdir -p "$work/stage/$empty"
printf 'rx_unix_ms,frame,hr_bpm,corrected_hr_bpm\n' > "$work/stage/$empty/${id}_hr.csv"
printf 'rx_unix_ms,frame,rr_ms\n' > "$work/stage/$empty/${id}_rr.csv"
(cd "$work/stage" && python3 -m zipfile -c "$base/Archive/$empty.zip" "$empty")

check "fails on header-only streams" bash -c "! SLEEP_IMPORT_CONFIG='$work/none.env' SLEEP_BASE_DIR='$base' POLAR_DEVICE_ID='$id' bash '$script'"
check "staged rr.csv is untouched after an empty import" \
    grep -qx 'previous rr' "$base/Current Night/rr.csv"

# --- 6. Config file is read, and the environment overrides it ----------------
base=$(new_base config)
python3 "$maker" --out "$base/Archive" --zip --hours 0.1 --seed 3 >/dev/null
printf 'SLEEP_BASE_DIR="%s"\nPOLAR_DEVICE_ID="FFFFFFFF"\n' "$base" > "$work/cfg.env"
check "config file supplies SLEEP_BASE_DIR; environment overrides POLAR_DEVICE_ID" \
    env -u SLEEP_BASE_DIR SLEEP_IMPORT_CONFIG="$work/cfg.env" POLAR_DEVICE_ID="$id" bash "$script"
printf 'SLEEP_BASE_DIR="%s"\nPOLAR_DEVICE_ID="%s"\n' "$base" "$id" > "$work/cfg2.env"
rm -f "$base/Current Night/"*.csv
check "config file alone is sufficient" \
    env -u SLEEP_BASE_DIR -u POLAR_DEVICE_ID SLEEP_IMPORT_CONFIG="$work/cfg2.env" bash "$script"
check "config-file import staged rr.csv" test -s "$base/Current Night/rr.csv"

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
