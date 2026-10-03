#!/usr/bin/env bash
# download_data.sh — fetch the source OSM extract into data/osm/.
#
# Usage: ./download_data.sh [--force]
#
# Downloads the Geofabrik Sri Lanka extract (GEOFABRIK_URL in
# config/build.conf). Existing files are kept unless --force is given.
# SRTM elevation tiles (data/hgt/) are not downloaded automatically —
# see README.md for where to get them.

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

FORCE=0
[ "${1:-}" = --force ] && FORCE=1
case "${1:-}" in --force|""|-h|--help) ;; *) die "unknown option: $1" ;; esac

need_cmd wget

target="$DATA_DIR/osm/$SOURCE_MAP_NAME"
mkdir -p "$DATA_DIR/osm"

if [ -f "$target" ] && [ "$FORCE" = 0 ]; then
    log "Source extract already present: $target (use --force to re-download)"
else
    log "Downloading $GEOFABRIK_URL"
    wget --inet4-only -O "$target.part" "$GEOFABRIK_URL"
    [ -s "$target.part" ] || die "download produced an empty file"
    mv "$target.part" "$target"
    log "Download complete: $target"
fi

if ! ls "$DEM_DIR"/*.hgt >/dev/null 2>&1; then
    log "NOTE: no SRTM tiles found in $DEM_DIR — the base layer needs them"
    log "      for hill shading. See README.md ('Source data')."
fi
