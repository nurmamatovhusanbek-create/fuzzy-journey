# Research, November 2026: games like Terra Bellum, and the interface

Method: web searches and a handful of primary pages (Paradox dev diaries, Soren Johnson's Old World notes). Evidence is graded for each point; many search hits were aggregator or forum posts and are marked weak. Not covered: Supremacy 1914 and Conflict of Nations (searches returned nothing usable).

## Next steps (our own backlog)

* **Check 1.5.0 on real devices.** The APK and the Windows build are untested on hardware. What to watch: frame time and memory with the 5120x2560 title globe, the size of the new numbers in every window, a full game on a mid-range phone.
* **Walk every window under rules 5.** The suites pass, but a screen-by-screen pass at phone and desktop sizes has not been done since gold and people grew by two orders of magnitude (HUD chips, nations list, budget, dossier, peace table, stats, goals). Fix what reads badly (billions, long labels).
* **Teach the new start.** In rules 5 a nation starts with its whole army in the capital. How to play, the tutorial and the advisor do not say so yet, and there is no one-tap way to spread it (see G3).
* **Tighten the historical people.** Regional estimates spread by today's geography (1804 France 22 million against about 29 in history). A per-country correction table and a sources page would make it defensible.
* **A real late-game use for gold.** Open from the audit: one AI giant banks tens of millions with nothing to buy. Needs a design decision (see G1).
* **Review new Russian and Uzbek text.** Everything added since 1.4.0 was translated by me; a native speaker should read it.

## Games like ours: what to improve

| id | idea | value | effort |
|---|---|---|---|
| G1 | Gold needs a sink that grows with size | High | Medium |
| G2 | Undo for the turn | High | Medium |
| G3 | Mass orders and army templates | High | Medium |
| G4 | Make the AI legible and give it real aims | High | Large |
| G5 | Fill the diplomacy gaps players name | Medium | Medium |
| G6 | A population panel that explains itself | Medium | Small |
| G7 | Keep eras separate; do not copy Civ VII's reset | Low | — |
| G8 | Fast turns and short sessions on mobile | Medium | Small |
| G9 | Not found: Supremacy 1914 and Conflict of Nations | — | — |

### G1. Gold needs a sink that grows with size

Our audit found hoarding giants. Paradox ran into the same thing and answered with decline mechanics: EU5 1.1 adds a "complacency" stat so unchallenged empires slowly rot, and turns weak uprisings into local debuffs instead of endless small wars. Victoria 3 keeps the economy interesting because pops spend and demand things. For us: upkeep or corruption that rises with realm size and idle gold, court and prestige projects, and standing-army or garrison costs that bite at scale.

Evidence: Medium evidence (one dev changelog, one review). Sources: [FinalBoss on EU5 1.1 "Rossbach" UI changes](https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui); [Game Critics review of Victoria 3](https://gamecritics.com/mitch-zehe/victoria-3-review/)

### G2. Undo for the turn

Old World's designer calls the undo button one of the two best decisions of the game: it started as a misclick fix and became a core feature because players could test an attack and reverse it. We already have a deterministic engine and save snapshots, so "undo this turn's orders" is feasible for everything before the first random roll. On a phone, where misclicks are the main danger, it matters more than on desktop.

Evidence: Strong evidence (the designer's own notes). Sources: [Soren Johnson, Old World Designer Notes #1: Orders](https://www.designer-notes.com/old-world-designer-notes-1-orders/); [Soren Johnson, "My Elephant in the Room" (Old World postmortem)](https://www.designer-notes.com/my-elephant-in-the-room-part-1/)

### G3. Mass orders and army templates

EU5 1.1 added move-all by category, mass building upgrades, saveable army and navy templates, multi-location recruitment with automatic rendezvous, and formation automation, because the late game became a chore of repeated clicks. Old World's designer calls automation "a warning sign that a system may need rethinking". Rules 5 makes this urgent for us: every nation starts with one stack in the capital that has to be spread. Candidates: "distribute to the border", "recruit across the front", saved army templates, a "move all idle armies" button.

Evidence: Strong evidence. Sources: [FinalBoss on EU5 1.1 "Rossbach" UI changes](https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui); [GameWatcher on EU5 1.1 (alerts, templates)](https://www.gamewatcher.com/europa-universalis-5-rossbach-update-1-1-hidden-alerts-army-navy-templates-quality-of-life-changes); [Soren Johnson, "My Elephant in the Room" (Old World postmortem)](https://www.designer-notes.com/my-elephant-in-the-room-part-1/)

### G4. Make the AI legible and give it real aims

HoI4 players keep asking for a smarter AI; a developer answer cited says the AI ignores casualties because modelling them would make it passive. Our own audit shows thousands of wars with almost no change on the map. EU5 now shows AI "conquer desire" and "threat" overlays. For us: war goals that annex a nation or a region (not one province), alliances that act on them, and an overlay showing who each AI is aiming at and why.

Evidence: Medium evidence. Sources: [GamePressure on HoI4 AI complaints](https://www.gamepressure.com/newsroom/players-are-calling-for-smarter-ai-in-hoi4-but-theyre-not-convinc/z88529); [FinalBoss on EU5 1.1 "Rossbach" UI changes](https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui)

### G5. Fill the diplomacy gaps players name

Age of History 3 players ask for features of the earlier game: release a vassal, a trade tab, forming a coalition, annexing vassals; one critic notes peace treaties and colonisation depth. We have trade, coalitions and a peace table, but not release-vassal or formable nations (still listed as not ported).

Evidence: Medium evidence (Steam threads, secondary reviews). Sources: [Age of History 3 on Steam (community discussion)](https://steamcommunity.com/app/2772750/discussions/2/7004880749908236207); [PCGamesN on Age of History 3](https://www.pcgamesn.com/age-of-history-3/new-steam-strategy-game)

### G6. A population panel that explains itself

Victoria 3's 1.2 reworked its population overview after players could not see size, income, spending and what drives unrest, and put the "why" into tooltips. We just made people real; the dossier shows the number but not growth, ceiling, mood drivers, levy and workers together.

Evidence: Strong evidence. Sources: [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements)

### G7. Keep eras separate; do not copy Civ VII's reset

Civ VII's era transitions, where you pick a new civilisation each age, are its most divisive change; players say it wipes out achievements and breaks the feeling of leading one empire, and a later update lets players keep one civ. Our design (a scenario per era, one nation throughout) avoids that. Keep it; offer the chain of eras as a campaign instead.

Evidence: Weak evidence (forum posts; one quote unverified). Sources: [Civ VII post-mortem thread (CivFanatics)](https://forums.civfanatics.com/threads/civ-vii-post-mortem-crafting-a-redemption-arc.699434/post-16854810)

### G8. Fast turns and short sessions on mobile

Polytopia's developer says the goal is making the complex feel simple, introducing concepts gradually, and reviewers note a turn takes under a minute and a whole game can be 30 minutes. Our turns are heavier. Worth: a fast-forward for AI turns, turn summary that can be skipped, a short scenario length option, and a "quick game" preset.

Evidence: Medium evidence (developer statements). Sources: [Cubed3 interview with the Polytopia developer](https://www.cubed3.com/features/interviews/interview-with-midjiwan-ceo-christian-lovstedt-on-the-battle-of-polytopia)

### G9. Not found: Supremacy 1914 and Conflict of Nations

My searches returned nothing useful on these two, the closest commercial mobile rivals; the retention and monetisation lessons from them are not covered here. Worth a second pass with their own forums and reviews.

Evidence: Gap in this research. Sources: none

## Interface and UI: what to improve

| id | idea | value | effort |
|---|---|---|---|
| U1 | Alert management: categories, mute, auto-pause | High | Small |
| U2 | Breakdown tooltips and linked terms | High | Medium |
| U3 | Search, sort and pinned filters on every list | Medium | Medium |
| U4 | Outliner: what needs me, pinned | High | Medium |
| U5 | Onboarding that teaches how to play, not what buttons do | High | Medium |
| U6 | Explain why the AI said no | Medium | Small |
| U7 | Battle report with the arithmetic | Medium | Small |
| U8 | Touch targets and radial menus done carefully | Medium | Small |
| U9 | Accessibility: colour-blind safe maps, scaling that does not break | Medium | Medium |
| U10 | New lenses for the new numbers | Medium | Small |
| U11 | Rebindable keys and a shortcut sheet on desktop | Low | Small |

### U1. Alert management: categories, mute, auto-pause

Victoria 3 1.2 cut notifications by roughly half and added a Message Settings window that controls how each kind shows and whether it pauses the game. EU5's most recurrent UI complaint was alert overload and 1.1 added alerts that can be permanently muted with a menu to bring them back. We have an advisor and a ticker but no per-kind control.

Evidence: Strong evidence. Sources: [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements); [GameWatcher on EU5 1.1 (alerts, templates)](https://www.gamewatcher.com/europa-universalis-5-rossbach-update-1-1-hidden-alerts-army-navy-templates-quality-of-life-changes); [FinalBoss on EU5 1.1 "Rossbach" UI changes](https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui)

### U2. Breakdown tooltips and linked terms

The most praised Victoria 3 feature is the nested tooltip: any term or number opens its explanation and the calculation behind it; reviewers say it taught more than hours of video. CK3 made text hoverable inside tooltips; Old World lets you middle-click any term. We have tips and a codex, but our key numbers (income, stability target, worth, levy cap, population ceiling) do not show their sums. We already compute every term, so this is mostly plumbing.

Evidence: Strong evidence. Sources: [PCGamesN on Victoria 3 nested tooltips](https://www.pcgamesn.com/victoria-3/nested-tooltip-system); [Game Critics review of Victoria 3](https://gamecritics.com/mitch-zehe/victoria-3-review/); [PC Gamer on making Crusader Kings 3 easier to learn](https://www.pcgamer.com/the-crusader-kings-3-team-is-working-hard-to-make-the-game-easier-to-learn/); [Soren Johnson, "My Elephant in the Room" (Old World postmortem)](https://www.designer-notes.com/my-elephant-in-the-room-part-1/)

### U3. Search, sort and pinned filters on every list

EU5 pins common filters per screen and added a search-and-filter system for every list to fight information overload; Victoria 3 added sortable trade routes and a country grouping. Our nations list, provinces list and goals have fixed order.

Evidence: Strong evidence. Sources: [FinalBoss on EU5 1.1 "Rossbach" UI changes](https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui); [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements)

### U4. Outliner: what needs me, pinned

Victoria 3's Outliner lets you pin goods and characters and shows approval, labour and qualifications at a glance. A side list of running projects, armies, wars, rulers and pinned provinces would replace many window hops, especially on a phone.

Evidence: Medium evidence. Sources: [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements)

### U5. Onboarding that teaches how to play, not what buttons do

Common failure: onboarding that explains controls but not how to start; a long tutorial is a tax; successful ones start simple and add systems gradually and give a personal stake. CK3 invested in a refreshed tutorial and highlighted-text encyclopedia. Ours is six steps. Better: an objective list for the first ten turns of any scenario, an advisor that points at the one useful move, and a scenario briefing that names three first moves.

Evidence: Medium evidence (articles, not studies). Sources: [Game Wisdom on onboarding](https://game-wisdom.com/critical/onboarding); [PC Gamer on making Crusader Kings 3 easier to learn](https://www.pcgamer.com/the-crusader-kings-3-team-is-working-hard-to-make-the-game-easier-to-learn/)

### U6. Explain why the AI said no

Victoria 3 added a clearer AI acceptance display and signals for whether an obligation would sway the AI, and shows why a play is blocked. We show a percentage chance; adding the three or four terms behind it (+ allies, - grudge, + marriage) turns a gamble into a decision. Our "why blocked" requirement lists already follow this idea.

Evidence: Strong evidence. Sources: [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements)

### U7. Battle report with the arithmetic

Victoria 3 added more battle data and tooltips with calculation breakdowns because combat was hard to understand, and reduced clutter from overlapping front markers. We have a preview; a short after-action card (strength, terrain, general, losses by round) would teach the battle rules without a manual.

Evidence: Medium evidence. Sources: [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements)

### U8. Touch targets and radial menus done carefully

General guidance: targets at least 44 px, at most two touch points, always a way to cancel, menus no deeper than about three levels, radial menus as temporary overlays that keep play moving; Paradox itself used radial menus for console. Our ring and verb bar fit this; worth an audit at phone density with large-touch on and off, and a visible cancel on every order mode.

Evidence: Weak to medium evidence (general design blogs; one primary Paradox source). Sources: [Multi-touch RTS interface paper (Crenshaw et al.)](https://www.cin.ufpe.br/~if124/frame/turmas/turma_2013_1/artigos/multi-touch/p283-crenshaw.pdf); [300mind on radial menus in game design](https://300mind.studio/blog/radial-menus-in-game-design/); [Paradox console dev diary: UI, UX and controls](https://admin-forum.paradoxplaza.com/forum/developer-diary/console-dd-3-ui-ux-and-controls.1516699/page-2)

### U9. Accessibility: colour-blind safe maps, scaling that does not break

Victoria 3 shipped a colour-blind mode (default, tritanopia, protanopia/deuteranopia) and promised UI scaling that works out of the box; older Paradox games drew complaints about red and green in map modes and scaling that blurred or broke the frame. We have colour-blind, contrast, text-scale and spoken-text options; the gap to check is the map itself: lenses that rely on red against green, and patterns or labels as a second channel.

Evidence: Medium evidence (forum posts and a dev diary). Sources: [Victoria 3 Dev Diary #29, user experience (colour-blind mode, UI scale)](https://admin-forum.paradoxplaza.com/forum/developer-diary/victoria-3-dev-diary-29-user-experience.1506484/page-3)

### U10. New lenses for the new numbers

EU5 added economy base, food balance, coalition and AI-intention modes so players can find data and anticipate conflict. With real people we can add: growth room (people against the ceiling), levy pool, army per head, and later AI aim.

Evidence: Medium evidence. Sources: [FinalBoss on EU5 1.1 "Rossbach" UI changes](https://finalboss.io/europa-universalis-5-rossbach-1-1-tackles-ui)

### U11. Rebindable keys and a shortcut sheet on desktop

Victoria 3 replaced its shortcut system with rebindable keys and more places for them. A desktop build with a remembered set of keys and a help overlay costs little.

Evidence: Medium evidence. Sources: [Victoria 3 Dev Diary #74, UX improvements (Paradox)](https://www.paradoxinteractive.com/games/victoria-3/news/dev-diary-74-ux-improvements)

## Suggested order

1. Teach and spread the new start (U5 + G3), because rules 5 shipped without it.
2. Alerts, breakdown tooltips and undo (U1, U2, G2): the three things the best of the genre invested in.
3. Outliner, lists with search and sort, population panel (U4, U3, G6).
4. The gold sink and AI war goals (G1, G4), which need design decisions from you.
5. The smaller items as filler between releases.
