#!/usr/bin/env bash
# assemble_typ.sh — assemble the monolithic TYP text file from the segment
# tree under typ/ and place it in the build directory, ready for mkgmap's
# TypCompiler. Invoked by compile_typ (lib/common.sh) during build_map.sh
# when TYP_FILE is not set.
#
# Segment layout for the selected device (typ/<device>/, produced by
# test/split_typ.py):
#   typ/<device>/common/common.txt            [_id] + [_drawOrder] sections
#   typ/<device>/polygon/<type>.txt           one [_polygon] section per file
#   typ/<device>/line/<type>.txt              one [_line] section per file
#   typ/<device>/point/<type>-<sub-type>.txt  one [_point] section per file
#
# Usage: ./assemble_typ.sh [output-file]
#   Default output: $BUILD_DIR/$STYLE.txt (build/drive66.txt).
#   The segment root can be overridden with TYP_SRC_DIR
#   (default: typ/$DEVICE).

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

TYP_SRC_DIR=${TYP_SRC_DIR:-"$PROJECT_ROOT/typ/$DEVICE"}
OUT_FILE=${1:-"$BUILD_DIR/$STYLE.txt"}

# List a segment directory's files in numeric type (then sub-type) order, so
# the assembled file reads like a hand-maintained TYP regardless of glob
# order. Filenames carry the type: 0x1b.txt, 0x10603.txt, 0x008-0x00.txt.
segments_sorted() {
    local dir="$1"
    [ -d "$dir" ] || die "segment directory missing: $dir"
    find "$dir" -maxdepth 1 -name '*.txt' -printf '%f\n' |
    awk '{
        name = $0; sub(/\.txt$/, "", name)
        t = name; s = "0"
        if (name ~ /-/) { split(name, p, "-"); t = p[1]; s = p[2] }
        printf "%d %d %s\n", strtonum(t), strtonum(s), $0
    }' | sort -n -k1,1 -k2,2 | cut -d' ' -f3-
}

# emit_class <subdir> <banner> — print the banner, then every segment file in
# the directory followed by a blank line. sed '$a\' guarantees each segment
# ends with a newline so sections can never glue together.
emit_class() {
    local subdir="$1" banner="$2" f
    printf ';%s\n\n' "$banner"
    while IFS= read -r f; do
        sed -e '$a\' "$TYP_SRC_DIR/$subdir/$f"
        printf '\n'
    done < <(segments_sorted "$TYP_SRC_DIR/$subdir")
}

need_file "$TYP_SRC_DIR/common/common.txt"
mkdir -p "$(dirname "$OUT_FILE")"

log "Assembling TYP text from $TYP_SRC_DIR -> $OUT_FILE"
{
    sed -e '$a\' "$TYP_SRC_DIR/common/common.txt"
    printf '\n'
    emit_class polygon "===================== POLYGONES ========================"
    emit_class line    "====================== LINES ==========================="
    emit_class point   "====================== POINTS =========================="
} > "$OUT_FILE"

# Count sections in the artifact itself so the log reflects what was written.
log "Assembled: $(grep -c '^\[_drawOrder\]' "$OUT_FILE") drawOrder, \
$(grep -c '^\[_polygon\]' "$OUT_FILE") polygon, \
$(grep -c '^\[_line\]' "$OUT_FILE") line, \
$(grep -c '^\[_point\]' "$OUT_FILE") point sections"
