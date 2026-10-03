#!/usr/bin/env bash
# build_map.sh — build the Sri Lanka topo map for Garmin Drive GPS devices.
#
# Produces four layers, each merged into its own gmapsupp-style image in
# build/dist/:
#   sl-base.img     sea/land polygons + DEM hill shading
#   sl-admin.img    administrative boundaries
#   sl-contour.img  contour lines (cached in data/cache/)
#   sl-road.img     roads, POIs, routing + address index (_mdr.img / .mdx)
#
# Usage: ./build_map.sh [--device <type>] [--pg-cleanse] [--pg-experiments]
#                       [--skip-contours] [--keep-build-dir] [-h|--help]
#
#   --device <type>  Garmin device family to build for (default: drive66);
#                    selects the mkgmap style (style/<type>/) and the TYP
#                    segment tree (typ/<type>/); overrides $DEVICE/$STYLE
#   --pg-cleanse       round-trip the OSM extract through PostGIS first
#                      (cleanse_data.sh) and build from the cleansed PBF
#   --pg-experiments   also run pg/experiments/*.sql (implies --pg-cleanse)
#   --skip-contours    do not build the contour layer at all
#   --keep-build-dir   keep the PostGIS scratch database after cleansing

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

PG_CLEANSE=0
PG_EXPERIMENTS=0
SKIP_CONTOURS=0
KEEP_BUILD_DIR=0

# Deterministic 8-digit tile mapnames: <FID><layer index>.
MAPNAME_BASE=53130001
MAPNAME_ADMIN=53130002
MAPNAME_CONTOUR=53130003
MAPNAME_ROAD=53130004

usage() { sed -n '2,21p' "$0"; exit "${1:-0}"; }

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --device)
                [ $# -ge 2 ] || die "--device requires a device type (e.g. drive66)"
                DEVICE="$2"
                STYLE="$DEVICE"
                TYP_SRC_DIR="$PROJECT_ROOT/typ/$DEVICE"
                shift ;;
            --pg-cleanse)     PG_CLEANSE=1 ;;
            --pg-experiments) PG_EXPERIMENTS=1; PG_CLEANSE=1 ;;
            --skip-contours)  SKIP_CONTOURS=1 ;;
            --keep-build-dir) KEEP_BUILD_DIR=1 ;;
            -h|--help)        usage 0 ;;
            *)                echo "unknown option: $1" >&2; usage 1 ;;
        esac
        shift
    done
}

check_prerequisites() {
    need_cmd "$JAVA_CMD"
    need_file "$MKGMAP_JAR"
    need_file "$SPLITTER_JAR"
    [ -x "$OSMOSIS" ] || die "osmosis not executable: $OSMOSIS"
    if [ "$STYLE" != default ]; then
        [ -d "$STYLE_DIR/$STYLE" ] \
            || die "no style for device '$DEVICE': $STYLE_DIR/$STYLE"
        if [ -z "${TYP_FILE:-}" ]; then
            [ -d "$TYP_SRC_DIR" ] \
                || die "no TYP segment tree for device '$DEVICE': $TYP_SRC_DIR"
        fi
    fi
    if [ "$PG_CLEANSE" = 1 ]; then
        need_cmd psql
        need_cmd createdb
        need_cmd dropdb
    fi
}

ensure_source_data() {
    [ -f "$DATA_DIR/osm/$SOURCE_MAP_NAME" ] \
        || die "source extract missing: $DATA_DIR/osm/$SOURCE_MAP_NAME
       run ./download_data.sh first"
    need_file "$POLY_FILE"
}

# Run the PostGIS cleansing stage and switch the build input to the
# cleansed extract. See cleanse_data.sh.
run_cleanse() {
    local args=()
    [ "$PG_EXPERIMENTS" = 1 ]  && args+=(--experiments)
    [ "$KEEP_BUILD_DIR" = 1 ]  && args+=(--keep-db)
    log "=== PostGIS cleansing stage ==="
    "$PROJECT_ROOT/cleanse_data.sh" ${args[@]+"${args[@]}"}
    SOURCE_PBF="$BUILD_DIR/$CLEANSED_MAP_NAME"
    need_file "$SOURCE_PBF"
    log "Building from cleansed extract: $SOURCE_PBF"
}

