# Icons: the engraved plate set (1.6.1)

Every icon of the game is one of 67 emblems: solid silhouettes of period objects (a standard for the host, a sealed letter for envoys, an armillary sphere for nations, a scroll with a wax seal for decrees, an olive branch for peace, an anchor for the port) with the engraving cut into them. Direction A of the mocks, calmer: flat matte, softer cuts, rounded edges, one margin.

## Colour for meaning (Settings > Display > Icons)
| colour | meaning |
|---|---|
| brass `#D6B05A` | state, money, building, land (treasury, tax, decrees, council, annals, goals, market, port, build, farm, settle, colonize) |
| bone `#EFE6CF` | people and peace (people, happy, heart, peace) |
| vermilion `#E4573F` | war and danger (host, wars, attack, fortress, recruit, spread, muster, skull, warning) |
| Tyrian purple `#BE8ADB` | diplomacy and knowledge (envoys, nations, pact, spy, research, library, info, release, claim) |
| smoke `#A89C80` | controls, places, terrain (move, save, close, back, lock, filter, pin) |

The game's own status colours (teal good, coral bad, blue information) are never used for meaning: an icon the code draws in one of them keeps it, a dim icon (disabled) stays dim, a dark icon on a brass plate (the ring's primary verb) stays dark. The province ring is the exception: its verbs are one brass instrument and are drawn in the ring's own brass and ivory. Modes: **Colour by meaning** (default), **All brass**, **Classic line icons** (the 1.6.0 set). Colour-vision modes and high contrast always use brass: every drawing differs by shape.

## How it is built
* `tools/emblems/emblems.svg` is the source (symbols on a 48 grid, the cuts in classes `k` / `kf` / `sep`). `tools/emblems/render.cjs` + `post.py` render each symbol to a 256 px white mask whose cuts are transparent: `assets/emblems/<id>.png`.
* `src/ui/emblem.gd` (TBEmblem) loads a mask once, scales it to the nearest bin (24 ... 256 px) with Lanczos, caches the texture, and draws it tinted. `TBGlyph.draw / draw_filled / draw_ic` and `TBBzIcons.draw` ask it first; a name it does not know (diamond, triangles, arrowhead, capital ring, unrest burst) keeps its old drawing.
* `TBEmblem.ALIAS` maps every name the old set used (and the verb ids of the province ring) to an emblem; `tests/emblem.gd` checks that every name maps, every mask exists, colours, the modes and a real draw.
* To change an icon: edit its symbol in `emblems.svg`, run the two render steps (needs Node with Playwright and Pillow), commit the PNG.
