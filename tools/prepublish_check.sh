#!/usr/bin/env bash
#
# prepublish_check.sh — scan every tracked (or staged) file for things that
# must not be published: data files, workbooks, recording metadata, crash
# dumps, review files, identifiers, personal paths, secret-like strings and
# oversized files.
#
# Run from anywhere inside the repository:
#     bash tools/prepublish_check.sh
#
# Optional: list private strings (sensor ID, user names, ...) one per line in
# config/private_terms.txt. That file is git-ignored; if it exists, any tracked
# file containing one of its terms fails the check.
#
# The single real recording the author has authorised for publication
# (examples/demo-night-2026-11-26/) is exempt from the file-type rule by exact
# path only, and is pinned to its SHA256SUMS; see docs/privacy.md.
#
# Exit status 0 = nothing found. This is an aid, not a guarantee: read the
# diff before every push. See docs/privacy.md.

set -uo pipefail
export LC_ALL=C

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not inside a Git repository." >&2; exit 2; }
cd "$root" || exit 2

self="tools/prepublish_check.sh"
problems=0
report() { echo "FAIL  $*"; problems=$((problems + 1)); }

mapfile -t files < <(git ls-files)
if (( ${#files[@]} == 0 )); then
    echo "No tracked or staged files to check (run 'git add' first)." >&2
    exit 2
fi

# --- 1. File types that should never be tracked -------------------------------
allowed_workbook="excel/template/athlete-recovery-template.xlsm"
# The one real recording the author has authorised for publication. Only these
# exact paths are exempt; section 6 pins their content to SHA256SUMS.
demo_dir="examples/demo-night-2026-11-26"
demo_files=("$demo_dir/hr.csv" "$demo_dir/rr.csv")
demo_allowed=("${demo_files[@]}" "$demo_dir/README.md" "$demo_dir/SHA256SUMS" "$demo_dir/dashboard-note.txt")
for f in "${files[@]}"; do
    case "$f" in
        "$allowed_workbook"|examples/synthetic/*|"$demo_dir/hr.csv"|"$demo_dir/rr.csv") continue ;;
    esac
    case "${f,,}" in
        *.csv|*.tsv|*.zip|*.7z|*.gz|*.tgz|*.parquet|*.h5|*.hdf5|*.npy|*.npz|*.pkl|*.mat|*.db|*.sqlite|\
        *.xls|*.xlsx|*.xlsm|*.xlsb|*.xltx|*.xltm|\
        *.fit|*.tcx|*.gpx|*.edf|*.bdf|\
        *.pem|*.key|*.p12|*.pfx|*.env|*/.env|.env)
            report "forbidden file type tracked: $f" ;;
        */session.json|session.json|*/markers.csv)
            report "recording metadata tracked: $f" ;;
        *.dmp|*.mdmp|*.hdmp|*.wer|*.stackdump|*.xar|*.asd|*.xlk)
            report "crash dump or recovery file tracked: $f" ;;
        review/*|reviews/*|drafts/*|scratch/*|notes/*|review*|*.review.*|*-review.*|*_review.*)
            report "review or scratch file tracked: $f" ;;
    esac
done

# --- 2. Oversized files ---------------------------------------------------------
for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    size=$(wc -c < "$f")
    limit=1048576
    # The workbook template carries a full synthetic night of cached data.
    [[ "$f" == "$allowed_workbook" ]] && limit=8388608
    if (( size > limit )); then
        report "file larger than $((limit / 1048576)) MB: $f ($size bytes)"
    fi
done

# --- 3. Content patterns --------------------------------------------------------
# name|extended regular expression
patterns=(
    'sensor ID in a Polar device name|Polar[ _-]?H10[ _-][0-9A-Fa-f]{8}'
    'sensor ID in a stream file name|[0-9A-Fa-f]{8}_(hr|rr|ecg|acc)\.csv'
    'Linux home directory path|/home/[a-z_][a-z0-9_-]*/'
    'macOS home directory path|/Users/[A-Za-z0-9._-]+/'
    'Windows user profile path|[A-Za-z]:\\+Users\\+[A-Za-z0-9._-]+'
    'mounted Windows drive path|/mnt/[a-z]/[A-Za-z]'
    'cloud drive path|[A-Za-z]:\\+My Drive'
    'email address|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
    'private key block|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    'GitHub token|gh[pousr]_[A-Za-z0-9]{20,}'
    'hard-coded secret|(api[_-]?key|secret|passw(or)?d|token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}'
)
# Placeholders that are safe by construction.
allow='Polar[ _-]?H10[ _-]0{8}|0{8}_(hr|rr|ecg|acc)\.csv|noreply|@example\.(com|org)'

