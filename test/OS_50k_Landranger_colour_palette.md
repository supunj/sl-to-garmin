# OS 1:50 000 Scale Colour Raster (OS Landranger style) — Complete Colour Palette

**Product:** 1:50 000 Scale Colour Raster — the digital version of the OS **Landranger** map series (Great Britain).
**Legend version:** 2022-01 (official OS legend artwork, `50k-raster-legend.pdf`).

## How this palette was derived

| Source | What it provided |
| --- | --- |
| Official OS legend PDF ([50k-raster-legend.pdf](https://www.ordnancesurvey.co.uk/documents/product-support/support/50k-raster-legend.pdf), v2022-01) | Every swatch is vector artwork defined in **DeviceCMYK** — raw CMYK values were read directly from the PDF content streams |
| Ghostscript (ICC colour-managed) rendering of the legend artwork | Print-accurate RGB conversions of each CMYK swatch |
| Five genuine raster extracts published by OS on the [product documentation page](https://docs.os.uk/os-downloads/products/maps-and-imagery-portfolio/1-50-000-scale-colour-raster) (South Wales, West Highlands, North Devon coast, Argyll, Outer Hebrides) | Pixel-verified **digital raster** colours for large-area fills (sea, sand, woodland, access land) |

Where the printed legend and the digital raster differ slightly (the artwork is CMYK print-origin), both values are given. Values marked **≈** were measured on rendered tiles and are approximate (JPEG antialiasing).

---

## 1. Core palette (quick reference)

| Swatch | Hex | RGB | CMYK (artwork) | Primary usage |
| --- | --- | --- | --- | --- |
| ⬛ | #231F20 | 35, 31, 32 | 0/0/0/100 | Black: text, road casings, railways, footpaths, boundaries, symbol linework |
| ⬜ | #FFFFFF | 255, 255, 255 | 0/0/0/0 | White: land background, motorway centre stripe, unfilled symbols |
| 🟦 | #00AEEF | 0, 174, 239 | 100/0/0/0 | Cyan-blue: motorways, all water linework, tourist symbols, grid numbers, sea names |
| 🟩 | #00A650 | 0, 166, 80 | 100/0/100/0 | Green: primary routes, cycle routes, woodland tree symbols |
| 🟪 | #EC008C | 236, 0, 140 | 0/100/0/0 | Magenta: main (A) roads, rights of way, stations, youth hostels |
| 🟧 | #FAA21A | 250, 162, 26 | 0/42/100/0 | Orange: secondary (B) roads |
| 🟨 | #FFF200 | 255, 242, 0 | 0/0/100/0 | Yellow: minor roads, light-rail station dots, glass structures |
| 🟫 | #F69679 | 246, 150, 121 | 0/50/50/0 | Salmon: contour lines, contour values, cliff shading |
| 🟠 | #FEDCC2 | 254, 220, 194 | 0/15/22/0 | Peach: building fills |
| 🟢 | #DBEAB9 | 219, 234, 185 | 15/0/34/0 | Pale green: woodland fill (all types) — raster reads ≈ #DAEABB |
| 🌊 | #D8F8F7 | 216, 248, 247 | print: 15/0/0/0 → #D4EFFC | Water areas (lakes, sea) — digital raster value |
| 🏖️ | #F8E7C9 | 248, 231, 201 | print: 0/7/22/0 → #FFEBCA | Sand / intertidal zones — digital raster value |

---

## 2. Roads and paths

| Feature | Fill / line | Casing | Centre | Notes |
| --- | --- | --- | --- | --- |
| Motorway (incl. dual carriageway motorway) | #00AEEF | #231F20 | white #FFFFFF` stripe | Junction numbers in black-outlined blue boxes #00AEEF |
| Dual carriageway (non-motorway) | #00AEEF | #231F20 | white #FFFFFF` stripe | Same blue family as motorway |
| Primary route (recommended through route) | #00A650 | #231F20 | — | Route numbers in green #00A650 |
| Main road (other A road) | #EC008C | #231F20 | — | Numbers in magenta #EC008C |
| Secondary road (B road) | #FAA21A | #231F20 | — | Numbers in magenta #EC008C |
| Road generally more than 4 m wide | #FFF200 | #231F20 | — | |
| Road generally less than 4 m wide | #FFF200 | none | — | Thin yellow line, no casing |
| Other road, drive or track | #231F20 | — | — | Black dashed line |
| Path | #231F20 | — | — | Black dashed line |
| Gradient steeper than 20% / 14–20% | #231F20 | — | — | Double/Single black chevrons on the road |
| Gates / road tunnel | #231F20 | — | — | Black bars across the road |
| Ferry (passenger `P` / vehicle `V`) | #FFFFFF` background | #231F20` letters | — | |

## 3. Railways

| Feature | Colour |
| --- | --- |
| Track (single or multiple) | #231F20` black line with white cross-hatch |
| Track under construction | #231F20` dashed black |
| Light rail / tram / narrow gauge | #231F20` black + tick marks |
| Station (principal) | #EC008C` magenta fill, black outline |
| Siding, level crossing, bridge, cutting, embankment | #231F20` black |
| Light rail station | #FFF200` yellow dot |

## 4. Public rights of way and access

| Feature | Colour / pattern |
| --- | --- |
| Footpath | #231F20` dotted black |
| Bridleway | #231F20` long-dashed black |
| Restricted byway | #EC008C` long-dashed magenta |
| Byway open to all traffic | #EC008C` dash-dot magenta |
| National Trail, Scotland's Great Trails, E-paths, selected recreational routes | #EC008C` magenta diamonds; on the raster a soft **yellow corridor band ≈ #F8DC4B` core fading to ≈ #FFF9AE`** accompanies the route alignment |
| Other route with public access | #EC008C` magenta dots |
| National Cycle Network / on-road cycle route | #00A650` green dots |
| Traffic-free cycle route | #00A650` green open circles |
| Cycle route number (national / regional) | #EC008C` / #00AEEF` filled boxes, white numerals |
| Danger Area (firing ranges) | Red ≈ #D7085F` boundary dashes and label (legend prints the label #EC008C`; tiles read #C60F52`–#FF0057`) |

## 5. Boundaries

| Feature | Colour / pattern |
| --- | --- |
| National | #231F20` black alternating dash-dot ("┄●┄") |
| County, Unitary Authority, Metropolitan District, London Borough | #231F20` black dash-dot-dash |
| District | #231F20` black dashed |
| National Park | Soft yellow gradient band #FFF450` → #FFF684` → #FFF9AE` → #FFFCD5` (artwork values `0/0/80Y` → `0/0/20Y`) |

## 6. Water and coast

| Feature | Colour |
| --- | --- |
| Lakes, Lochs, broad rivers, sea (area fill) | #D8F8F7 in the digital raster (print legend: #D4EFFC) |
| Coastline (high water mark), rivers, streams, canals, aqueducts, normal tidal limit | #00AEEF blue lines (tile measurement of the coast line ≈ #45B3D4 – #3E9DBB after antialiasing) |
| Low water mark | #00AEEF dashed blue |
| Ford | #00AEEF blue line + black box |
| Lock | #231F20 black |
| Marsh or salting | Pale blue wash ≈ #D8EBF7 with #00AEEF reed/horizontal-dash symbols |
| Mud | Pale blue wash ≈ #D4EFFC with #00AEEF dash symbols |
| Sand (beaches, dunes, intertidal) | #F8E7C9 digital raster (print legend #FFEBCA) |
| Shingle | Grey-green speckle ≈ #D8DDC9 with black dots |
| Flat rock | #FFEBCA print / white in raster, black speckle outline |
| Cliff | #231F20 black tick symbols over #F69679 contour shading |
| Water-body names (e.g. "BIDEFORD BAY", "Loch Riddon") | #00AEEF blue italic serif |

## 7. Vegetation and land use

| Feature | Fill | Symbol / outline |
| --- | --- | --- |
| Coniferous wood | #DBEAB9` (raster ≈ #DAEABB`) | Conifer tree symbols #00A650`, black polygon outline #231F20 |
| Non-coniferous wood | #DBEAB9` (raster ≈ #DAEABB`) | Broad-crown tree symbols #00A650 |
| Mixed wood | #DBEAB9` (raster ≈ #DAEABB`) | Both tree symbol types |
| Orchard | #FFFDEB` pale cream-yellow | Green dot grid #00ADDE`/#00A650`, black outline |
| Park or ornamental ground | #E6E7E8` light grey (10% K) | Scattered tree symbols, black outline |
| Solar farm | #FFFFFF` white | Black panel symbols #231F20 |
| Landfill site / slag heap | #FFFFFF | Black speckle dots |
| Cutting / embankment | — | Black hatching #231F20 |

## 8. Relief and rock

| Feature | Colour |
| --- | --- |
| Contour lines (10 m vertical interval) | #F69679` salmon (CMYK 0/50/50/0); read ≈ #E0A892`–#DDAA99` on rendered tiles |
| Contour values | #F69679` salmon figures |
| Spot heights | #231F20` black figures |
| Triangulation pillar | #00AEEF` blue triangle symbol |
| Cliff, outcrop, scree, rock symbols | #231F20` black |

## 9. Built environment

| Feature | Colour |
| --- | --- |
| Buildings | #FEDCC2` peach fill with #231F20` black outline |
| Important building (selected) | Very dark charcoal ≈ #031C26` fill |
| Glass structure | #FFF200` yellow outline |
| Bus or coach station | #EC008C` magenta symbol |
| Ruin | #231F20` black hatch pattern |
| Electricity transmission line (pylons) | #231F20` black |
| Pipe line | #231F20` black dashed with flow arrows |

## 10. Access land tint

| Feature | Colour |
| --- | --- |
| Access land wash (area tint) | #D3BFDD` lilac (artwork CMYK 15/25/0/0); digital raster reads ≈ #D9CADF |
| Access land boundary & agency symbols (Forestry England, National Trust, etc.) | #9E76B4` purple (CMYK 40/60/0/0) |

## 11. Tourist information

| Feature | Colour |
| --- | --- |
| Viewpoint 180°/360°, visitor centre, walks/trails, nature reserve, picnic site, camp site, caravan site, parking, Park & Ride, information centre, golf course, garden/arboretum, recreation centre, World Heritage site | #00AEEF` blue symbols |
| Selected places of tourist interest | #00AEEF` blue diagonal hatching |
| Youth hostel | #EC008C` magenta triangle |
| Phone (public / emergency) | #231F20` black + #EC008C` magenta handsets |

## 12. Annotation and typography

| Element | Colour |
| --- | --- |
| Place names, general text, abbreviations | #231F20` black |
| Sea / water names | #00AEEF` blue italic serif capitals |
| Motorway numbers (M1…) | #231F20` black |
| Primary route numbers (A470…) | #00A650` green |
| Main road & B road numbers (A493, B4518…) | #EC008C` magenta |
| Spot heights | #231F20` black |
| Contour values | #F69679` salmon |
| Grid line numbers | #00AEEF` blue italic (tiles read ≈ #29ABE2`) |
| Danger Area label | ≈ #D7085F` red (legend prints #EC008C`) |

## 13. Map furniture

| Element | Colour |
| --- | --- |
| National Grid lines (1 km) | Pale blue ≈ #7FCCE6` (observed on raster tiles over open sea) |
| Graticule intersections (5′) | #00AEEF` blue cross |
| Map border, scale bar, height-conversion scale | #231F20` black |
| Legend sheet furniture (headers, panels) | #4D4D4F` dark grey, #E6E7E8` light grey — print sheet only, not part of the map face |

---

## Print vs digital notes

1. The legend artwork is authored in **DeviceCMYK** (print origin). CMYK → RGB conversion depends on the ICC profile, which is why e.g. the printed water tint #D4EFFC` differs from the digital raster's #D8F8F7`, and printed sand #FFEBCA` from the raster's #F8E7C9`. For screen/web work, prefer the digital-raster values for area fills and the artwork values for linework.
2. Contours, roads and other thin lines read lighter on rendered tiles (≈#E0A892` for contours, ≈#FF006B`-family for magenta) because of JPEG antialiasing; the artwork values above are the canonical line colours.
3. The National Park boundary and promoted-route corridors are drawn as **soft-edged gradient bands**, not hard fills — use the four-step yellow ramp for a faithful reproduction.
4. Background (unclassified land) is plain white #FFFFFF`; urban areas keep white background with black-outlined buildings.

## Sources

- OS 1:50 000 Scale Colour Raster legend, version 2022-01: <https://www.ordnancesurvey.co.uk/documents/product-support/support/50k-raster-legend.pdf>
- OS product documentation, 1:50 000 Scale Colour Raster (sample extracts): <https://docs.os.uk/os-downloads/products/maps-and-imagery-portfolio/1-50-000-scale-colour-raster>
- OS cartographic house styles (context): <https://www.ordnancesurvey.co.uk/blog/os-cartographic-house-styles>
