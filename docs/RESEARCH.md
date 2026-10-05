# Research: comparable games, what they prioritise, what Terra Bellum lacks

Sources consulted (web, plus design knowledge of the genre):
[Age of Civilizations II overview](https://www.mobygames.com/game/117375) ·
[AoC map modes / decisions wiki](https://age-of-civilizations.fandom.com/wiki/Map_Modes?oldid=1066) ·
[Age of History 2 review summary (complaints)](https://vaporlens.app/app/3381680/age_of_history_2_definitive_edition) ·
[best mobile war games](https://www.pockettactics.com/best-mobile-war-games) ·
[grand strategy list](https://www.pcgamesn.com/grand-strategy-games) ·
[EU4 casus belli / coalitions / alliances](https://steamcommunity.com/app/236850/discussions/0/3113645647526094707) ·
[event-driven design](https://game-wisdom.com/critical/event-driven-game-design) ·
[how Paradox plunders history for mechanics](https://gamedeveloper.com/design/how-paradox-plunders-history-for-great-gameplay-mechanics).

## What the genre's players value (and complain about)
| Signal | Source | Implication for us |
|---|---|---|
| "AI is simplistic/passive in war; doesn't build as much as the player" | AoH2 reviews | AI must expand, build, spend, coalition-fight (done in part; keep improving) |
| "Wars decided by raw troop numbers" | AoH2 reviews | terrain/fortress/era/leader traits/supply matter (partly done); add leader traits, casus belli costs |
| "Diplomatic options from earlier versions missing / simplified" | AoH2 reviews | casus belli, ultimatums, war goals, trade deals, marriage, guarantee, coalitions |
| "No images/names of leaders" | AoH2 reviews | named rulers with traits and succession |
| Mobile: long games, async multiplayer, big player counts | Supremacy 1914 / Conflict of Nations | configurable turn timers (have), async/long-turn rooms |
| EU4: *aggressive expansion → coalitions*; casus belli changes war cost; royal marriage; alliances | EU4 | infamy system + coalitions; CB; marriages |
| Event-driven design: small/medium/large events, chains, "a few dozen events foster connection" | Game Developer | many more historical events, with chains and consequences, decisions/focus |
| Systems should generate stories the player wants to tell | Game Developer / CK3 | rulers, successions, rivalries, named wars, chronicle |

## Feature matrix: top genre games vs Terra Bellum (✅ have · ◐ partial · ❌ missing)
| Feature | AoC2 | EU4 | Civ6 | CK3 | Supremacy | **TB now** |
|---|---|---|---|---|---|---|
| Province map, nations, eras | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ |
| Vassals / tribute / liberty | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| Peace deals (land, vassal, reparations) | ✅ | ✅ | ◐ | ✅ | ◐ | ◐ (land, vassal) |
| Casus belli / war justification | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Infamy / coalitions | ❌ | ✅ | ◐ | ◐ | ❌ | ◐ (target bias only) |
| Rulers with traits & succession | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Decisions / national focus / policies | ◐ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Rich historical events + chains | ◐ | ✅ | ◐ | ✅ | ❌ | ◐ (~40 events) |
| Random events with choices | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| Event log / chronicle / notifications | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (toasts only) |
| Advisors / contextual tips | ◐ | ✅ | ✅ | ◐ | ✅ | ❌ |
| Trade (routes / deals) | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Espionage | ❌ | ◐ | ✅ | ✅ | ✅ | ✅ |
| Statistics, graphs, rankings over time | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ (final standings only) |
| Multiple victory paths | ◐ | ◐ | ✅ | ❌ | ✅ | ✅ |
| Multiplayer | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Map modes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tutorial / onboarding | ◐ | ✅ | ✅ | ✅ | ✅ | ◐ (6 steps) |

## Prioritised backlog from this research (value ÷ cost)
1. **Chronicle + alerts + advisor tips** (UX: players miss toasts; every genre leader has an event log) — cheap, high value.
2. **Rulers**: named leader per nation with traits, ageing, succession events — cheap, strong storytelling, fixes the "no leaders" complaint.
3. **Infamy & coalitions + casus belli**: conquering raises infamy; high infamy makes neighbours form a coalition; war with a CB is cheaper — cures runaway empires and adds diplomacy depth.
4. **Decisions / national focus**: timed, costed projects with permanent modifiers (military reform, trade boom, centralisation) — gold sink + strategic identity.
5. **Historical content expansion**: ~8–12 dated events per era with consequences (the biggest content gap).
6. **Statistics screen**: nation power history graph, ranking over time.
7. **Trade deals** between friendly nations (income) — small version of trade routes.
8. Later: generals, formable nations, marriage, leaders' portraits, supply/attrition, achievements, async rooms.
