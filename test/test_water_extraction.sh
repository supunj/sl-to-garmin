#!/usr/bin/env bash
# test/test_water_extraction.sh — test water-body and waterway extraction.
#
# Usage: test/test_water_extraction.sh [input.osm.pbf]
#
# The input defaults to the full source extract. Water bodies, waterways,
# water-line ways, and their combined output are written to
# build/tmp/water-extraction/.

TEST_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$TEST_DIR/../lib/common.sh"

usage() { sed -n '2,8p' "$0"; exit "${1:-0}"; }

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
    usage 0
fi
[ $# -le 1 ] || usage 1

INPUT="${1:-$DATA_DIR/cache/$SOURCE_MAP_NAME}"
OUTPUT_DIR="$BUILD_DIR/tmp/water-extraction"
WATER_BODIES_PBF="$OUTPUT_DIR/01-water-bodies.osm.pbf"
WATERWAYS_PBF="$OUTPUT_DIR/02-waterways.osm.pbf"
WATER_LINES_PBF="$OUTPUT_DIR/03-water-lines.osm.pbf"
MERGED_PBF="$OUTPUT_DIR/04-water-combined.osm.pbf"
WATER_LINES_COPY="$OUTPUT_DIR/water-lines-copy.osm.pbf"
WAYS_ONLY_PBF="$OUTPUT_DIR/water-lines-ways-only.osm.pbf"
TRANSFORM_XML="$OUTPUT_DIR/water-lines-transform.xml"

need_file "$INPUT"
[ -x "$OSMOSIS" ] || die "osmosis not executable: $OSMOSIS"
[ -x "$OSMIUM" ] || die "osmium not executable: $OSMIUM"
mkdir -p "$OUTPUT_DIR"
trap 'rm -f -- "$WATER_LINES_COPY" "$WAYS_ONLY_PBF" "$TRANSFORM_XML"' EXIT

log "Extracting water-body relations and polygons from $INPUT"
"$OSMIUM" tags-filter \
    --overwrite \
    --output="$WATER_BODIES_PBF" \
    "$INPUT" \
    'r/natural=water' \
    'r/natural=wetland' \
    'r/water' \
    'a/natural=water' \
    'a/natural=wetland' \
    'a/water'

log "Extracting waterways from $INPUT"
"$OSMOSIS" \
    --read-pbf-fast file="$INPUT" \
    --tf accept-ways waterway=* \
    --tf reject-relations \
    --used-node \
    --write-pbf "$WATERWAYS_PBF"

log "Creating water-line ways from a copy of the water bodies"
cp "$WATER_BODIES_PBF" "$WATER_LINES_COPY"
"$OSMIUM" cat \
    -t node \
    -t way \
    --overwrite \
    --output="$WAYS_ONLY_PBF" \
    "$WATER_LINES_COPY"

cat > "$TRANSFORM_XML" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<translations>
    <translation>
        <name>Replace water-body way tags</name>
        <match type="way">
            <notag k="__water_extraction_match_all__" v=".*"/>
        </match>
        <output>
            <tag k="water" v="water_line"/>
        </output>
    </translation>
</translations>
XML

"$OSMOSIS" \
    --read-pbf-fast file="$WAYS_ONLY_PBF" \
    --tag-transform file="$TRANSFORM_XML" \
    --write-pbf "$WATER_LINES_PBF"
"$OSMIUM" renumber \
    -t way \
    --start-id=10000000000 \
    --overwrite \
    --output="$WAYS_ONLY_PBF" \
    "$WATER_LINES_PBF"
mv "$WAYS_ONLY_PBF" "$WATER_LINES_PBF"

log "Merging water bodies, waterways, and water-line ways"
"$OSMIUM" merge \
    --overwrite \
    --output="$MERGED_PBF" \
    "$WATER_BODIES_PBF" \
    "$WATERWAYS_PBF" \
    "$WATER_LINES_PBF"

log "Water extraction completed: $MERGED_PBF"
