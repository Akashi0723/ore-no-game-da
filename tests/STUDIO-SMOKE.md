# Studio acceptance checks

Headless compilation and logic checks do not verify Roblox rendering, input,
physics, DataStores or real network replication. Run this list in Studio before
sharing the game. Keep real raid payments disabled until production ownership
recovery and the payment design are reviewed and verified.

## One-player first session

1. Connect Rojo, open Output and press Play. The generated world appears under
   `Workspace.WildboundWorld`; existing Studio world objects remain intact.
2. Follow rustling leaves, place the free berry, hold Sneak and befriend Mossbun.
   Check that guidance changes after each completed action, the capture is shown
   in the journal, and coins and snacks are never negative.
3. Run too close to a lured wild creature. The creature retreats and can be
   approached again. A failed action gives readable feedback.
4. Earn coins from a garden job, try again before its cooldown ends, then buy
   snacks. Photograph a clue twice: the first pays once and the second cannot
   farm the research reward.
5. Discover three distinct garden species. Repeated Mossbun captures do not
   count as new discoveries. Verify the pond gate unlocks for this player.
6. Move one creature between display and vault. Income, capacity and protection
   descriptions match actual behavior. Try buying with insufficient coins.
7. Run at least one weather cycle. Weather-specific spawns and the countdown
   update together; event and research objectives advance only on eligible actions.

## New progression and companion checks

1. Complete the naturalist trail in order. Each reward appears once; closing a
   panel, requesting Sync, rejoining, or repeating an earlier job cannot grant
   an already claimed reward. Check that the next waypoint points to its task.
2. Offer a snack, hold Sneak, and wait near the creature. The trust meter rises
   gradually; stepping out of range or releasing Sneak stops progress. A quick
   tap on Befriend must not grant the bonus shown for a fully patient approach.
3. Inspect all eight species. Garden discoveries unlock the pond at three unique
   garden species; a duplicate does not advance the milestone. Confirm the
   always-available pond creature permits progress in every weather.
4. Find Normal, Moonlit and Golden variants using a private test session. The
   variant name, creature appearance and journal entry agree after capture,
   display, vault storage and save/rejoin. Rarity and variant are labeled in text.
5. Equip an owned creature, respawn, switch companions and unequip it. Only one
   follows at a time, it cannot be captured or raided as a wild spawn, and it
   must disappear if that creature leaves the player's collection.
6. Feed an owned creature its preferred snack. The snack count falls once, bond
   rises within its limit and the cooldown is visible. A wrong snack, repeated
   click, reserved raid target or read-only profile must not consume supplies.

## Device and UI checks

1. Studio Device Emulator: test desktop, a narrow phone in landscape, and tablet.
   The HUD respects Roblox controls and screen insets. All panels scroll; the
   close button and primary action are reachable; longer descriptions stay inside.
2. Use touch controls for Sneak, Snack, Befriend, Photo and Net. Holding Sneak
   and releasing off the button, opening a panel, or resetting must not leave the
   player permanently slowed. UI buttons must not also activate world actions.
3. Test keyboard navigation and shortcuts with text boxes focused. Verify readable
   text contrast, different rarity names in addition to colors, and actionable
   disabled/pending explanations.
4. Join with no saved progress or unavailable saving. Session-only and save-error
   status must be honest. Never report permanent storage before it succeeds.
5. Check the redesigned HUD during a full raid and while a modal is open. Close,
   confirm, navigation, contextual actions and Roblox controls remain reachable
   on a narrow landscape phone. Dismiss with Escape and verify focus returns.
6. Turn off sound and reduce motion. Tasks, alerts, trust and cooldowns still
   communicate through readable text. Capture feedback does not hide the close
   button or lock input; UI transitions do not cause repeated reward sounds.

## Two-player competition and development raids

Use Studio **Test → Start** with two players. Development raids are free only
inside Studio; the paid raid button must be unavailable in a published server.

1. Both players approach the same wild creature. Only one obtains that spawn;
   the other gets feedback, and remote spam cannot award extra captures.
2. The protected tutorial creature is usable only by its tutorial owner.
3. Player A displays a creature. Player B begins a nearby raid. A receives an
   alert and can interrupt the six-second theft. The vault cannot be targeted.
4. Let B take the creature to extraction. The chase lasts 60 seconds and does not
   silently transfer ownership before completion.
5. A lands three net hits. Check range and cooldown enforcement and that the
   creature returns exactly once with no duplicate in B's collection.
6. B leaves, dies, resets, or falls out of the map during theft and again during
   the chase. Every case cancels the raid and restores A's creature.
7. A leaves during the raid, changes display status, or triggers concurrent
   raids on the same creature. No creature is lost or duplicated.
8. Let a legitimate chase succeed. Ownership changes once; a late net request
   or repeated completion cannot steal or duplicate the finished transfer.
9. Send malformed, too-distant and fast repeated RemoteEvent requests from a
   test LocalScript. They must not grant coins, creatures, XP or raid success.

## Persistence and publishing gate

Publish a private test experience and enable its intended DataStore setup. Verify
new profile creation, save/rejoin, two-server session-lock behavior and failure
recovery. Do not enable paid raids while cross-profile recovery is unavailable.
Use a separate test experience for payment receipt and disconnect scenarios.
