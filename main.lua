-- SpeedTweaks
-- Score-neutral scoring-time optimisations for modded Balatro.
--
-- Author: kians322315
-- Requires: Steamodded
-- Optional: Amulet/Talisman (calculation-slice tuning)
--
-- Every call skipped here is one the engine provably resolves to "no effect".
-- Nothing changes scoring, jokers, odds, RNG, or game state.

local SLICE_SECONDS     = 0.12   -- Amulet yield slice (default 0.03)
local YIELD_CHECK_EVERY = 1000   -- Amulet yield granularity (default 250)
local ENABLE_INERT_SKIP = true   -- skip inert Card:calculate_joker
local VERBOSE           = true

-------------------------------------------------------------------------------
-- Why this only runs on Steamodded
--
-- Steamodded rewrites Card:calculate_joker so a card's handler lives in
-- config.center.calculate and the ONLY set-gated branch is:
--
--     if self.ability.set == "Joker" then ... end
--
-- Stock Balatro also special-cases set == "Planet" (Observatory), so on an
-- unpatched game a non-Joker card with no handler is NOT provably inert.
-- Rather than risk changing scoring on an unknown setup, we stand down.
-------------------------------------------------------------------------------
local HAVE_SMODS = type(SMODS) == 'table' and SMODS.calculate_card_areas ~= nil

if not HAVE_SMODS then
    print('[SpeedTweaks] Steamodded not detected - optimisations disabled')
    return
end

-------------------------------------------------------------------------------
-- Amulet calculation slices
--
-- With animations off, yielding to the frame loop every 30 ms of maths is pure
-- loss. Fewer, larger slices spend a larger share of wall time on arithmetic.
-------------------------------------------------------------------------------
if Talisman and Talisman.coroutine then
    Talisman.coroutine.frametime = SLICE_SECONDS
    Talisman.coroutine.framecalc = YIELD_CHECK_EVERY
elseif VERBOSE then
    print('[SpeedTweaks] Amulet not detected - slice tuning skipped')
end

-------------------------------------------------------------------------------
-- Can this card possibly produce a scoring effect?
--
-- No calculate / calc_scaling / calc_resetting handler and not a Joker means
-- the engine's dispatch cannot reach a single branch. Instance-level
-- calculate_joker overrides (Cryptid exotics use these) are excluded because
-- they bypass the class method that this test is based on.
-------------------------------------------------------------------------------
local function is_inert(card)
    local ab = card.ability
    if not ab or ab.set == 'Joker' then return false end
    if rawget(card, 'calculate_joker') ~= nil then return false end
    local c = card.config and card.config.center
    if not c then return false end
    if c.calculate or c.calc_scaling or c.calc_resetting then return false end
    return true
end

-------------------------------------------------------------------------------
-- The optimisation
--
-- Installed last (highest priority) so it is the outermost wrapper and
-- short-circuits ahead of Steamodded's context stack, Cryptid's wrapper,
-- Amulet's coroutine bookkeeping and the vanilla chain.
--
-- IMPORTANT: this returns exactly `nil`, which is what the engine's own
-- dispatch would have produced for these cards in every context.
-------------------------------------------------------------------------------
local skipped, ran = 0, 0
local orig_cj = Card.calculate_joker

function Card:calculate_joker(context)
    if ENABLE_INERT_SKIP and is_inert(self) then
        skipped = skipped + 1
        return nil
    end
    ran = ran + 1
    return orig_cj(self, context)
end

-------------------------------------------------------------------------------
-- Measurement: repetitions per scored card
-------------------------------------------------------------------------------
local reps_stats = { cards = 0, total = 0, max = 0, time = 0 }

if SMODS.calculate_repetitions then
    local orig_reps = SMODS.calculate_repetitions
    SMODS.calculate_repetitions = function(card, context, reps)
        local t0 = love.timer.getTime()
        orig_reps(card, context, reps)
        reps_stats.time = reps_stats.time + (love.timer.getTime() - t0)
        if type(reps) == 'table' then
            local n = #reps
            reps_stats.cards = reps_stats.cards + 1
            reps_stats.total = reps_stats.total + n
            if n > reps_stats.max then reps_stats.max = n end
        end
    end
end

-------------------------------------------------------------------------------
-- Report, written next to profile.jkr when a hand finishes
-------------------------------------------------------------------------------
local function report()
    local last = (G.GAME and G.GAME.LAST_CALC_TIME) or 0
    local total = skipped + ran
    local lines = {
        '[SpeedTweaks] hand finished',
        string.format('slice=%s  yield_every=%s', SLICE_SECONDS, YIELD_CHECK_EVERY),
        string.format('calculate_joker_skipped=%d', skipped),
        string.format('calculate_joker_run=%d', ran),
        string.format('calculate_joker_skip_ratio=%.1f%%',
            total > 0 and (skipped / total * 100) or 0),
        string.format('Amulet_last_calcs=%s', tostring(G.GAME and G.GAME.LAST_CALCS)),
        string.format('Amulet_last_time=%.2fs', last),
        string.format('reps_scored_cards=%d', reps_stats.cards),
        string.format('reps_total=%d', reps_stats.total),
        string.format('reps_max_per_card=%d', reps_stats.max),
        string.format('reps_avg_per_card=%.0f',
            reps_stats.cards > 0 and reps_stats.total / reps_stats.cards or 0),
    }
    local out = table.concat(lines, '\n') .. '\n'
    print(out)
    love.filesystem.write('speedtweaks.txt', out)
    reps_stats = { cards = 0, total = 0, max = 0, time = 0 }
end

local was_scoring = false
local orig_update = love.update
function love.update(dt, ...)
    local now = Talisman and Talisman.scoring_coroutine ~= nil
    if was_scoring and not now then report() end
    was_scoring = now
    return orig_update(dt, ...)
end

if VERBOSE then
    print(string.format('[SpeedTweaks] loaded (slice=%s, inert skip=%s)',
        SLICE_SECONDS, tostring(ENABLE_INERT_SKIP)))
end
