#!/usr/bin/env bash
#
# Install (or remove) the dsh-theme-warm theme in a DeepSeek Harness profile.
#
# Route B of the README: no npm, no publishing. The script copies the package
# into $DSH_HOME/themes/<name>/ and writes a marker-delimited row into
#
#     $DSH_HOME/profiles/<profile>/cordis.patch.yml
#
# so repeated runs replace rather than duplicate, and your own patch entries are
# never touched.
#
# It then reproduces the Loader's own resolution of that row and rolls it back if
# it would not mount. That matters: a row naming a DIRECTORY instead of the entry
# file fails with ERR_UNSUPPORTED_DIR_IMPORT, and the failure is invisible in the
# UI -- no theme, no error, and the plugin's HTTP routes just keep returning 404.
#
# cordis.patch.yml is read at boot, so restart dsh afterwards.
#
# Usage:
#   ./install.sh [--profile desktop] [--dsh-home PATH]
#   ./install.sh --uninstall [--profile desktop]

set -euo pipefail

PROFILE="desktop"
UNINSTALL=0
DSH_HOME_ARG=""

usage() {
    cat <<'EOF'
Install the dsh-theme-warm theme into a DeepSeek Harness profile.

  -p, --profile NAME   profile to install into (default: desktop)
  -u, --uninstall      remove the row and the installed package
      --dsh-home PATH  harness config root (default: $DSH_HOME, then ~/.dsh)
  -h, --help           show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--profile) PROFILE="${2:-}"; shift 2 ;;
        -u|--uninstall) UNINSTALL=1; shift ;;
        --dsh-home) DSH_HOME_ARG="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_DIR/package.json"
[ -f "$MANIFEST" ] || { echo "package.json not found next to this script: $MANIFEST" >&2; exit 1; }

DSH_HOME="${DSH_HOME_ARG:-${DSH_HOME:-$HOME/.dsh}}"
PROFILES_DIR="$DSH_HOME/profiles"
THEMES_DIR="$DSH_HOME/themes"
PATCH_FILE="$PROFILES_DIR/$PROFILE/cordis.patch.yml"

# -- read the manifest ---------------------------------------------------------
# node is guaranteed for a DSH user; python3 is the fallback so the script also
# runs where node is not on PATH.
read_manifest() {
    if command -v node >/dev/null 2>&1; then
        node -e '
          const fs = require("fs");
          const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
          const ex = m.exports ? m.exports["."] : undefined;
          let entry = typeof ex === "string" ? ex : (ex && ex.default);
          if (!entry) entry = m.main;
          if (entry && entry.startsWith("./")) entry = entry.slice(2);
          const files = (Array.isArray(m.files) && m.files.length)
            ? m.files.slice()
            : ["package.json", "cordis.patch.yml", "lib", "media"];
          if (files.indexOf("package.json") < 0) files.push("package.json");
          console.log("name=" + m.name);
          console.log("entry=" + entry);
          files.forEach((f) => console.log("file=" + f));
        ' "$MANIFEST"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
ex = m.get("exports")
ex = ex.get(".") if isinstance(ex, dict) else None
entry = ex if isinstance(ex, str) else (ex or {}).get("default")
if not entry:
    entry = m.get("main")
if entry and entry.startswith("./"):
    entry = entry[2:]
files = m.get("files") or ["package.json", "cordis.patch.yml", "lib", "media"]
if "package.json" not in files:
    files.append("package.json")
print("name=" + m["name"])
print("entry=" + entry)
for f in files:
    print("file=" + f)
        ' "$MANIFEST"
    else
        echo "need node or python3 on PATH to read package.json" >&2
        exit 1
    fi
}

NAME=""
ENTRY=""
FILE_LIST=""
while IFS= read -r line; do
    case "$line" in
        name=*) NAME="${line#name=}" ;;
        entry=*) ENTRY="${line#entry=}" ;;
        file=*) FILE_LIST="$FILE_LIST${line#file=}
