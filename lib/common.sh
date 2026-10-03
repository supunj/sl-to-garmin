# lib/common.sh — shared setup and wrappers for all sl-to-garmin scripts.
# Source this file; do not execute it directly:
#     source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config/build.conf
source "$PROJECT_ROOT/config/build.conf"

# Vendored tools
MKGMAP_JAR="$PROJECT_ROOT/tools/mkgmap-r4924/mkgmap.jar"
SPLITTER_JAR="$PROJECT_ROOT/tools/splitter-r654/splitter.jar"
OSMOSIS="$PROJECT_ROOT/tools/osmosis-0.49.2/bin/osmosis"
PGSNAPSHOT_SCHEMA="$PROJECT_ROOT/tools/osmosis-0.49.2/script/pgsnapshot_schema_0.6.sql"
JAVA_OPTS="-Xmx$JAVA_HEAP -enableassertions"

# Style directory for --style-file; test scripts override this.
STYLE_DIR=${STYLE_DIR:-"$PROJECT_ROOT/style"}

# Working dirs inside BUILD_DIR
LAYERS_DIR="$BUILD_DIR/layers"   # mkgmap CWD for layer tile builds
MAPSET_DIR="$BUILD_DIR/mapset"   # mkgmap CWD for gmapsupp merges
SPLIT_DIR="$BUILD_DIR/split"     # splitter output

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd()  { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }
need_file() { [ -f "$1" ] || die "required file not found: $1"; }

# prepare_build_dir — wipe and recreate the artifact tree. Never touches data/.
prepare_build_dir() {
    [ -n "${BUILD_DIR:-}" ] && [ "$BUILD_DIR" != / ] \
        || die "refusing to wipe unsafe BUILD_DIR: '${BUILD_DIR:-}'"
    rm -rf "$BUILD_DIR"
    mkdir -p "$LAYERS_DIR" "$MAPSET_DIR" "$SPLIT_DIR" "$DIST_DIR"
}

# run_mkgmap <args-file> <mapname> [extra mkgmap options and input files...]
# mkgmap writes output into its working directory, so this runs in a subshell
# with CWD=$LAYERS_DIR — the caller's CWD never changes.
run_mkgmap() {
    local args_file="$1" mapname="$2"
    shift 2
    need_file "$args_file"
    local style_args=()
    if [ "$STYLE" != default ]; then
        style_args=(--style-file="$STYLE_DIR" --style="$STYLE")
    fi
    mkdir -p "$LAYERS_DIR"
    (
        cd "$LAYERS_DIR"
        "$JAVA_CMD" $JAVA_OPTS -jar "$MKGMAP_JAR" \
            -c "$args_file" \
            --family-id="$FID" \
            --product-id="$PID" \
            --series-name="$SERIES_NAME" \
            --area-name="$AREA_NAME" \
            --mapname="$mapname" \
            ${style_args[@]+"${style_args[@]}"} \
            "$@"
    )
}

# run_splitter <input.pbf> — split a large PBF into tiles under $SPLIT_DIR.
run_splitter() {
    local input="$1"
    need_file "$input"
    rm -rf "$SPLIT_DIR"
    mkdir -p "$SPLIT_DIR"
    (
        cd "$SPLIT_DIR"
        "$JAVA_CMD" $JAVA_OPTS -jar "$SPLITTER_JAR" \
            --polygon-file="$POLY_FILE" \
            "$input"
    )
}

# compile_typ — compile the configured TYP file into $BUILD_DIR/<style>.typ.
# No-op for the built-in default style (test/build_map_default.sh).
compile_typ() {
    if [ "$STYLE" = default ] || [ -z "${TYP_FILE:-}" ]; then
        log "Style '$STYLE' has no TYP — skipping TYP compilation"
        return
    fi
    need_file "$TYP_FILE"
    log "Compiling TYP: $TYP_FILE"
    (
        cd "$BUILD_DIR"
        "$JAVA_CMD" -cp "$MKGMAP_JAR" \
            uk.me.parabola.mkgmap.main.TypCompiler \
            "$TYP_FILE" "$STYLE.typ"
    )
}

# merge_layer <output-name> [--with-index]
# Combine every .img in $LAYERS_DIR into one gmapsupp, move it to
# $DIST_DIR/<output-name>.img, then remove the intermediate tiles.
# --with-index also keeps the address-search index (osmmap_mdr.img/.mdx),
# renamed to <output-name>_mdr.img / <output-name>.mdx.
merge_layer() {
    local out_name="$1" with_index="${2:-}"
    shopt -s nullglob
    local imgs=("$LAYERS_DIR"/*.img)
    shopt -u nullglob
    [ ${#imgs[@]} -gt 0 ] || die "merge_layer: no .img files in $LAYERS_DIR"

    local typ_args=()
    if [ -n "${TYP_FILE:-}" ] && [ -f "$BUILD_DIR/$STYLE.typ" ]; then
        typ_args=("$BUILD_DIR/$STYLE.typ")
    fi

    log "Merging ${#imgs[@]} tile(s) -> $out_name.img"
    (
        cd "$MAPSET_DIR"
        "$JAVA_CMD" $JAVA_OPTS -jar "$MKGMAP_JAR" \
            --latin1 \
            --family-id="$FID" \
            --product-id="$PID" \
            --series-name="$SERIES_NAME" \
            --area-name="$AREA_NAME" \
            --keep-going \
            --gmapsupp \
            --tdbfile \
            --index \
            "${imgs[@]}" \
            ${typ_args[@]+"${typ_args[@]}"}
    )
    mv "$MAPSET_DIR/gmapsupp.img" "$DIST_DIR/$out_name.img"
    if [ "$with_index" = --with-index ]; then
        mv "$MAPSET_DIR/osmmap_mdr.img" "$DIST_DIR/${out_name}_mdr.img"
        mv "$MAPSET_DIR/osmmap.mdx" "$DIST_DIR/$out_name.mdx"
    fi
    rm -f "$MAPSET_DIR"/osmmap* "${imgs[@]}"
}
