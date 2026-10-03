#!/usr/bin/env bash
# cleanse_data.sh — round-trip the OSM extract through PostGIS for cleansing.
#
#   raw PBF --osmosis--> PostGIS (pgsnapshot schema) --pg/cleanse/*.sql-->
#   cleansed DB --osmosis dataset dump--> build/sri-lanka-cleansed.osm.pbf
#
# Usage: ./cleanse_data.sh [--experiments] [--keep-db]
#
#   --experiments  also run pg/experiments/*.sql after the vetted rules
#   --keep-db      do not drop the scratch database afterwards (debugging)
#
# Normally invoked via ./build_map.sh --pg-cleanse, but can be run standalone.
# Database connection comes from config/build.conf (PG_*); see README.md for
# the one-time role setup.

source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

EXPERIMENTS=0
KEEP_DB=0

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --experiments) EXPERIMENTS=1 ;;
            --keep-db)     KEEP_DB=1 ;;
            -h|--help)     sed -n '2,16p' "$0"; exit 0 ;;
            *)             die "unknown option: $1" ;;
        esac
        shift
    done
}

psql_db() {
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB_NAME" \
        -v ON_ERROR_STOP=1 "$@"
}

# osmosis (JDBC) does not read ~/.pgpass — pass a password only when
# PG_PASSWORD is set; otherwise rely on trust auth for localhost.
osmosis_pg_auth() {
    local auth=(host="$PG_HOST" database="$PG_DB_NAME" user="$PG_USER")
    [ -n "$PG_PASSWORD" ] && auth+=(password="$PG_PASSWORD")
    printf '%s\n' "${auth[@]}"
}

recreate_db() {
    log "Recreating scratch database: $PG_DB_NAME"
    dropdb -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" --if-exists "$PG_DB_NAME"
    createdb -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$PG_DB_NAME"
    psql_db -c 'CREATE EXTENSION postgis' -c 'CREATE EXTENSION hstore'
    need_file "$PGSNAPSHOT_SCHEMA"
    psql_db -f "$PGSNAPSHOT_SCHEMA"
}

import_osm() {
    local source_pbf="$DATA_DIR/osm/$SOURCE_MAP_NAME"
    need_file "$source_pbf"
    log "Importing $source_pbf into PostGIS (this takes a while)"
    mapfile -t auth < <(osmosis_pg_auth)
    "$OSMOSIS" \
        --read-pbf-fast file="$source_pbf" \
        --write-pgsql "${auth[@]}"
}

run_sql_dir() {
    local dir="$1" label="$2"
    shopt -s nullglob
    local scripts=("$dir"/*.sql)
    shopt -u nullglob
    [ ${#scripts[@]} -gt 0 ] || { log "No $label SQL in $dir — skipping"; return; }
    local sql
    for sql in "${scripts[@]}"; do
        log "Applying $label rule: $(basename "$sql")"
        psql_db -f "$sql"
    done
}

export_osm() {
    local out="$BUILD_DIR/$CLEANSED_MAP_NAME"
    mkdir -p "$BUILD_DIR"
    log "Exporting cleansed data to $out"
    mapfile -t auth < <(osmosis_pg_auth)
    "$OSMOSIS" \
        --read-pgsql "${auth[@]}" outPipe.0=pg \
        --dd inPipe.0=pg outPipe.0=dd \
        --write-pbf inPipe.0=dd file="$out"
}

teardown_db() {
    if [ "$KEEP_DB" = 1 ]; then
        log "--keep-db given; scratch database '$PG_DB_NAME' left in place"
    else
        log "Dropping scratch database: $PG_DB_NAME"
        dropdb -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" --if-exists "$PG_DB_NAME"
    fi
}

main() {
    parse_args "$@"
    need_cmd psql
    need_cmd createdb
    need_cmd dropdb
    [ -x "$OSMOSIS" ] || die "osmosis not executable: $OSMOSIS"
    recreate_db
    import_osm
    run_sql_dir "$PROJECT_ROOT/pg/cleanse" "cleanse"
    if [ "$EXPERIMENTS" = 1 ]; then
        run_sql_dir "$PROJECT_ROOT/pg/experiments" "experiment"
    fi
    export_osm
    teardown_db
    log "Cleanse complete: $BUILD_DIR/$CLEANSED_MAP_NAME"
}

main "$@"
