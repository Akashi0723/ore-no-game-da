# Wildbound UI design handoff

These editable vector boards describe the current cozy exploration interface:

- [Desktop encounter](../design/handoff/Wildbound-HUD.svg): 1440 × 900, with the first Mossbun encounter, weather, currency, objective, menu rail, trust and quickslots.
- [Creature collection](../design/handoff/Wildbound-Collection.svg): 1440 × 900, with the 900 × 680 collection modal, seven tabs, search, filters and eight creature silhouettes.
- [Mobile landscape](../design/handoff/Wildbound-Mobile.svg): 844 × 390, with the compact header, horizontal menu, large encounter button and quickslots clear of the thumb controls.

The boards contain grouped SVG shapes and editable text. The forest backdrop and
creature drawings are design references; they are not screenshots of Roblox
Studio or exports of the game's three-dimensional models. The collection board
uses a sample state with the three garden species discovered. Its second card
row is intentionally clipped by the scroll viewport, as in the game.

## Import into Figma

1. Download the SVG files or open `design/handoff/` in this repository.
2. Open your Figma design file and drag each SVG onto the canvas.
3. Rename the imported groups `Desktop HUD`, `Collection` and `Mobile landscape`.
4. Keep the `Environment-vector-reference` layer separate from the interface.
   Expand the named groups to edit the controls, icons, cards and text.
5. Turn a repeated menu button or collection tile into a component if you want
   to explore variants. Preserve the touch target dimensions below.

Figma's tools were unavailable in the current cloud session. These files were
created locally; no remote Figma design file was created. SVG import is the
concrete handoff for editing the design in your own Figma account. The artwork
uses local font fallbacks for portability. The game uses Roblox's native
`FredokaOne`, `Gotham` and `GothamBold` fonts; select suitable installed fonts
after import if Figma reports a missing font.

## Implementation reference

The implemented interface lives in [Game.client.luau](../src/client/Game.client.luau),
with editable native GUI icons in [UIIcons.luau](../src/client/UIIcons.luau).
The game renders the actual articulated creatures inside `ViewportFrame`
portraits. The SVG drawings represent their silhouettes without requiring
downloaded image assets.

| Token | Value | Use |
| --- | --- | --- |
| Paper | `#EAF3E5` | Menu surface |
| Ink | `#193838` | Text, outlines, title header |
| Teal | `#17695E` | Primary actions and selected controls |
| White | `#FFFBEC` | Secondary controls and cards |
| Gold | `#FFCA59` | Currency and gamepad focus |
| Muted | `#3F5C55` | Supporting text |
| Leaf | `#619E58` | Trust, XP and progress fills |
| Line | `#C6DCCC` | Tracks and quiet separators |
| Berry | `#C25465` | Berry snack accents |

Desktop navigation uses 72 × 68 controls with 32-pixel icons. Compact navigation
uses 50 × 52 controls with 24-pixel icons. Quickslots are 104 × 52, or 82 × 52
on narrower screens. The encounter action remains 126 × 44. Panels use rounded
corners and ink outlines; button shadows are simple offset shapes.

The bottom quickslots are **Sneak**, **Berry/Seed** and **Photo**. **Offer** and
**Befriend** live inside the contextual encounter card. Desktop encounter
actions use **E**; nearby field prompts use **F**. Controller encounters use
**X**; field prompts use **D-pad up**. Menus temporarily suspend field prompts so
controller navigation does not trigger world interactions.

The native UI also includes states the static boards do not animate: gamepad
focus, pending actions, disabled actions, the weather countdown, coin changes,
portrait movement and non-blocking capture feedback. Reduced motion and
lightweight effects are available in Settings. Final device and text-fit
acceptance still happens in Roblox Studio; an SVG preview does not verify the
native renderer.
