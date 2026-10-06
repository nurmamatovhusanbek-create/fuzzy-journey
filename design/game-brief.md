# Terra Bellum — game brief (UI redo input)

**Working title:** Terra Bellum. **Genre:** turn-based grand strategy on a spinning globe / flat map.
**Pitch:** Rule one of ~250 nations from 218 BC to 2024 AD. Move armies, recruit, build, trade, scheme, declare war, take
provinces, outlast coalitions. One more turn, always.
**Who it's for / what they feel:** strategy players on phones and PCs who want the weight of an empire in a few minutes
a turn: *the calm, slightly dangerous focus of a staff officer at a map table at night.*
**Platforms:** Android, iOS, Windows. Touch-first, mouse/keyboard supported (gamepad not required). Sizes from 540×960 portrait
phones through 2340×1080 landscape phones to 1920×1080 desktop. Godot 4.4 (GDScript, Control nodes, GL Compatibility).
Languages: English, Russian, Uzbek (Latin) — text must fit ~35 % longer strings. Modes: single player, hot-seat (2–4 on one
device), authoritative-server multiplayer.
**Art & audio direction:** history, cartography, military staff work. Materials: laid paper, ink, brass, umber leather, wax.
The globe/flat map is the hero and is rendered by a GPU shader; UI is Godot Control nodes drawn procedurally (no image assets;
fonts Cinzel, Alegreya, JetBrains Mono embedded).

## Pillars (proposed for this redo)
1. **The map is the hero.** UI frames it and never competes with it; panels are small, dismissible and never stack.
2. **Orders happen on the map.** Selecting, moving, attacking, recruiting are map gestures with an on-map preview; panels
   confirm and explain, they do not host the main verbs.
3. **Every number answers a decision.** Nothing is shown unless it changes what the player does this turn; the rest is one tap deeper.
4. **Quiet until it matters.** Alerts surface by priority (war, revolt, offers, supply) and fade when handled.
5. **Structure over ornament.** Paper / ink / brass is the material language, but hierarchy, grouping and spacing do the work.
   Decoration has a budget.

## What the player said about the current interface
- "It's not bad, but it's just not it." Picked: **too decorative**, **not game-like enough**, plus something else (unspecified).
- Direction chosen: **refine the paper table** (keep the material language, reduce decoration, raise function).
- Reference feel: **Total War / Hearts of Iron IV** — military command table, stacked info chips, orders on the map.
- Earlier feedback: text and borders too bold; army numbers uncomfortable at distance (now zoom-disclosed gonfalons); edges
  at close zoom (fixed in shader); misaligned/overflowing items; popups should use wide layouts on landscape.
- Accessibility tier committed: **Comprehensive**.

## Current interface inventory (see godot/src/ui/*.gd; screenshots in /tmp/claude-0/shots/sh_1280x720_*.png, docs/ui_elements.html)
Top ribbon (flag, ruler cameo, nation, date, 7 readouts) · left dock of 8 brass medallions (Nations, Budget, Decrees, Annals,
Goals, Advice, Save, Options) · lens chit "Political ▾" · End Turn wax seal bottom right · province side panel (title, owner,
long list of action buttons, send-share 25/50/75/100, ledger of figures, meters) · hover card · battle-preview banner · toasts ·
army gonfalons on the map · modals (nations list/stats, budget sliders, decisions, annals, goals, advisor, nation card,
settings, save/load, honours, codex, era picker, hot-seat setup, event/ultimatum prompts, game over) · title screen on a bezel
ring around the globe · nation-pick screen.
