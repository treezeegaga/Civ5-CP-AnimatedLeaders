# Pre-flight review checklist

Before a build goes to the PCs (AGENTS.md rule 0a), a fresh reviewer (an agent, not the code's author) reads the diff
against this list. The list grows: every bug a review or a test game finds gets a line under "Bug kinds found".

## How to review

- Read-only. Review `git diff <last tested build> <candidate>` in the DLL repo, with the full source for context.
- Report at most 8 findings, most severe first: file:line, the concrete scenario, the fix in 1-2 lines, and CONFIRMED
  (traced) or POSSIBLE. Say "CLEAN" plainly if there's nothing.

## Cases to walk through

- **Civ types:** early-spike strike civ; late-strike civ; generic Composite Bowman rush (bGenericRush); a warmonger with no
  plan (bValid false); a non-strike AI; a human (must be unaffected); city-states (must be unaffected, no crash).
- **Strike states:** NONE, PREP, BUILDUP, WAR, OVER, and every transition. Check that each state can be left for a
  reachable game-state reason (no deadlocks).
- **Cities:** the capital vs the other cities.
- **War situations:** attacked by the target; attacked by a third party; the target killed or protected by someone else
  (defensive pact, vassal); no target in reach; only city-state targets.
- **Units:** an obsolete or unbuildable list item; a core that needs a strategic resource; losses mid-build-up.
- **Gold:** unit upkeep driving net gold negative; the treasury at 0; the upgrade bill.

## The user's rules (any break is a finding)

- No turn windows in AI strike decisions. Only logs may use turns. Exits come from game state.
- No world or national wonders and no city-state gold (gifts or gift saving) before the strike civ's first own
  declaration.
- The strike civ declares no war of its own before its strike.
- Warmongers buy only settlers and siege with gold; no Warriors ever. Strike build-ups get no exception.
- Follow the expert list. CP's own picks never fill in before the strike, except for a defender in danger.
- Multiplayer-safe: no local-only state, deterministic.

## Bug kinds found so far

- **Free vs owned resources:** `canTrainUnit` and `getNumResourceAvailable` count only unused resources, so a strike that
  builds its own Horse or Iron units looks "untrainable". Use the owned total (`getNumResourceTotal`) and the quantity
  needed.
- **Bans covering only some strike states:** e.g. only the EarlyStrike book, or only BUILDUP. Ban by
  "before the first own declaration", at the chokepoints: `CvCity::canConstruct`, `DoGoldGiftFromMajor`,
  `StartSaveForPurchase`.
- **Fallback around a veto:** when the sanity check vetoes everything, CP falls back to the unchecked list (wonders
  included).
- **Bans lifted by the wrong war:** allied city-states declaring on us counted as "we declared".
- **Deal paths that skip a block:** war bribes, co-op wars, move-troops requests, defensive pacts, voluntary vassalage.
  The AI takes the payment or bonus and doesn't act, or gets dragged into a war.
- **A turn count in a decision:** fallback turns, peace-treaty dampener turns.
- **A cache the UI can reach:** a plan that depends on HasTech or other per-turn state, built on different turns on
  different clients, causes a multiplayer desync.
- **Private or const access:** a function called from another class while private, or a non-const call on a const
  pointer. The build breaks.
- **Two merged fixes contradicting each other:** e.g. a saving condition that equals the state transition it was meant
  to precede.
- **Target logic fighting CP's:** our pin and CP's committed-target loop undoing each other every turn.
- **Target sets that disagree:** the target picker counts city-states but the in-reach check doesn't.
- **Exits that end a working strike:** a resource exit firing after the army used its own resources; "attacked by
  anyone" ending a strike.
- **The game's own war logic:** CP declares during PREP or BUILDUP and ends the strike.
- **A readiness check that never passes:** the strength check said a ready plan army "can't take" defence-19 and
  defence-11 cities, so it waited 39 turns for siege it couldn't train (trial24). Calibrate every readiness check
  against the user's game: 6 Jaguars + 4 Composite Bowmen took a walled defence-19 capital without siege. Make sure
  something the civ can't build never holds a declaration.
- **Unit scaling in combat math:** CP keeps damage and HP x100 in places. Mixing scaled and unscaled values made the
  take-the-city check 100x too strict (0cb5402). Check the units of every value fed into a comparison.
- **Silent refusal after the caller acted:** a low-level gate refuses after the payments, force-peace flags or
  UnitProcessed are already applied. Deal validity and unit selection must use the same check as the gate.
- **No exit on losing, superseded for the strike's war (the user, 2026-11-06 9:30pm ET: "they are ALL IN"):** a strike at
  war holds no-retreat until its target is finished, with no release by losses. Other locks (before the war, or outside
  the strike) still need a release when we're losing. Don't report the strike's war having no loss exit as a finding.
- **A state that outlives its purpose:** WAR keeping its ownership of production and gold until peace with everyone.
- **Dead guard:** a new branch put behind a condition that already rules out its success.
- **Mixed-team gates:** loops that skip humans but still block the human's own actions.
- **Game mechanics through AI gates:** Lua, vassal liberation and independence wars reach declareWar/makePeace and are
  swallowed. Gate on the originating player being the strike AI.
- **A clear that kills another branch:** clearing CP's state that another of our rules reads (the committed target)
  silently disables that rule.
- **Capture counts that aren't per-target:** any capture ends the strike or releases its lock.
- **Lua's missing arguments become 0:** an omitted player from Lua arrives as player 0, not NO_PLAYER.
- **Operations created outside RequestCityAttack:** show-of-force and bully operations skip the operations gate.
- **A wait that removes its own way forward:** the build-up stops building units while it waits for the city to become
  takeable.
- **"Plan valid" isn't "strike civ":** bValid is set for any civ with a unique unit or an expert row. Gates must use the
  strike-civ test.
- **One flag, several readers:** clearing a marker to unlock one path (the deploy turn for recruitment) also turns off
  tactical behaviour that reads it.
- **An empire-wide check approving a local decision:** the take-the-city check counts garrisons and the whole empire,
  and is used to clear one operation's army.
- **A new hold losing its predecessor's exemption:** 0055 widened 0048 but dropped the at-war exemption.
- **A rule placed before the scope check:** income-first sits ahead of the capital-only check and, through the pushOrder
  redirect, reaches every city.
- **An exit that ignores the upgrade line:** "core obsolete" ended a strike whose plan was to upgrade that core
  (Assyria, Archer to Composite Bowman).
- **A widened exit that the entry gates don't match:** the exit follows the upgrade line, but the buildable and window
  gates check only the base class, so the old exit turns into a deadlock.
- **A temporary block taken as a dead end:** an era gate triggering a fallback meant for a finished order.
- **An exit testing one blocker while another holds:** the stall exit checks "not takeable", but readiness can also be
  held by the upgrade bill or the field count.
- **A refusal that keeps a dead object alive:** gate 4 refused the half-strength abort of an operation whose last unit had
  died. The empty operation stayed "under way", blocked new attacks for up to 42 turns and crashed the logging on its
  NULL centre of mass (183D5D87). Every refusal must let an object with nothing left in it end, and logging must
  null-check what it prints.
- **A widened lock without the old release:** moving an exit later (the first capture to the target's capital, 227f759)
  kept every lock (no peace, no other wars, gate 4, WAR production) on when the capital can't be reached by land, or when the
  capital's attack fails and nothing else is requested. A later goal needs a release for when it can't be reached.
- **A "preferred" pass that blocks the fallback:** a flag set when the preferred target is listed, not when its attack
  actually started, so the normal pass never runs.
- **A goal that's already met at the start:** "the capital is ours" was true from the first turn when we already held it,
  so WAR went straight to OVER. Count only what changed during this strike (the per-war capture mark).
- **A tactical move that skips the safety passes:** a new move that runs before the heal and safety passes, and marks the
  unit processed, sends wounded units into danger along unsafe paths (SiegeCapturer review). Filter on shouldHeal and
  projected death, and use safe paths.
- **A new move placed inside the condition that rules it out:** the capturer call sat inside "some unit can strike the city",
  so the very case it was written for (nobody can strike) never reached it.
- **Unit filters that admit units that can't do the job:** "combat and not ranged" lets in defensive-only units that can't
  attack or capture.
