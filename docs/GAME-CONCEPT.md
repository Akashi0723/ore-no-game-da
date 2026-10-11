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

UI design is pending. Required surfaces: contextual creature actions, wallet/snack HUD, journal, shop, vault/display screen, raid cost disclosure, owner alert, and chase timer/hit feedback. No UI or runtime checks have been performed.

Use the existing GitHub/Rojo workflow. Git stores Luau source and project configuration. Rojo syncs local files to Studio; cloud changes require delivery and a local pull. Do not assume direct Studio MCP access or automatic cloud-to-Studio synchronization.

## Risks and unresolved choices

- Rare losses and progression advantages may discourage beginners: test the protected first encounter, attainable garden spawns, competition, and vault usefulness with mixed-progress players.
- A Robux purchase with uncertain outcome requires current Roblox policy review and explicit outcome disclosure. Do not describe this economy as free of spending advantages or automatically compliant.
- Purchase races, competing thieves, exits, and shutdowns threaten single ownership: define raid reservations and durable recovery before monetized testing.
- Confirm whether stolen creatures count toward discovery milestones. Recommendation: distinguish ownership from wild research so theft cannot replace all exploration.
- Combat balance, net cooldown, stealing duration, chase speed, spawn weights, income rates, pricing, and event cadence remain tuning decisions, not agreed numbers.

This version implements the garden loop, collection progression, weather, sanctuary growth, daily research, rotating weekly collections, and session-only Studio raid practice. Paid raids, durable production transfers, larger worlds, and trading remain later milestones. The generated world and interface still need the documented Studio acceptance checks.
