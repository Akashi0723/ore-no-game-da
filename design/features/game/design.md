# Game interface

Status: implementation authorized by user request; visual validation in Roblox Studio pending.
Mode: Experience / Operate.

Goal: find a clue, offer a snack, befriend a creature, and immediately understand collection progress. First view shows the garden, current objective, coins, and a small weather indicator. No start menu or purchase popup.

HUD: objective and progress, coins, Taming level/XP, weather timer, three menu buttons. Context actions name the current creature/job/clue; when out of range show a useful exploration hint rather than a dead button. Sneak is held on keyboard/touch and released on lost focus. Net appears during owner defense. Raid state shows phase, countdown, hits, and opponent.

Shop: two snack rows, price, quantity, locked level, Buy action; insufficient coins explains how to earn them. Journal: species portraits, rarity, preferred snack, discovery status and clues. Sanctuary: owned creature rows with Store safely/Display actions, risk notice, expansion price and capacity. Help: first-session instructions, keyboard/touch controls, paid raids availability. Raids panel shows clear development-only status until payment configuration and durable ownership are ready.

Default: active session values. Loading: connection/loading message, requests disabled until state arrives. Empty: no creatures yet with a next action. Error: nonblocking toast naming problem and recovery. Locked: pond discovery milestone, snack level, unavailable paid raids. Pending: action debounce and purchase buttons show work in progress.

Mobile: minimum 44–48px touch actions, landscape-safe playfield, reduced HUD, scrolling panels bounded to current viewport, no controls over default movement stick/jump. Desktop/tablet: panels centered with comfortable readable widths; keyboard bindings visible. Creature portraits use procedural geometry in ViewportFrames with a fixed camera and soft lighting.
