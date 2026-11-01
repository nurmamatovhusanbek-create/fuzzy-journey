# Covert operations (rules 4)

Before: success = clamp(0.60 + 0.08 × tech gap, 0.25, 0.90); a failure only cost 25 grudge; no defence, no discovery, nothing cut; the AI only used agents against nations it was at war with.

## The chance (`TBSpy.chance`, terms named for the interface)
`0.80` (a trained agent) `+ 0.10 × (your learning − theirs)` (±0.3) `− guard` where guard = `0.15 + 0.06 × their learning` (0.10 to 0.55: how well a court watches its house)
`+ 0.08` a fresh report from their court (`see_until`) `+ 0.10` kinship through marriage `+ 0.06` a trade route (merchants as eyes) `+ 0.06` a restless country (average stability under 55)
`− 0.05` sabotage, `− 0.10` incite (the nastier the work, the harder). Clamped to 10–90 %. About 45 % at equal learning for stealing.

How a country counters: its guard rises with its learning. How you raise your chance: stay ahead in learning, keep a report fresh (a successful operation gives one for 6 turns), marry into the court, keep trade, strike a country in turmoil.

## What follows (`TBSpy.consequences`)
- **Failed**: caught with 55 % + 0.6 × guard (max 90 %). A failure that is not caught costs only the intel.
- **Succeeded** (sabotage, incite): traced to you with 10 % + 0.5 × guard, at **half** the price below.
- **Price** of being caught (full) or traced (half): grudge of the target against you (steal 25, sabotage 40, incite 55) through `TBDiplo.hurt`, so the target's friends resent it too; your infamy (1, 3, 5).
- **Ties cut**: sabotage 50 %, incite 80 % (× the half for a trace): a non-aggression pact ends, a trade route ends, and their eyes shut out your agents (`see_until`). You cannot spy on allies or kin of the throne by rule, so those ties are not at risk.
- The chronicle tells the target who struck (and that it was traced), and tells you your agents were lost or exposed and which ties ended.

## How a court raises its guard (the player's levers)
- **Watchtowers** (the existing building, 60 gold): each province with one adds +2 % to the guard, six count at most (+12 %). The page of the building says so.
- **Military Academy** (a decree, rules 4 only, era 1+): 700 gold and 5 move points, **twelve turns of training with no effect**, then for good: +12 % guard, +5 % to your own operations, +3 % army strength. It is dear and slow because it reaches
  several areas at once (counter-intelligence, agents, the army). A save from before it existed loads (the decree table grows by one column).
- **Learning** counts 6 % per level already. The Realm page shows the guard ("Guard against agents: 33 % · 2 watchtowers").
- The AI buys the academy like any other decree (rich courts, now and then).

## Not done here
- No vigilance that rises after an incident; no casus belli from a caught incite.
- AI use is unchanged (at war, 12–32 % a turn when it has the intel).
- Tests: `tests/spy_logic.gd`.