for entry in "${patterns[@]}"; do
    name=${entry%%|*}
    regex=${entry#*|}
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && report "$name: $hit"
    done < <(
        for f in "${files[@]}"; do
            [[ "$f" == "$self" || ! -f "$f" ]] && continue
            grep -nIHE -e "$regex" -- "$f" 2>/dev/null
        done | grep -vE -e "$allow" | cut -c1-160
    )
done

# --- 4. Private terms -----------------------------------------------------------
terms_file="config/private_terms.txt"
if [[ -f "$terms_file" ]]; then
    n=0
    while IFS= read -r term || [[ -n "$term" ]]; do
        n=$((n + 1))
        term=${term%$'\r'}
        [[ -z "$term" || "$term" == \#* ]] && continue
        while IFS= read -r f; do
            # Do not echo the term itself into logs.
            [[ -n "$f" ]] && report "private term (line $n of $terms_file) found in: $f"
        done < <(
            for f in "${files[@]}"; do
                [[ -f "$f" ]] && grep -lIiF -e "$term" -- "$f" 2>/dev/null
            done
        )
    done < "$terms_file"
    echo "note  private terms checked from $terms_file"
else
    echo "note  $terms_file not found; skipping the private-term scan"
    echo "      (recommended: list your sensor ID and user names there, one per line)"
fi

# --- 5. Workbook template -------------------------------------------------------
# The template is a ZIP package, so the text scans above cannot see inside it.
if git ls-files --error-unmatch "$allowed_workbook" >/dev/null 2>&1; then
    py=""
    for candidate in python3 python; do
        if "$candidate" -c "import sys" >/dev/null 2>&1; then py=$candidate; break; fi
    done
    if [[ -z "$py" ]]; then
        report "cannot audit $allowed_workbook: Python not found"
    else
        audit_args=()
        [[ -f "$terms_file" ]] && audit_args=(--terms "$terms_file")
        # The template caches the authorised demonstration night. Require its
        # cached HR and RR columns to equal the published files exactly, so
        # it can hold nothing else (no other night, no original timestamps).
        audit_args+=(--expect-data "$demo_dir")
        if "$py" tools/audit_workbook.py "${audit_args[@]}" "$allowed_workbook" >/dev/null; then
            echo "note  workbook template passed tools/audit_workbook.py (cached data identical to $demo_dir)"
        else
            report "workbook template failed tools/audit_workbook.py (run it for details)"
        fi
    fi
fi

# --- 6. Authorised demonstration recording -------------------------------------
# Exactly the files listed above may exist under $demo_dir, the two data files
# must match SHA256SUMS (so a different or extended recording cannot be
# swapped in under the same authorisation), and the recording must start at
# 00:00:00.000 UTC on its label date (proof that clock time was removed).
for f in "${files[@]}"; do
    [[ "$f" == "$demo_dir"/* ]] || continue
    ok=0
    for a in "${demo_allowed[@]}"; do [[ "$f" == "$a" ]] && ok=1; done
    (( ok )) || report "unexpected file in the authorised demonstration folder: $f"
done
if [[ -f "$demo_dir/SHA256SUMS" ]]; then
    if ! (cd "$demo_dir" && sha256sum --quiet -c SHA256SUMS >/dev/null 2>&1); then
        report "$demo_dir: data files do not match SHA256SUMS"
    fi
    for f in "${demo_files[@]}"; do
        first=$(sed -n 2p "$f" 2>/dev/null | cut -d, -f1)
        earliest=$(tail -n +2 "$f" | cut -d, -f1 | sort -n | head -1)
        # 1795651200000 = 2026-11-26T00:00:00.000Z
        if [[ "$earliest" != "1795651200000" || "$first" != "1795651200000" ]]; then
            report "$f: does not start at 2026-11-26 00:00:00 UTC; clock time may not have been removed"
        fi
    done
    if ! grep -q "CC BY-NC 4.0" "$demo_dir/README.md" 2>/dev/null; then
        report "$demo_dir/README.md: the data licence (CC BY-NC 4.0) is not stated"
    fi
    echo "note  authorised demonstration recording checked ($demo_dir)"
elif git ls-files --error-unmatch "${demo_files[0]}" >/dev/null 2>&1; then
    report "$demo_dir: SHA256SUMS missing"
fi

# --- 7. Git identity ------------------------------------------------------------
email=$(git config user.email || true)
case "$email" in
    *noreply*) ;;
    "") echo "note  no Git author email configured" ;;
    *) echo "note  commits will publish this author email: review 'git config user.email'" ;;
esac

echo
if (( problems > 0 )); then
    echo "$problems problem(s) found in ${#files[@]} files. Do not publish until resolved."
    exit 1
fi
echo "No problems found in ${#files[@]} tracked files."
