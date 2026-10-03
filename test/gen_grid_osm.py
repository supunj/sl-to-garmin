#!/usr/bin/env python3
"""Generate an OSM XML file with a grid of 5km x 5km polygons (1km gaps),
one polygon per type code in area_type_codes.txt, named with the type code.

The grid is placed in the South Pacific Ocean (south of French Polynesia,
west of Point Nemo), well clear of any land or island."""

CODES_FILE = "area_type_codes.txt"
OUT_FILE = "area_type_grid.osm"

# Grid layout: 393216 codes -> 768 cols x 512 rows
COLS = 768

# North-west corner of the grid (open South Pacific Ocean)
ORIGIN_LAT = -35.0
ORIGIN_LON = -170.0

# km -> degrees (near equator)
KM_PER_DEG_LAT = 110.574
KM_PER_DEG_LON = 111.320  # at equator

CELL = 5.0   # polygon size in km
GAP = 1.0    # gap in km
PITCH = CELL + GAP

def main():
    codes = []
    with open(CODES_FILE) as f:
        for line in f:
            codes.extend(c.strip() for c in line.split(",") if c.strip())

    total = len(codes)
    rows = (total + COLS - 1) // COLS
    print(f"{total} codes, grid {COLS} x {rows}")
    print(f"extent: {COLS*PITCH} km x {rows*PITCH} km")

    node_id = 0
    way_id = 0
    with open(OUT_FILE, "w", buffering=1 << 20) as out:
        w = out.write
        w("<?xml version='1.0' encoding='UTF-8'?>\n")
        w("<osm version='0.6' generator='type-code-grid'>\n")

        # First pass: nodes
        for idx in range(total):
            r, c = divmod(idx, COLS)
            x0 = c * PITCH
            y0 = r * PITCH
            lat0 = ORIGIN_LAT - (y0 / KM_PER_DEG_LAT)   # grid grows southward
            lon0 = ORIGIN_LON + (x0 / KM_PER_DEG_LON)
            lat1 = ORIGIN_LAT - ((y0 + CELL) / KM_PER_DEG_LAT)
            lon1 = ORIGIN_LON + ((x0 + CELL) / KM_PER_DEG_LON)
            for lat, lon in ((lat0, lon0), (lat0, lon1), (lat1, lon1), (lat1, lon0)):
                node_id += 1
                w(f"  <node id='{node_id}' version='1' lat='{lat:.7f}' lon='{lon:.7f}'/>\n")

        # Second pass: ways
        for idx, code in enumerate(codes):
            base = idx * 4
            way_id += 1
            w(f"  <way id='{way_id}' version='1'>\n")
            for k in range(4):
                w(f"    <nd ref='{base + k + 1}'/>\n")
            w(f"    <nd ref='{base + 1}'/>\n")
            w(f"    <tag k='name' v='{code}'/>\n")
            w(f"    <tag k='landuse' v='farmland'/>\n")
            w("  </way>\n")

        w("</osm>\n")
    print(f"wrote {OUT_FILE}: {node_id} nodes, {way_id} ways")

if __name__ == "__main__":
    main()
