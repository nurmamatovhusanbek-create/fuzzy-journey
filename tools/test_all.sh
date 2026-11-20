#!/bin/bash
# Runs every headless test. Usage: tools/test_all.sh [GODOT_BIN]
GODOT=${1:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")/.."
fail=0
run() { echo "== $1"; local out; out=$(cd godot && timeout ${TB_TEST_TIMEOUT:-900} "$GODOT" --headless --path . -s "$2" 2>&1); local rc=$?; echo "$out" | grep -vE "ALSA|audio|^$|Godot Engine"; [ $rc -eq 0 ] || { echo "!! FAILED: $1"; fail=1; }; }
(cd godot && "$GODOT" --headless --path . --import >/dev/null 2>&1)
# the turn runs on its own thread while the screen reads the same tables: a GDScript `const` Array / Dictionary is not safe to read from two threads
# (a corrupted table, a double free), a `static var` is. Engine tables must be `static var`.
bad=$(grep -rnE '^const [A-Z][A-Z0-9_]*\s*(:=|:\s*(Array|Dictionary)[^=]*=)\s*[\[{]' godot/src/engine --include=*.gd)
if [ -n "$bad" ]; then echo "$bad"; echo "!! FAILED: engine const tables (use static var)"; fail=1; else echo "ok: no const tables in the engine"; fi
run "engine tables are safe to read from several threads" tests/const_race.gd
run "engine: determinism + basics" tests/run_all.gd
run "save/load round trip (3 scenarios)" tests/saveload.gd
run "rulers: historical seeds, succession, determinism" tests/rulers.gd
run "diplomacy: casus belli, infamy, coalitions" tests/diplo.gd
run "diplomacy view mirrors the engine (acceptance, peace, trade)" tests/dipview.gd
run "contact decides who offers what, far pacts weigh little" tests/diplo_logic.gd
run "covert operations (chance terms, caught agents, cut ties)" tests/spy_logic.gd
run "colonies cost gold, settlers and moves; every requirement is listed" tests/colony_rules.gd
run "province names of the era (Khujand 1400, Petrograd 1914, ru/uz forms)" tests/hist_names.gd
run "worth follows people, economy, development; Develop is a choice of projects; standing stars" tests/projects.gd
run "investment bars, shrinking returns" tests/invest.gd
run "quarrels reach friends, trade routes need means, victories are held" tests/realism.gd
run "eras: every era starts sanely (capitals, rulers, names, land)" tests/era_audit.gd
run "decisions" tests/decisions.gd
run "real people per era at 10/20/30:1, growth under a ceiling" tests/pop5.gd
run "armies in the capital only, incomes and prices at scale" tests/rules5.gd
run "spread and muster orders" tests/mass5.gd
run "alerts: tips can be switched off, crises never" tests/alert_prefs.gd
run "breakdown tooltips list the engine's own terms" tests/breakdown.gd
run "undo takes orders back exactly" tests/undo.gd
run "state works cost, effects, AI buys them" tests/works.gd
run "AI states fight for aims" tests/aims.gd
run "release a vassal, united regions pay, new lenses" tests/n8.gd
run "trade deals" tests/trade.gd
run "royal marriages" tests/marriage.gd
run "generals" tests/generals.gd
run "ultimatums" tests/ultimatum.gd
run "court requests answered next turn" tests/asks.gd
run "marching to any reachable province + fog of war" tests/march.gd
run "capitals stand where the historical capitals were" tests/capitals.gd
run "districts: slots, job fill, demolish, AI builds" tests/districts.gd
run "honours" tests/honours.gd
run "supply / attrition" tests/supply.gd
run "levy pools, recruits from the pool, work loss" tests/levy.gd
run "the whole army may go, an army of one moves, the conqueror can go on" tests/send_all.gd
run "battles of three rounds, range, retreat" tests/battle.gd
run "morale, war exhaustion, desertion, peace readiness" tests/morale.gd
run "sieges of fortified provinces, supply reach" tests/siege.gd
run "war score, peace table, deals" tests/peace.gd
run "occupation income, resistance, no annexation without a treaty" tests/occupation.gd
run "military works in held land" tests/held_build.gd
run "Raise troops (levy first, the rest hired)" tests/raise.gd
run "Disband (half back to the levy pool)" tests/disband.gd
run "lineages (stages, conditions, forming, claims, AI, saves)" tests/lineage.gd
run "event cards say what happens (previews = applied amounts, scaled by the nation)" tests/event_amounts.gd
run "institutions (spread, embrace, lag, AI, saves)" tests/institutions.gd
run "reform of the government (cost, era, cooldown, estates, AI, USSR road)" tests/regime.gd
run "every icon a window asks for has a drawing" tests/ui_icon_names.gd
run "estates (loyalty, courting, effects, AI, events, saves)" tests/estates.gd
run "institution events (conditions, effects, three languages)" tests/inst_events.gd
run "calls to arms weighed by trust, threat, border, distance, exhaustion" tests/calls.gd
run "doctrine" tests/doctrine.gd
run "economy / research / aggression / rebellion model" tests/model.gd
run "plaque animation state" tests/labels_anim.gd
run "can(): read-only and in step with apply()" tests/can.gd
run "regional unification" tests/realms.gd
run "AI offers to humans" tests/offers.gd
run "chronicle/advisor texts have no missing keys" tests/chron_keys.gd
run "Russian nation names" tests/names_ru.gd
run "Russian place names" tests/places_ru.gd
run "synth audio" tests/audio.gd
run "UI contrast: tokens vs art bible 4.2-4.7 (normal + high contrast)" tests/ui_contrast.gd
run "soak: random human, 7 eras, invariants" tests/soak.gd
run "historical events: integrity + firing" tests/hist_events.gd
run "security: command schema, wire format, saves, settings, server text/rate rules" tests/security.gd
run "fuzz: random and hostile commands keep the invariants" tests/fuzz_commands.gd
echo "== links: res paths, translation keys, language parity"; python3 tools/audit_links.py || fail=1
echo "== uzbek apostrophes (oʻ gʻ = U+02BB, tutuq = U+02BC)"; python3 tools/uz_normalize.py --check || fail=1
echo "== multiplayer: server + 2 clients (lockstep of mirrored state)"; tools/test_mp.sh "$GODOT" 2>&1 | tail -3; [ "${PIPESTATUS[0]}" -eq 0 ] || fail=1
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
