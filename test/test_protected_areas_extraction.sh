#!/usr/bin/env bash
# test/test_protected_areas_extraction.sh — test protected-area extraction and way-tag stripping.
#
# Usage: test/test_protected_areas_extraction.sh [input.osm.pbf]
#
# The input defaults to the full source extract. Output and its XML audit copy
# are written to build/tmp/protected-areas/.

TEST_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$TEST_DIR/../lib/common.sh"

usage() { sed -n '2,7p' "$0"; exit "${1:-0}"; }

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
    usage 0
fi
[ $# -le 1 ] || usage 1

INPUT="${1:-$DATA_DIR/cache/$SOURCE_MAP_NAME}"
OUTPUT_DIR="$BUILD_DIR/tmp/protected-areas"
EXTRACTED_PBF="$OUTPUT_DIR/protected-areas-with-way-tags.osm.pbf"
OUTPUT_PBF="$OUTPUT_DIR/protected-areas.osm.pbf"
OUTPUT_XML="$OUTPUT_DIR/protected-areas.osm"

need_file "$INPUT"
need_file "$POLY_FILE"
need_cmd python3
[ -x "$OSMIUM" ] || die "osmium not executable: $OSMIUM"
mkdir -p "$OUTPUT_DIR"

log "Extracting protected-area relations from $INPUT"
"$OSMOSIS" \
    --read-pbf-fast file="$INPUT" \
    --tf reject-relations boundary=administrative \
    --tf reject-relations name='Asia/Colombo timezone' \
    --tf reject-relations name='Yala National Park' \
    --tf accept-relations boundary=protected_area,national_park \
    --used-way \
    --used-node \
    --bounding-polygon file="$POLY_FILE" \
    --write-pbf "$EXTRACTED_PBF"

log "Stripping tags from protected-area ways"
"$OSMIUM" tags-filter \
    --invert-match \
    --remove-tags \
    --overwrite \
    --output="$OUTPUT_PBF" \
    "$EXTRACTED_PBF" \
    'w/*'

log "Converting filtered data to XML for validation"
"$OSMOSIS" \
    --read-pbf file="$OUTPUT_PBF" \
    --write-xml file="$OUTPUT_XML"

python3 - "$OUTPUT_XML" <<'PY'
from collections import Counter
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
relations = root.findall("relation")
if not relations:
    raise SystemExit("FAIL: no protected-area relations were extracted")

allowed_boundaries = {"protected_area", "national_park"}
counts = Counter()
unexpected = []
for relation in relations:
    tags = {tag.get("k"): tag.get("v") for tag in relation.findall("tag")}
    boundary = tags.get("boundary")
    if boundary not in allowed_boundaries:
        unexpected.append((relation.get("id"), boundary))
    else:
        counts[boundary] += 1

if unexpected:
    for relation_id, boundary in unexpected:
        print(
            f"Unexpected relation {relation_id}: boundary={boundary!r}",
            file=sys.stderr,
        )
    raise SystemExit(f"FAIL: {len(unexpected)} unexpected relations were extracted")

tagged_ways = [way.get("id") for way in root.findall("way") if way.find("tag") is not None]
if tagged_ways:
    raise SystemExit(
        f"FAIL: {len(tagged_ways)} ways still have tags; first way: {tagged_ways[0]}"
    )

for boundary in sorted(counts):
    print(f"{boundary}: {counts[boundary]} relations")
print(f"PASS: all {len(relations)} extracted relations have the requested tags")
print(f"PASS: all {len(root.findall('way'))} extracted ways have no tags")
PY

log "Extraction test passed: $OUTPUT_PBF"
