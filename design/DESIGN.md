# Wildbound visual system

A cozy Roblox creature collector: a scenic forest with a soft, compact HUD and
chunky controls. The world has priority. Desktop uses a narrow icon rail, small
weather/title plate, wallet, objective, encounter card, and three bottom
quickslots. Phone layouts use a horizontal rail and lift controls clear of the
Roblox joystick and jump button. Short landscape screens keep the first
collection row visible and scroll additional content.

The live palette is mint paper #EAF3E5, deep forest ink #193838, cream #FFFBEC,
teal #17695E, leaf #619E58, berry #C25465, gold #FFCA59, muted #3F5C55,
peach #F7B97C, and sky #C0E1E5. Roblox FredokaOne supplies titles; Gotham
supplies readable labels and copy. Dark outlines, rounded panels, and shallow
raised-button shadows give the UI a game identity. Icons are native Roblox
Frames, so controls need no fetched image asset. Buttons have visible focus,
pressed, pending, and disabled states. UI contrast is checked against live colors.

Collection entries use real animated ViewportFrame portraits, species colors,
discovery counts, search, and filters. Creature detail keeps snack, weather,
forecast, and capture instructions together. Coin changes animate briefly;
notifications remain clear of encounter and jump controls. Journey milestones
show a concrete next action. Sanctuary ownership, vault/display exposure,
companion bond, and feeding cooldown remain explicit.

Forest islands rise above water; layered stone paths lead between the elder oak,
rustic market, lantern clearings, sanctuary village, and Stillwater lagoon.
Background pine ridges frame exploration. Waterfalls and bridges make the pond
feel like a discovery. Ferns, mushrooms, flowers, and warm lanterns create small
landmarks. Interactive clearings remain navigable and free of dense decoration.
Ground layers have distinct heights to avoid flickering surfaces.

Eight native creature silhouettes have hierarchical joints: bunny ears and
hops, moth wings and antennae, hog feet and sniffing, frog/reed motion, fish fins,
fox tail and head, and stag steps and antlers. Root movement belongs to the
server. Presentation only poses child parts, including blinking eyes. Animation
work and foliage sway have fixed budgets. Reduced motion preserves readable
states while removing extra movement; Low Effects lowers visible-model budgets.

Editable SVG references live in `design/handoff/`; see `docs/UI-HANDOFF.md`.
They are design boards for Figma import, not screenshots of a running Studio
session. Native geometry previews likewise use the real authored models but
render outside Roblox. Final camera, device, replication, and performance checks
belong in Roblox Studio.