" ;;
    esac
done <<EOF
$(read_manifest)
EOF

[ -n "$NAME" ] || { echo "package.json has no name" >&2; exit 1; }
[ -n "$ENTRY" ] || { echo "package.json declares neither exports['.'] nor main" >&2; exit 1; }

ROW_ID="theme-${NAME#dsh-theme-}"
DEST_DIR="$THEMES_DIR/$NAME"
MARK_START="# >>> $NAME >>>"
MARK_END="# <<< $NAME <<<"

# -- patch-file surgery ---------------------------------------------------------
# DSH itself APPENDS entries to this file: a settings write-back persists rows
# such as `ui-theme` when the user changes a preference. A position-based marker
# block therefore ends up with someone else's entry inside it, and deleting the
# block deletes their setting along with yours. So this package's row is found by
# CONTENT, never by position, and the block is inserted at the TOP of the file so
# that later appends land outside the markers.
remove_row() {
    [ -f "$PATCH_FILE" ] || return 0
    # ROW_ID is interpolated into a regex below; it is derived from the package
    # name, which is a plain npm name, so it carries no regex metacharacters.
    awk -v s="$MARK_START" -v e="$MARK_END" -v rowid="$ROW_ID" '
        function lead(str) { match(str, /^[ \t]*/); return RLENGTH }
        function trim(str) { sub(/^[ \t]+/, "", str); sub(/[ \t]+$/, "", str); return str }

        { line[NR] = $0 }

        END {
            # pass 1: drop our markers and our own entry
            k = 0
            i = 1
            while (i <= NR) {
                cur = line[i]
                if (trim(cur) == s || trim(cur) == e) { i++; continue }
                if (cur ~ ("^[ \t]*-[ \t]+id:[ \t]*" rowid "[ \t]*$")) {
                    base = lead(cur)
                    i++
                    while (i <= NR) {
                        nxt = line[i]
                        if (trim(nxt) == "") break
                        if (lead(nxt) <= base) break
                        i++
                    }
                    continue
                }
                kept[++k] = cur
                i++
            }

            # pass 2: drop an `- insert:` left with no children
            m = 0
            j = 1
            while (j <= k) {
                cur = kept[j]
                if (cur ~ /^[ \t]*-[ \t]*insert:[ \t]*$/) {
                    ind0 = lead(cur)
                    p = j + 1
                    while (p <= k && trim(kept[p]) == "") p++
                    if (p > k) { j++; continue }
                    if (lead(kept[p]) <= ind0) { j++; continue }
                }
                out[++m] = cur
                j++
            }

            # pass 3: drop leading blanks, trim trailing ones
            start = 1
            while (start <= m && trim(out[start]) == "") start++
            last = m
            while (last >= start && trim(out[last]) == "") last--
            if (last < start) { print "[]"; exit }
            for (q = start; q <= last; q++) print out[q]
        }
    ' "$PATCH_FILE" > "$PATCH_FILE.tmp"
    mv "$PATCH_FILE.tmp" "$PATCH_FILE"
}

