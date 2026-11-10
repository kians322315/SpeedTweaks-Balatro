# SpeedTweaks (WIP)

A little Balatro mod I made with AI that makes very long scoring calculations finish much faster **without
changing the final score**. (Well, atleast it shouldn't)

It skips scoring work the engine performs but which cannot possibly produce an
effect on the game. The score, the jokers, the RNG and the game state are identical — only
wasted checks the engine does disappear.

Built and tested against a run (Cryptid) making **354 million** scoring calls in a single
hand.

## Result

| | Before | After |
|---|---|---|
| `Card:calculate_joker` calls | 354,512,994 | 121,425,742 |
| Hand time | ~1344 s (22.4 min) | **460 s (7.7 min)** |
| Speedup | — | **2.9×** |

Measured on a 99-card hand holding 44 jokers, 108 consumables and 42 vouchers.
`calculate_joker_skip_ratio` was **65.7 %**, and `1 / (1 − 0.657) = 2.9×`
matches the observed time exactly.

The gain scales with how many consumables and vouchers you hold, because those
are the cards that get evaluated on every scoring pass without being able to act.

## Why the skipped checks are provably free

Steamodded rewrites `Card:calculate_joker` into this dispatch:

```lua
local obj = self.config.center
if self.ability.set ~= "Enhanced" and obj.calculate        then ... end
if context.scaling_card   and obj.calc_scaling             then ... end
if context.resetting_card and obj.calc_resetting           then ... end
if self.ability.set == "Joker" then ... vanilla chain ... end
```

The **only** set-gated branch is `"Joker"`. So a card with no
`calculate` / `calc_scaling` / `calc_resetting` handler that is not a Joker
**must** return `nil` — in every context, for every mod set.

Meanwhile `SMODS.calculate_card_areas('jokers')` walks `G.jokers` **and**
`G.consumeables` **and** `G.vouchers` on every scoring pass. A hand holding 108
tarots therefore pays for 108 do-nothing evaluations per pass, each one walking
Steamodded's context stack, Cryptid's wrapper, Amulet's coroutine bookkeeping and
the vanilla chain, to reach `nil`.

SpeedTweaks returns that `nil` immediately.

## What it does

1. **Inert-card fast path** on `Card:calculate_joker`. Returns `nil` for provably
   inert cards before any wrapper runs.
2. **Calculation slices.** If Amulet/Talisman is present, its coroutine yield
   interval is raised from `0.03 s` to `0.12 s`. With animations disabled the
   extra frame trips are pure loss.

**I can only do so much testing on my system, your results may differ.**

## Install

Requires [Steamodded](https://github.com/Steamodded/smods). Lovely injector
required as usual.

Download the source code.
Copy the `SpeedTweaks` folder to your mods directory:

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\Balatro\Mods\SpeedTweaks\` |
| Linux/Proton | `.../compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods/SpeedTweaks/` |
| macOS | `~/Library/Application Support/Balatro/Mods/SpeedTweaks/` |

Mods live in the **save** directory, not the game install directory.

## Output

After each hand it writes `speedtweaks.txt` next to `profile.jkr`:

```
[SpeedTweaks] hand finished
slice=0.12  yield_every=1000
calculate_joker_skipped=233087252
calculate_joker_run=121425742
calculate_joker_skip_ratio=65.7%
Amulet_last_calcs=121387308
Amulet_last_time=460.44s
reps_scored_cards=99
reps_max_per_card=913
reps_avg_per_card=272
```

Note `Amulet_last_calcs` reads **lower** than before. That is the skipped calls,
not a smaller score.

## Compatibility

| Mod | Status |
|---|---|
| Steamodded | **Required** |
| Amulet / Talisman | Works; slice tuning active. Its wrapper is bypassed only for provably-inert cards. |
| Cryptid | Works. Instance-level `calculate_joker` overrides (Cryptid exotics) are detected via `rawget` and never skipped. |
| HandyBalatro | Compatible (does not touch `Card:calculate_joker`). |
| CardSleeves, TwoRowJokers | Compatible (no references to the function). |
| JokerDisplay | Compatible (display only). |
| Mods that add `calculate` to consumables/vouchers | Respected — such cards are never skipped. |
| Mods that replace `Card:calculate_joker` outright without chaining | Fast path is bypassed; no effect, no harm. |

Will update this list on user feedback.

Safety rails:

- Disabled entirely if Steamodded is absent, because stock Balatro has a
  `set == "Planet"` branch (Observatory) and the inertness proof would not hold.
- Only returns `nil`, which is exactly what the engine's dispatch would produce.
  It never fabricates an effect table, so no return-shape assumptions are made.

## Toggles

At the top of `main.lua`:

```lua
local ENABLE_INERT_SKIP = true   -- the optimisation
local SLICE_SECONDS     = 0.12   -- Amulet slice length
```


It is very much an WIP, still some optimisations to be made.
For bugs/problems, open an issue and I will try to get it sorted. No guarantees though.




# **DISCLAIMER: THIS MOD WAS MADE ALMOST COMPLETELY WITH AI, USE AT YOUR DISCRETION**

## Licence

MIT.
