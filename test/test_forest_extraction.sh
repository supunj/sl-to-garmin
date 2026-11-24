#!/usr/bin/env bash
# test/test_forest_extraction.sh — test forest extraction and member-way tag stripping.
#
# Usage: test/test_forest_extraction.sh [input.osm.pbf]
#
# The input defaults to the full source extract. Output and its XML audit copy
# are written to build/tmp/forest/.

TEST_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$TEST_DIR/../lib/common.sh"

usage() { sed -n '2,7p' "$0"; exit "${1:-0}"; }

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
    usage 0
fi
[ $# -le 1 ] || usage 1

INPUT="${1:-$DATA_DIR/cache/$SOURCE_MAP_NAME}"
OUTPUT_DIR="$BUILD_DIR/tmp/forest"
EXTRACTED_PBF="$OUTPUT_DIR/forest-with-way-tags.osm.pbf"
EXTRACTED_XML="$OUTPUT_DIR/forest-with-way-tags.osm"
OUTPUT_PBF="$OUTPUT_DIR/forest.osm.pbf"
OUTPUT_XML="$OUTPUT_DIR/forest.osm"

need_file "$INPUT"
need_file "$POLY_FILE"
need_cmd python3
[ -x "$OSMIUM" ] || die "osmium not executable: $OSMIUM"
mkdir -p "$OUTPUT_DIR"
trap 'rm -f -- "$EXTRACTED_XML"' EXIT

log "Extracting forest-cover relations from $INPUT"
"$OSMOSIS" \
    --read-pbf-fast file="$INPUT" \
    --tf reject-relations boundary=protected_area,national_park \
    --tf accept-relations natural=wood,scrub,grassland,bare_rock,sand landuse=forest \
    --used-way \
    --used-node \
    --bounding-polygon file="$POLY_FILE" \
    --write-pbf "$EXTRACTED_PBF"

log "Stripping tags from unrelated forest relation member ways"
"$OSMIUM" tags-filter \
    --remove-tags \
    --overwrite \
    --output="$OUTPUT_PBF" \
    "$EXTRACTED_PBF" \
    'n/*' \
    'r/*' \
    'w/natural=wood,scrub,grassland,bare_rock,sand' \
    'w/landuse=forest'

log "Converting source and filtered data to XML for validation"
"$OSMOSIS" \
    --read-pbf file="$EXTRACTED_PBF" \
    --write-xml file="$EXTRACTED_XML"
"$OSMOSIS" \
    --read-pbf file="$OUTPUT_PBF" \
    --write-xml file="$OUTPUT_XML"

python3 - "$EXTRACTED_XML" "$OUTPUT_XML" <<'PY'
from collections import Counter
import sys
import xml.etree.ElementTree as ET

source = ET.parse(sys.argv[1]).getroot()
output = ET.parse(sys.argv[2]).getroot()


def tags(element):
    return {tag.get("k"): tag.get("v") for tag in element.findall("tag")}


def is_forest(element):
    element_tags = tags(element)
    return (
        element_tags.get("natural") in {"wood", "scrub", "grassland", "bare_rock", "sand"}
        or element_tags.get("landuse") == "forest"
    )


source_relations = {relation.get("id"): relation for relation in source.findall("relation")}
output_relations = {relation.get("id"): relation for relation in output.findall("relation")}
source_ways = {way.get("id"): way for way in source.findall("way")}
output_ways = {way.get("id"): way for way in output.findall("way")}

if not source_relations:
    raise SystemExit("FAIL: no forest relations were extracted")
if set(output_relations) != set(source_relations):
    raise SystemExit("FAIL: filtered forest relations differ from the extracted relations")
if set(output_ways) != set(source_ways):
    raise SystemExit("FAIL: filtered forest member ways differ from the extracted ways")

counts = Counter()
for relation_id, relation in source_relations.items():
    if not is_forest(relation):
        raise SystemExit(f"FAIL: unexpected relation {relation_id} was extracted")
    if tags(relation).get("boundary") in {"protected_area", "national_park"}:
        raise SystemExit(f"FAIL: protected relation {relation_id} was extracted")
    if tags(output_relations[relation_id]) != tags(relation):
        raise SystemExit(f"FAIL: relation {relation_id} tags were modified")
    relation_tags = tags(relation)
    if relation_tags.get("landuse") == "forest":
        counts["forest"] += 1
    else:
        counts[relation_tags["natural"]] += 1

preserved_way_ids = {way_id for way_id, way in source_ways.items() if is_forest(way)}
stripped_way_ids = set(source_ways) - preserved_way_ids
for way_id in preserved_way_ids:
    if tags(output_ways[way_id]) != tags(source_ways[way_id]):
        raise SystemExit(f"FAIL: selected polygon way {way_id} tags were modified")
for way_id in stripped_way_ids:
    if tags(output_ways[way_id]):
        raise SystemExit(f"FAIL: unrelated member way {way_id} still has tags")

tagged_ways = [source_ways[way_id] for way_id in stripped_way_ids if tags(source_ways[way_id])]
if not tagged_ways:
    raise SystemExit("FAIL: no tagged unrelated member ways were available to validate stripping")
road_ways = [way for way in tagged_ways if "highway" in tags(way)]
for name in sorted(counts):
    print(f"{name}: {counts[name]} relations")
print(f"PASS: all {len(output_relations)} forest relations retained their tags")
print(f"PASS: all {len(preserved_way_ids)} selected polygon ways retained their tags")
print(f"PASS: all {len(stripped_way_ids)} unrelated member ways have no tags")
print(f"PASS: stripped tags from {len(tagged_ways)} tagged unrelated ways, including {len(road_ways)} roads")
PY

log "Extraction test passed: $OUTPUT_PBF"
