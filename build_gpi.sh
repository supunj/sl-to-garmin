#!/usr/bin/env bash
# build_gpi.sh — build Garmin POI (.gpi) files from the source OSM extract.
#
# For each line of config/tags.conf (format: category:key.value,key.value
# [:extra_gpsbabel_options]), extract matching nodes and convert them to
# build/gpi/<category>.gpi with icons/<device>/<category>.bmp as the bitmap.
#
# Usage: ./build_gpi.sh [--device <type>] [-h|--help]
#
#   --device <type>  Garmin device family to build for (default: drive66);
#                    selects the icon set (icons/<type>/); overrides $DEVICE

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

TAGS_CONF="$PROJECT_ROOT/config/tags.conf"
POI_DIR="$BUILD_DIR/poi"
GPI_DIR="$BUILD_DIR/gpi"
NODES_PBF="$POI_DIR/poi-nodes.osm.pbf"
ICON_DIR="$PROJECT_ROOT/icons/$DEVICE"

usage() { sed -n '2,11p' "$0"; exit "${1:-0}"; }

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --device)
                [ $# -ge 2 ] || die "--device requires a device type (e.g. drive66)"
                DEVICE="$2"
                ICON_DIR="$PROJECT_ROOT/icons/$DEVICE"
                shift ;;
            -h|--help)        usage 0 ;;
            *)                echo "unknown option: $1" >&2; usage 1 ;;
        esac
        shift
    done
}

# Pull every node out of the extract once; per-category filters then read
# this much smaller file.
extract_nodes() {
    log "Extracting all POI nodes from $SOURCE_MAP_NAME"
    "$OSMOSIS" \
        --read-pbf-fast file="$DATA_DIR/osm/$SOURCE_MAP_NAME" \
        --tf accept-nodes \
        --tf reject-ways \
        --tf reject-relations \
        --write-pbf "$NODES_PBF"
}

# build_one_gpi <category> <key.value,key.value,...> [extra gpsbabel opts]
build_one_gpi() {
    local category="$1" keys="$2" extra="${3:-}"
    local icon="$ICON_DIR/$category.bmp"
    local osm_file="$POI_DIR/$category.osm"
    need_file "$icon"

    log "Building POI category: $category"
    "$OSMOSIS" \
        --read-pbf file="$NODES_PBF" \
        --tf reject-ways \
        --tf reject-relations \
        --tf accept-nodes \
        --node-key-value keyValueList="$keys" \
        --write-xml "$osm_file"

    local out_opts="garmin_gpi,descr,category=$category,bitmap=$icon"
    [ -n "$extra" ] && out_opts="$out_opts,$extra"
    gpsbabel \
        -i osm -f "$osm_file" \
        -o "$out_opts" \
        -F "$GPI_DIR/$category.gpi"
}

main() {
    parse_args "$@"
    need_file "$TAGS_CONF"
    need_cmd gpsbabel
    [ -x "$OSMOSIS" ] || die "osmosis not executable: $OSMOSIS"
    [ -d "$ICON_DIR" ] || die "no icon set for device '$DEVICE': $ICON_DIR"
    mkdir -p "$POI_DIR" "$GPI_DIR"
    extract_nodes
    local line category keys extra
    while IFS= read -r line; do
        # skip blank lines and comments
        [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
        IFS=: read -r category keys extra <<< "$line"
        build_one_gpi "$category" "$keys" "$extra"
    done < "$TAGS_CONF"
    log "Done. GPI files:"
    ls -lh "$GPI_DIR"
}

main "$@"
