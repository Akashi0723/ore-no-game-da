# Creature game concept

Working title: Wildbound: Hunt & Heist (proposed, not selected).
Status: first playable implementation built under src. Compilation, headless logic tests, and Rojo packaging are validated; Roblox Studio playtesting is pending. Paid raids and production ownership transfers remain disabled.

## Player promise

Discover elusive creatures, earn their trust, build a sanctuary, and compete with rivals for rare catches and exposed collections. The visual theme can be charming, but theft makes this a competitive game rather than a purely cozy collector.

## Core loop and first session

Complete garden jobs and photograph clues → earn coins → buy snacks → follow clues → sneak, lure, and befriend a creature → earn Taming XP and collection progress → unlock areas and sanctuary improvements.

First encounter: moving leaves and a placement prompt lead the player to a free berry. A Mossbun emerges; the player holds Sneak, approaches, and taps Befriend. Target the first successful interaction within 30 seconds. The guided encounter is protected from competition. Early mistakes should permit an immediate retry. Find three distinct garden creatures to unlock the pond; duplicates do not advance this milestone.

## Confirmed design decisions

- Players earn coins through repeatable garden jobs and clue photography. Proposed safeguard: each distinct clue pays once per player; jobs remain available if snacks run out.
- Taming XP comes from wild befriending and research, unlocking better snacks and tools. Higher progression improves wild capture chances without guaranteeing rare catches. Exact probability curves remain unset.
- Wild encounters are exclusive: one player gets a spawned creature. Rare creatures are not guaranteed to respawn during the session. Weather, time, and rarity affect appearances.
- Competitors can lure away a wild creature before capture and raid owned collections.
- Vault creatures and offline owners are protected. Creatures displayed while the owner is online are exposed. Display income was recommended as the reason to accept risk; rates and eligible creatures remain unset.
- Each theft attempt prompts a Robux purchase before the attempt starts. This is the user's requested monetization; payment buys an attempt, not guaranteed success. Price, failed-attempt treatment, payment timing, and current Roblox policy compatibility must be resolved before implementation.
- The owner can interrupt the stealing interaction. After taking a creature, the thief must reach extraction and survive a 60-second marked chase. Ownership transfers only after success.
- Leaving early returns the creature. Apply the same rule to disconnects; account for both players disconnecting, server shutdown, and late purchase receipts before shipping.
- Three short-range defensive net hits make the thief drop the creature and end the raid. Proposed detail: hits persist across extraction and briefly slow the thief.
- Mobile controls: hold Sneak, with separate Snack and Befriend buttons. Defensive net controls should be contextual.
- Return hooks combine rotating weather encounters, recurring collection events, and sanctuary expansion/decorating.

## Return hooks (proposed implementation)

- First return: refreshed research tasks and a visible forecast for a different creature encounter.
- Following sessions: weather-dependent discoveries and sanctuary improvements give alternate goals.
- Week-long aspiration: complete a themed collection and unlock a habitat cosmetic. Avoid requiring daily attendance or paid catches for basic area progression.
- Regular updates: expand creature sets, clues, weather interactions, and decorations before expanding whole worlds. Event cadence is not yet committed.

## Build sequence

1. One protected Mossbun encounter: clue, free snack, Sneak, Befriend, sanctuary arrival. Verify the complete action on touch and desktop.
2. One repeatable job, one clue-photo reward, coin balance, shop, and snack consumption. Verify a player can recover from zero coins/snacks and rewards cannot be duplicated.
3. Three creatures, journal, Taming XP, and pond-unlock milestone. Save collection, coins, snacks, and progression; verify rejoin.
4. Competitive wild encounters and weather conditions. Test simultaneous claims and beginner progression.
5. Vault and display management, followed by an unpaid development-only raid test: interruption, extraction, chase, three net hits, early departure, and recovery. Verify single ownership and disconnect/shutdown behavior.
6. Paid attempt handling only after the raid is validated and monetization questions are resolved. Use server receipt processing that tolerates retries and unavailable targets; never grant ownership on a client purchase signal.
7. Expand sanctuary growth, scheduled research, and themed collection events after the core game is fun and stable.

