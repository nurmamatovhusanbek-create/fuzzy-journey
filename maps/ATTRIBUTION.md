# Historical era maps — attribution & license

The era-accurate border maps in this folder (`*.topojson`) are derived from:

**historical-basemaps** by André Ourednik
https://github.com/aourednik/historical-basemaps

Licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

## What we did
Each source `world_<year>.geojson` was downloaded, simplified, and converted to
quantized TopoJSON (feature ids slugged from the `NAME` field; the `SUBJECTO`,
`PARTOF` and `BORDERPRECISION` properties were preserved). No coordinates were
hand-edited. These derived TopoJSON files are likewise distributed under GPL-3.0.

Historical borders are approximate, especially before 1648 (see each feature's
`BORDERPRECISION`: 1 = approximate, 2 = moderate, 3 = legally defined).
