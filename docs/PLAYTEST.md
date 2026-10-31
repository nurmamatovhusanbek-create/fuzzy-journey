# Playtest notes (rules 3)

Method: `godot/tests/playtest.gd` plays a campaign with a scripted human (era, nation, turns, size, output dir), checks every `can()` against `apply()`, records alerts, idle resources and dialogs, and takes screenshots. Campaigns: Rome (ancient), Uzbekistan (modern, S22 size), Germany 1939, Portugal (discovery).

## Fixed
- `can()` and `apply()` disagreed on action points by a float32 rounding step (`_short_mp`).
- Event dialogs stacked (14 at once); a new one now closes older ones.
- Gold piled up because action points ran out first; human action points now grow with realm size.
- Alliance spam (28 allies at 9 provinces, diplomatic bar at 100% in every run): a court holds `2 + sqrt(provinces) + era/2` alliances (rules 3 only). The AI, `can()`, `apply()` and the diplomacy view all use `TBDiplo.ally_room`.

- The "action points at cap" alert still used the old cap, so it fired all game in grown realms; it now uses `TBAdvisor.mp_cap`. A matching "envoys at cap" alert (`idle_dp`, rules 3) points to pacts, trade or marriage.

## Checked and left as is
- Small-nation trade: Portugal (5 provinces) opened 3 routes by turn 10. Its later bankruptcy came from four simultaneous wars and falling happiness (63 to 22), not from trade fees.
- "No general" alert: fires only when a general is affordable and an army qualifies, so it is a real prompt; the scripted bot never appoints.
- AI snowball: 39 AI-only runs (13 eras x 3 seeds, 150 turns) show a flat concentration index (HHI about 0.13), no eliminations, and only the Roman Empire reaching an economic win (turn 90 to 110).

## Open
- Idle manpower and a lack of late-game sinks for envoys (the alerts now say so; a real sink would be a design decision).
- Germany 1939 under a naive bot collapses to 10 provinces with 8 wars.

## Rome, ancient, 60 turns (2026-10-31, after the new ancient events)
No script errors, 0 can/apply mismatches, 0 slow turns; 37 event choices answered, the new events appear as ordinary event cards. The scripted player's happiness fell from 65 to 18 and its net income turned negative by turn 60: that is the bot's own budget (high tax, constant recruiting and settling), not the model. Every headless test of this kind ends with a heap-corruption message at process exit (`corrupted double-linked list` / `double free`), also in `ui_hotseat.gd`, after the result is printed; I tried to narrow it down: it also happens under Godot 4.5 (so it is not new to 4.4.1), never in an empty scene, and not when the game only shows the title, starts a game, plays three turns on the worker thread or on the main thread, or shows the menu; it does appear in some runs that open the nation pick screen and wait, so it is probably a stale object freed at shutdown rather than a turn-thread race. The official binary has no symbols, so the next step needs an engine build with debug symbols (or a Windows crash dump). No sign of it in play so far.