build_base_layer() {
    log "=== Base layer (sea/land + DEM hill shading) ==="
    local coastline="$BUILD_DIR/coastline.osm.pbf"
    log "Extracting coastline"
    "$OSMOSIS" \
        --read-pbf-fast file="$SOURCE_PBF" \
        --tf accept-ways natural=coastline \
        --tf reject-relations \
        --bounding-polygon file="$POLY_FILE" \
        --used-node \
        --write-pbf "$coastline"
    log "Building base tiles"
    run_mkgmap "$PROJECT_ROOT/arg/sea_land.args" "$MAPNAME_BASE" \
        --dem="$DEM_DIR" \
        --dem-poly="$POLY_FILE" \
        "$coastline"
    merge_layer sl-base
}

build_admin_layer() {
    log "=== Admin boundary layer ==="
    local admin="$BUILD_DIR/admin.osm.pbf"
    log "Extracting admin boundaries"
    "$OSMOSIS" \
        --read-pbf-fast file="$SOURCE_PBF" \
        --tf accept-relations boundary=administrative \
        --used-way \
        --used-node \
        --bounding-polygon file="$POLY_FILE" \
        --write-pbf "$admin"
    log "Building admin tiles"
    run_mkgmap "$PROJECT_ROOT/arg/admin.args" "$MAPNAME_ADMIN" "$admin"
    merge_layer sl-admin
}

build_contour_layer() {
    log "=== Contour layer ==="
    local contours="$DATA_DIR/osm/$CONTOURS_NAME"
    local cache="$DATA_DIR/cache/sl-contour.img"

    if [ "$SKIP_CONTOURS" = 1 ]; then
        log "--skip-contours given; skipping contour layer"
        return
    fi

    # Regenerate the merged contour source if it is missing entirely.
    if [ ! -f "$contours" ]; then
        log "Merged contour file not found — generating contours (hgt2osm.sh)"
        "$PROJECT_ROOT/hgt2osm.sh"
        need_file "$contours"
    fi

    # Contour data changes rarely, so the compiled layer is cached. Reuse the
    # cache while it is newer than the contour source; rebuild otherwise.
    if [ -f "$cache" ] && [ "$cache" -nt "$contours" ]; then
        log "Reusing cached contour layer: $cache"
        cp "$cache" "$DIST_DIR/sl-contour.img"
        return
    fi
    log "Splitting contour data"
    run_splitter "$contours"
    log "Building contour tiles"
    run_mkgmap "$PROJECT_ROOT/arg/elevation.args" "$MAPNAME_CONTOUR" \
        "$SPLIT_DIR"/*.osm.pbf
    merge_layer sl-contour
    log "Updating contour cache: $cache"
    mkdir -p "$(dirname "$cache")"
    cp "$DIST_DIR/sl-contour.img" "$cache"
}

build_road_layer() {
    log "=== Road / POI / routing layer ==="
    local filtered="$BUILD_DIR/roads.osm.pbf"
    log "Filtering ways, relations and POIs"
    "$OSMOSIS" \
        --read-pbf file="$SOURCE_PBF" \
        --tf accept-nodes \
        --tf accept-ways \
        --tf reject-ways boundary=administrative \
        --tf accept-relations \
        --tf reject-relations name:en='Gulf of Mannar' \
        --tf reject-relations name:en='Bay of Bengal' \
        --tf reject-relations boundary=administrative \
        --bounding-polygon file="$POLY_FILE" \
        --write-pbf "$filtered"
    log "Splitting road data"
    run_splitter "$filtered"
    log "Building road tiles"
    run_mkgmap "$PROJECT_ROOT/arg/transport_osm.args" "$MAPNAME_ROAD" \
        "$SPLIT_DIR"/*.osm.pbf
    merge_layer sl-road --with-index
}

main() {
    parse_args "$@"
    check_prerequisites
    ensure_source_data
    SOURCE_PBF="$DATA_DIR/osm/$SOURCE_MAP_NAME"
    # Wipe build/ before the cleanse stage so the cleansed PBF it writes
    # there survives for the layer builds below.
    prepare_build_dir
    if [ "$PG_CLEANSE" = 1 ]; then
        run_cleanse
    fi
    compile_typ
    build_base_layer
    build_admin_layer
    build_contour_layer
    build_road_layer
    log "Build complete. Device-ready files:"
    ls -lh "$DIST_DIR"
}

main "$@"
