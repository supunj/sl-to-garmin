#!/usr/bin/env bash
# hgt2osm.sh — generate contour lines from SRTM elevation tiles.
#
# Runs phyghtmap over every .hgt tile in DEM_DIR (config/build.conf), writes
# one contour PBF per tile into build/contours/ (temporary), then merges them
# all with osmosis into data/osm/sl-contours.osm.pbf (the contour layer's
# input file).
#
# The next ./build_map.sh run picks up the new contour file automatically.
#
# Usage: ./hgt2osm.sh

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

# phyghtmap resolution order:
#   1. phyghtmap on PATH
#   2. project-root virtualenv at .venv (gitignored)
#   3. create that venv and install phyghtmap into it
#      (2.23 source tarball — http://katze.tfiu.de/projects/phyghtmap/#Download)
VENV_DIR="$PROJECT_ROOT/.venv"
PHYGHTMAP_VERSION=2.23
# phyghtmap is not on PyPI; source tarball from the author's site:
# http://katze.tfiu.de/projects/phyghtmap/#Download
PHYGHTMAP_URL="http://katze.tfiu.de/projects/phyghtmap/phyghtmap_${PHYGHTMAP_VERSION}.orig.tar.gz"
PHYGHTMAP=

install_phyghtmap() {
    need_cmd python3
    need_cmd wget
    log "Installing phyghtmap $PHYGHTMAP_VERSION into $VENV_DIR"
    python3 -m venv "$VENV_DIR" \
        || die "could not create a virtualenv (on Debian/Ubuntu: apt install python3-venv)"

    mkdir -p "$BUILD_DIR"
    local tarball="$BUILD_DIR/phyghtmap_$PHYGHTMAP_VERSION.orig.tar.gz"
    local src_dir="$BUILD_DIR/phyghtmap-$PHYGHTMAP_VERSION"
    log "Downloading $PHYGHTMAP_URL"
    wget --inet4-only -O "$tarball" "$PHYGHTMAP_URL" \
        || die "download failed: $PHYGHTMAP_URL"
    tar -xzf "$tarball" -C "$BUILD_DIR" \
        || die "could not extract $tarball"
    [ -f "$src_dir/setup.py" ] \
        || die "unexpected tarball layout: $src_dir/setup.py not found"

    # phyghtmap 2.23 imports matplotlib._contour, which was removed in
    # matplotlib 3.8. Shim it onto contourpy (the package matplotlib itself
    # now uses for contouring) so phyghtmap works with current matplotlib.
    python3 - "$src_dir/phyghtmap/hgt.py" <<'EOF'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

old = "else:\n\tfrom matplotlib import _contour\n"
new = (
    "else:\n"
    "\ttry:\n"
    "\t\tfrom matplotlib import _contour\n"
    "\texcept ImportError:\n"
    "\t\t# matplotlib >= 3.8 moved contouring to the contourpy package;\n"
    "\t\t# contourpy >= 1.4 takes the mask as a masked z array instead\n"
    "\t\timport numpy as _np\n"
    "\t\timport contourpy as _contourpy\n"
    "\n"
    "\t\tclass _QuadContourGeneratorShim:\n"
    "\t\t\tdef __init__(self, x, y, z, mask, corner_mask, nchunk):\n"
    "\t\t\t\tif mask is not None:\n"
    "\t\t\t\t\tz = _np.ma.array(z, mask=mask)\n"
    "\t\t\t\tself._gen = _contourpy.contour_generator(\n"
    "\t\t\t\t\tx=x, y=y, z=z, corner_mask=corner_mask,\n"
    "\t\t\t\t\tchunk_size=(nchunk or None))\n"
    "\n"
    "\t\t\tdef create_contour(self, level):\n"
    "\t\t\t\treturn self._gen.lines(level)\n"
    "\n"
    "\t\tclass _contour:  # compatibility shim for matplotlib >= 3.8\n"
    "\t\t\tQuadContourGenerator = _QuadContourGeneratorShim\n"
)

if old not in src:
    sys.exit("patch target not found in " + path)
with open(path, "w") as f:
    f.write(src.replace(old, new, 1))
EOF

    "$VENV_DIR/bin/pip" install --quiet --upgrade pip setuptools
    # runtime deps (numpy/matplotlib/beautifulsoup4/contourpy) come from
    # PyPI; phyghtmap itself from the patched source tarball
    "$VENV_DIR/bin/pip" install --quiet numpy matplotlib beautifulsoup4 contourpy \
        || die "pip install of phyghtmap dependencies failed"
    "$VENV_DIR/bin/pip" install --quiet "$src_dir" \
        || die "pip install of phyghtmap from $src_dir failed"

    [ -x "$VENV_DIR/bin/phyghtmap" ] \
        || die "phyghtmap install completed but $VENV_DIR/bin/phyghtmap is missing"
    PHYGHTMAP="$VENV_DIR/bin/phyghtmap"
    log "Installed: $PHYGHTMAP"
}

ensure_phyghtmap() {
    if command -v phyghtmap >/dev/null 2>&1; then
        PHYGHTMAP="$(command -v phyghtmap)"
    elif [ -x "$VENV_DIR/bin/phyghtmap" ]; then
        PHYGHTMAP="$VENV_DIR/bin/phyghtmap"
    else
        install_phyghtmap
    fi
    log "Using phyghtmap: $PHYGHTMAP"
}

ensure_phyghtmap

OUT_DIR="$BUILD_DIR/contours"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

shopt -s nullglob
tiles=("$DEM_DIR"/*.hgt)
shopt -u nullglob
[ ${#tiles[@]} -gt 0 ] || die "no .hgt tiles found in $DEM_DIR"

log "Generating contours from ${#tiles[@]} SRTM tile(s) in $DEM_DIR"
(
    cd "$OUT_DIR"
    for tile in "${tiles[@]}"; do
        log "  $(basename "$tile")"
        "$PHYGHTMAP" -s 5 --source=view3 --srtm-version=3 --srtm=3 \
            --viewfinder-mask=3 --no-zero-contour --line-cat=200,100 \
            --pbf "$tile"
    done
)

# merge_contours — merge the per-tile contour PBFs into the contour layer's
# input file (data/osm/$CONTOURS_NAME) using osmosis.
merge_contours() {
    local out="$DATA_DIR/osm/$CONTOURS_NAME"
    [ -x "$OSMOSIS" ] || die "osmosis not executable: $OSMOSIS"
    shopt -s nullglob
    local pbfs=("$OUT_DIR"/*.osm.pbf)
    shopt -u nullglob
    [ ${#pbfs[@]} -gt 0 ] || die "no contour PBFs found in $OUT_DIR"

    log "Merging ${#pbfs[@]} contour PBF(s) into $out"
    # --read-pbf a --read-pbf b --merge --read-pbf c --merge ... --write-pbf
    local args=(--read-pbf file="${pbfs[0]}")
    local pbf
    for pbf in "${pbfs[@]:1}"; do
        args+=(--read-pbf file="$pbf" --merge)
    done
    "$OSMOSIS" "${args[@]}" --write-pbf file="$out"
    log "Wrote $out"
    log "The next ./build_map.sh run will rebuild the contour layer from it."
}

merge_contours
