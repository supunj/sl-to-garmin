#!/usr/bin/env bash
# build_map.sh — build the Sri Lanka topo map for Garmin Drive GPS devices.
#
# Produces seven layers, each merged into its own gmapsupp-style image in
# build/dist/:
#   sl-base.img             sea/land polygons + DEM hill shading
#   sl-admin.img            administrative boundaries
#   sl-contour.img          contour lines (cached in data/cache/)
#   sl-water.img            water bodies, wetlands, shorelines and waterways
#   sl-forest.img           forest-cover relations and selected member polygons
#   sl-road.img             roads, POIs, routing + address index (_mdr.img / .mdx)
#   sl-protected-areas.img  protected-area and national-park boundaries
#
# Usage: ./build_map.sh [--device <type>] [--theme <name>] [--pg-cleanse]
#                       [--pg-experiments] [--skip-contours] [--keep-build-dir]
#                       [--keep-db] [-h|--help]
#
#   --device <type>  Garmin device family to build for (default: drive66);
#                    selects the mkgmap style (style/<type>/) and the TYP
#                    text file; overrides $DEVICE/$STYLE
#   --theme <name>   map theme; selects typ/NN_<device>_<theme>.txt
#                    (default: osm)
#   --pg-cleanse       round-trip the OSM extract through PostGIS first
#                      (cleanse_data.sh) and build from the cleansed PBF
#   --pg-experiments   also run pg/experiments/*.sql (implies --pg-cleanse)
#   --skip-contours    do not build the contour layer at all
#   --keep-build-dir   do not wipe the build directory before building
#   --keep-db          keep the PostGIS scratch database after cleansing

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

PG_CLEANSE=0
PG_EXPERIMENTS=0
SKIP_CONTOURS=0
KEEP_BUILD_DIR=0
KEEP_DB=0

# Deterministic 8-digit tile mapnames: <FID><layer index>.
MAPNAME_BASE=53130001
MAPNAME_ADMIN=53131002
MAPNAME_CONTOUR=53132003
MAPNAME_WATER=53133004
MAPNAME_FOREST=53134005
MAPNAME_ROAD=53135006
MAPNAME_PROTECTED_AREAS=53136007

usage() { sed -n '2,28p' "$0"; exit "${1:-0}"; }

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --device)
                [ $# -ge 2 ] || die "--device requires a device type (e.g. drive66)"
                DEVICE="$2"
                STYLE="$DEVICE"
                shift ;;
            --theme)
                [ $# -ge 2 ] || die "--theme requires a theme name (e.g. osm)"
                THEME="$2"
                shift ;;
            --pg-cleanse)     PG_CLEANSE=1 ;;
            --pg-experiments) PG_EXPERIMENTS=1; PG_CLEANSE=1 ;;
            --skip-contours)  SKIP_CONTOURS=1 ;;
            --keep-build-dir) KEEP_BUILD_DIR=1 ;;
            --keep-db)        KEEP_DB=1 ;;
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
    [ -x "$OSMIUM" ] || die "osmium not executable: $OSMIUM"
    if [ "$STYLE" != default ]; then
        [ -d "$STYLE_DIR/$STYLE" ] \
            || die "no style for device '$DEVICE': $STYLE_DIR/$STYLE"
        if [ -z "${TYP_FILE:-}" ]; then
            latest_typ_file >/dev/null
        fi
    fi
    if [ "$PG_CLEANSE" = 1 ]; then
        need_cmd psql
        need_cmd createdb
        need_cmd dropdb
    fi
}

ensure_source_data() {
    [ -f "$DATA_DIR/cache/$SOURCE_MAP_NAME" ] \
        || die "source extract missing: $DATA_DIR/cache/$SOURCE_MAP_NAME
       run ./download_data.sh first"
    need_file "$POLY_FILE"
}

# Run the PostGIS cleansing stage and switch the build input to the
# cleansed extract. See cleanse_data.sh.
run_cleanse() {
    local args=()
    [ "$PG_EXPERIMENTS" = 1 ]  && args+=(--experiments)
    [ "$KEEP_DB" = 1 ]         && args+=(--keep-db)
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
    merge_layer "$PROJECT_ROOT/arg/sea_land.args" sl-base
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
    merge_layer "$PROJECT_ROOT/arg/admin.args" sl-admin
}

