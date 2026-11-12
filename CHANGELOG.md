# Changelog

## 0.1.1

- Duplicate-install guard. Balatro loads every folder in `Mods` that contains a
  `smods.json`, so extracting the zip twice runs this file twice and installs
  the wrapper on top of itself. The second copy now logs one line and exits.
- No scoring change.

## 0.1

- Skip `Card:calculate_joker` for cards that provably cannot produce a scoring
  effect: no `calculate` / `calc_scaling` / `calc_resetting` handler and not
  `set == "Joker"`.
- Instance-level `calculate_joker` overrides (Cryptid exotics) are detected with
  `rawget` and never skipped.
- Amulet/Talisman calculation-slice tuning (`0.03 s` → `0.12 s`).
- Per-hand report written to `speedtweaks.txt`.
- Disabled automatically when Steamodded is not present.

Measured: 354,512,994 → 121,425,742 `calculate_joker` calls (65.7 % skipped),
~1344 s → 460 s on a 99-card hand (2.9×).