## Technical and UI plan

Server authority: creature spawns/claims, taming resolution, currency/snacks, research rewards, progression, vault access, raid state, purchases, and ownership transfers. Client presentation: clues, camera/photo interface, touch controls, journal, shop, sanctuary UI, alerts, and chase markers. Validate and rate-limit all valuable-state requests.

Persist currencies, inventory, creature identity/ownership, research, unlocks, and sanctuary configuration. Treat active chase state as transient but durably resolve pending ownership so crashes cannot duplicate or destroy creatures. Protect exposed targets once their owner leaves; define the exact active-raid recovery rule before coding.

The native interface uses a soft mint/cream and teal game HUD over a scenic forest.
It includes Journey, searchable journal, shop, sanctuary bond/follow/display
controls, settings, contextual encounter trust/chance, wallet/snack HUD, owner
alerts, and chase timer/hit feedback. Compiler, logic, contrast, and packaging
checks are automated. Studio rendering, input, physics, and replication remain
acceptance tests on the actual platform.

The cozy exploration direction is confirmed: wooded islands, a lagoon and
waterfalls, winding discovery trails, a rustic market, and sanctuary village.
Eight creatures share articulated native models in the world and animated
collection portraits. Server patrols and lure approach keep encounters alive;
child-part poses add hops, ear turns, wing beats, fin movement, tail motion,
and blinking without changing capture authority. The generated map is visible
in Studio Edit mode through Rojo before Play starts.

Use the existing GitHub/Rojo workflow. Git stores Luau source and project configuration. Rojo syncs local files to Studio; cloud changes require delivery and a local pull. Do not assume direct Studio MCP access or automatic cloud-to-Studio synchronization.

## Risks and unresolved choices

- Rare losses and progression advantages may discourage beginners: test the protected first encounter, attainable garden spawns, competition, and vault usefulness with mixed-progress players.
- A Robux purchase with uncertain outcome requires current Roblox policy review and explicit outcome disclosure. Do not describe this economy as free of spending advantages or automatically compliant.
- Purchase races, competing thieves, exits, and shutdowns threaten single ownership: define raid reservations and durable recovery before monetized testing.
- Confirm whether stolen creatures count toward discovery milestones. Recommendation: distinguish ownership from wild research so theft cannot replace all exploration.
- Combat balance, net cooldown, stealing duration, chase speed, spawn weights, income rates, pricing, and event cadence remain tuning decisions, not agreed numbers.

This version implements the garden loop, collection progression, weather, sanctuary growth, daily research, rotating weekly collections, and session-only Studio raid practice. Paid raids, durable production transfers, larger worlds, and trading remain later milestones. The generated world and interface still need the documented Studio acceptance checks.

## Expanded discovery and companionship

Eight species keep the garden trio intact and expand Stillwater with Reedling,
Dewfin, Moonhare, Mistfox, and Bloomstag. Each wild spawn rolls its color variant
once: 96% Natural, 3% Moonlit, 1% Golden; fog changes those to 93%, 6%, 1%.
The protected first Mossbun is always Natural. Variants stay attached to the
creature's identity, including through a successful Studio raid.

After the lure is ready, three uninterrupted seconds of sneaking in range fill
trust. Full trust adds ten percentage points to capture chance, capped at 99%.
The first protected encounter succeeds when its conditions are met. Trust resets
when the player leaves range or releases Sneak; it cannot be granted by a client.

The Journey gives six sequential, automatically claimed milestones: first catch,
first garden job, two distinct clue photos, three garden discoveries, first
display, and first pond catch. Each reward is saved once. Syncing the UI does not
grant rewards.

An owned creature can be equipped as a cosmetic walking companion. Feed its
preferred snack at most once every two minutes for +10 bond, up to 100. Feeding
does not grant coins or XP. Display income receives +1 at 50 bond and +2 at 100;
the original Vault/Display choice determines theft exposure. Equipping a vault
creature does not expose it. A completed transfer clears the former owner's
equipped selection while preserving variant, bond, and feeding cooldown.