build_contour_layer() {
    log "=== Contour layer ==="
    local contours="$DATA_DIR/cache/$CONTOURS_NAME"
    local cache="$DATA_DIR/cache/sl-contour.img"
    local args_file="$PROJECT_ROOT/arg/elevation.args"

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
    # cache while it is newer than the contour source and mkgmap options.
    if [ -f "$cache" ] && [ "$cache" -nt "$contours" ] \
        && [ "$cache" -nt "$args_file" ]; then
        log "Reusing cached contour layer: $cache"
        cp "$cache" "$DIST_DIR/sl-contour.img"
        return
    fi
    log "Splitting contour data"
    run_splitter "$contours"
    log "Building contour tiles"
    run_mkgmap "$args_file" "$MAPNAME_CONTOUR" "$SPLIT_DIR"/*.osm.pbf
    merge_layer "$args_file" sl-contour
    log "Updating contour cache: $cache"
    mkdir -p "$(dirname "$cache")"
    cp "$DIST_DIR/sl-contour.img" "$cache"
}

build_water_layer() {
    log "=== Water layer ==="
    local water_bodies="$BUILD_DIR/water-bodies.osm.pbf"
    local waterways="$BUILD_DIR/waterways.osm.pbf"
    local water_lines="$BUILD_DIR/water-lines.osm.pbf"
    local ways_only="$BUILD_DIR/water-lines-ways-only.osm.pbf"
    local transform="$PROJECT_ROOT/config/water-lines-transform.xml"
    local water="$BUILD_DIR/water.osm.pbf"
    local args_file="$PROJECT_ROOT/arg/water.args"

    log "Extracting water-body relations and polygons"
    "$OSMIUM" tags-filter \
        --overwrite \
        --output="$water_bodies" \
        "$SOURCE_PBF" \
        'r/natural=water' \
        'r/natural=wetland' \
        'r/water' \
        'a/natural=water' \
        'a/natural=wetland' \
        'a/water'

    log "Extracting waterways"
    "$OSMOSIS" \
        --read-pbf-fast file="$SOURCE_PBF" \
        --tf accept-ways waterway=* \
        --tf reject-relations \
        --used-node \
        --write-pbf "$waterways"

    log "Creating water-line ways from a copy of the water bodies"
    cp "$water_bodies" "$water_lines"
    "$OSMIUM" cat \
        -t node \
        -t way \
        --overwrite \
        --output="$ways_only" \
        "$water_lines"

    "$OSMOSIS" \
        --read-pbf-fast file="$ways_only" \
        --tag-transform file="$transform" \
        --write-pbf "$water_lines"
    "$OSMIUM" renumber \
        -t way \
        --start-id=10000000000 \
        --overwrite \
        --output="$ways_only" \
        "$water_lines"
    mv "$ways_only" "$water_lines"

    log "Merging water bodies, waterways, and water-line ways"
    "$OSMIUM" merge \
        --overwrite \
        --output="$water" \
        "$water_bodies" \
        "$waterways" \
        "$water_lines"
    rm -f "$ways_only"

    log "Splitting water data"
    run_splitter "$water"
    log "Building water tiles"
    run_mkgmap "$args_file" "$MAPNAME_WATER" "$SPLIT_DIR"/*.osm.pbf
    merge_layer "$args_file" sl-water
}

build_forest_layer() {
    log "=== Forest-cover layer ==="
    local extracted="$BUILD_DIR/forest-with-way-tags.osm.pbf"
    local filtered="$BUILD_DIR/forest.osm.pbf"
    local args_file="$PROJECT_ROOT/arg/forest.args"

    log "Extracting forest-cover relations"
    "$OSMOSIS" \
        --read-pbf-fast file="$SOURCE_PBF" \
        --tf reject-relations boundary=protected_area,national_park \
        --tf accept-relations natural=wood,scrub,grassland,bare_rock,sand,beach landuse=forest \
        --used-way \
        --used-node \
        --bounding-polygon file="$POLY_FILE" \
        --write-pbf "$extracted"

    log "Stripping tags from unrelated forest relation member ways"
    "$OSMIUM" tags-filter \
        --remove-tags \
        --overwrite \
        --output="$filtered" \
        "$extracted" \
        'n/*' \
        'r/*' \
        'w/natural=wood,scrub,grassland,bare_rock,sand,beach' \
        'w/landuse=forest'

    log "Building forest-cover tiles"
    run_mkgmap "$args_file" "$MAPNAME_FOREST" "$filtered"
    merge_layer "$args_file" sl-forest
}

build_road_layer() {
    log "=== Road / POI / routing layer ==="
    local filtered="$BUILD_DIR/roads.osm.pbf"
    log "Filtering ways, relations and POIs"
    "$OSMOSIS" \
        --read-pbf file="$SOURCE_PBF" \
        --tf reject-nodes natural=water,wetland,wood,scrub water=* waterway=* landuse=forest boundary=protected_area,national_park \
        --tf accept-nodes \
        --tf reject-ways boundary=administrative,protected_area,national_park natural=water,wetland,wood,scrub water=* waterway=* landuse=forest \
        --tf accept-ways \
        --tf accept-relations \
        --tf reject-relations name:en='Gulf of Mannar' \
        --tf reject-relations name:en='Bay of Bengal' \
        --tf reject-relations boundary=administrative,protected_area,national_park \
        --tf reject-relations natural=water,wetland,wood,scrub,grassland,bare_rock,sand,beach \
        --tf reject-relations landuse=forest \
        --tf reject-relations water=* \
        --tf reject-relations waterway=* \
        --bounding-polygon file="$POLY_FILE" \
        --write-pbf "$filtered"
    log "Splitting road data"
    run_splitter "$filtered"
    log "Building road tiles"
    run_mkgmap "$PROJECT_ROOT/arg/transport_osm.args" "$MAPNAME_ROAD" \
        "$SPLIT_DIR"/*.osm.pbf
    merge_layer "$PROJECT_ROOT/arg/transport_osm.args" sl-road --with-index
}

build_protected_areas_layer() {
    log "=== Protected-area boundary layer ==="
    local extracted="$BUILD_DIR/protected-areas-with-way-tags.osm.pbf"
    local filtered="$BUILD_DIR/protected-areas.osm.pbf"
    log "Filtering protected-area and national-park boundary relations"
    "$OSMOSIS" \
        --read-pbf-fast file="$SOURCE_PBF" \
        --tf reject-relations boundary=administrative \
        --tf reject-relations name='Asia/Colombo timezone' \
        --tf reject-relations name='Yala National Park' \
        --tf accept-relations boundary=protected_area,national_park \
        --used-way \
        --used-node \
        --bounding-polygon file="$POLY_FILE" \
        --write-pbf "$extracted"
    log "Stripping tags from protected-area ways"
    "$OSMIUM" tags-filter \
        --invert-match \
        --remove-tags \
        --overwrite \
        --output="$filtered" \
        "$extracted" \
        'w/*'
    log "Building protected-area tiles"
    run_mkgmap "$PROJECT_ROOT/arg/protected_areas.args" \
        "$MAPNAME_PROTECTED_AREAS" "$filtered"
    merge_layer "$PROJECT_ROOT/arg/protected_areas.args" sl-protected-areas
}

main() {
    parse_args "$@"
    check_prerequisites
    ensure_source_data
    SOURCE_PBF="$DATA_DIR/cache/$SOURCE_MAP_NAME"
    # The cleanse stage writes into build/, so prepare it before cleansing.
    if [ "$KEEP_BUILD_DIR" = 1 ]; then
        mkdir -p "$LAYERS_DIR" "$MAPSET_DIR" "$SPLIT_DIR" "$DIST_DIR"
    else
        prepare_build_dir
    fi
    if [ "$PG_CLEANSE" = 1 ]; then
        run_cleanse
    fi
    build_base_layer
    build_admin_layer
    build_contour_layer
    build_water_layer
    build_forest_layer
    build_road_layer
    build_protected_areas_layer
    log "Build complete. Device-ready files:"
    ls -lh "$DIST_DIR"
}

main "$@"