write_row() {
    remove_row

    # A fresh profile patch is the empty array `[]`; a sequence item placed after
    # it would be invalid YAML, so drop it.
    effective="$(grep -v '^[[:space:]]*#' "$PATCH_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
    if [ -z "$effective" ] || [ "$effective" = "[]" ]; then
        printf '%s\n' "$MARK_START" '- insert:' "    - id: $ROW_ID" "      name: '$REL_SPEC'" "$MARK_END" > "$PATCH_FILE"
        return
    fi

    # Insert at the top, after any leading comment block, so entries DSH appends
    # later stay outside our markers.
    awk -v ms="$MARK_START" -v me="$MARK_END" \
        -v l1="    - id: $ROW_ID" -v l2="      name: '$REL_SPEC'" '
        function trim(str) { sub(/^[ \t]+/, "", str); sub(/[ \t]+$/, "", str); return str }
        { line[NR] = $0 }
        END {
            at = 1
            while (at <= NR) {
                t = trim(line[at])
                if (t == "" || t ~ /^#/) at++
                else break
            }
            for (i = 1; i < at; i++) print line[i]
            print ms
            print "- insert:"
            print l1
            print l2
            print me
            if (at <= NR) {
                print ""
                for (i = at; i <= NR; i++) print line[i]
            }
        }
    ' "$PATCH_FILE" > "$PATCH_FILE.tmp"
    mv "$PATCH_FILE.tmp" "$PATCH_FILE"
}

if [ "$UNINSTALL" = "1" ]; then
    remove_row
    [ -d "$DEST_DIR" ] && rm -rf "$DEST_DIR"
    echo "Removed $NAME from profile '$PROFILE'."
    echo "Restart dsh to drop the theme."
    exit 0
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "No such profile: '$PROFILE' (looked for $PATCH_FILE)." >&2
    if [ -d "$PROFILES_DIR" ]; then
        echo "Available:" >&2
        for d in "$PROFILES_DIR"/*/; do
            [ -f "$d/cordis.patch.yml" ] && echo "  $(basename "$d")" >&2
        done
    fi
    exit 1
fi

# -- copy the package ----------------------------------------------------------
# Follow package.json `files`, so the multi-megabyte source artwork at the
# repository root never lands in the profile.
mkdir -p "$THEMES_DIR"
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

printf '%s' "$FILE_LIST" | while IFS= read -r item; do
    [ -n "$item" ] || continue
    [ -e "$REPO_DIR/$item" ] || continue
    mkdir -p "$DEST_DIR/$(dirname "$item")"
    cp -R "$REPO_DIR/$item" "$DEST_DIR/$item"
done

[ -f "$DEST_DIR/$ENTRY" ] || { echo "installed package is missing the entry file: $ENTRY" >&2; exit 1; }

# -- pre-flight: reproduce the Loader's resolution -----------------------------
REL_SPEC="../../themes/$NAME/$ENTRY"

echo ""
echo "Pre-flight resolution check:"

if command -v node >/dev/null 2>&1; then
    PROBE="$(mktemp)"
    cat > "$PROBE" <<'EOF'
const { pathToFileURL } = require('node:url')
;(async () => {
  const [profileDir, spec] = process.argv.slice(2)
  const base = pathToFileURL(profileDir.replace(/[\\/]?$/, '/'))
  const url = new URL(spec, base).href
  console.log('resolved  ' + url)
  let mod
  try {
    mod = await import(url)
  } catch (error) {
    console.log('FAIL      import: ' + (error.code || error.message))
    process.exit(1)
  }
  console.log('PASS      module imports')
  if (typeof mod.apply !== 'function') {
    console.log('FAIL      host half exports apply()')
    process.exit(1)
  }
  console.log('PASS      host half exports apply()')
})()
EOF
    set +e
    node "$PROBE" "$(dirname "$PATCH_FILE")" "$REL_SPEC"
    PROBE_CODE=$?
    set -e
    rm -f "$PROBE"
    if [ "$PROBE_CODE" -ne 0 ]; then
        remove_row
        echo "The row would not mount, so it has been rolled back. Nothing was installed." >&2
        exit 1
    fi
else
    echo "  SKIP      node not on PATH; the row is still written with a file specifier,"
    echo "            which is the part that matters."
fi

# -- write the row -------------------------------------------------------------
write_row

echo ""
echo "Installed $NAME"
echo "  package : $DEST_DIR"
echo "  row     : $ROW_ID  (name: $REL_SPEC)"
echo "  patch   : $PATCH_FILE"
echo ""
echo "RESTART dsh to activate it, then refresh the page. cordis.patch.yml is read"
echo "at boot; no installed package in this DSH version watches it."
echo ""
echo "Confirm the entry started:"
echo "  cordis_inspect_query platform=host provider=Config method=listConfigs"
echo "and look for entry id 'include:$ROW_ID'."
