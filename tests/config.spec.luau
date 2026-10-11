-- Executed against the real Config by tools/validate.py.
-- These checks protect progression boundaries, rarity balance and sane inputs.
assert(Config.GetLevel(0) == 1, "New players must start at level 1")
assert(Config.GetLevel(Config.LevelXP - 1) == 1, "XP boundary must not unlock tools early")
assert(Config.GetLevel(Config.LevelXP) == 2, "Exact XP boundary must award level 2")
assert(Config.GetLevel(Config.LevelXP * 3) == 4, "Multiple XP boundaries must advance correctly")

local known = {}
for _, species in Config.CreatureOrder do
    assert(not known[species], "Journal contains duplicate species: " .. species)
    known[species] = true
    local creature = assert(Config.Creatures[species], "Journal references an unknown creature")
    assert(Config.Snacks[creature.Snack], "A creature requires a snack the shop cannot sell")
    assert(creature.XP > 0, "Successful captures must grant progression")
    local firstChance = Config.CaptureChance(species, 1)
    local progressedChance = Config.CaptureChance(species, 10)
    local highChance = Config.CaptureChance(species, 10000)
    assert(firstChance > 0 and firstChance < 1, "Captures must be possible but uncertain")
    assert(progressedChance >= firstChance, "Progression must not lower capture odds")
    assert(highChance <= 1 and highChance >= progressedChance, "Capture odds must remain bounded")
end
assert(#Config.CreatureOrder >= 3, "Garden milestone needs at least three discoverable species")
assert(Config.CaptureChance("Mistfox", 1) < Config.CaptureChance("Mossbun", 1), "Rare creatures should be harder to capture")
for _, snack in Config.Snacks do
    assert(snack.Price > 0 and snack.Price % 1 == 0, "Shop prices must be positive whole coins")
    assert(snack.UnlockLevel >= 1, "Snack unlock levels must be valid")
end
assert(Config.Raid.ProductId == 0, "Unreviewed monetized raids must remain disabled")
assert(Config.Raid.NetHits == 3, "Raid recovery requires the agreed three hits")
assert(Config.Raid.ChaseSeconds == 60, "Extraction must preserve the agreed recovery window")
local function linear(channel)
    return if channel <= 0.04045 then channel / 12.92 else ((channel + 0.055) / 1.055)^2.4
end
local function luminance(color)
    return linear(color.R) * 0.2126 + linear(color.G) * 0.7152 + linear(color.B) * 0.0722
end
local paper = Color3.fromRGB(246, 242, 232)
for _, rarity in {"Common", "Uncommon", "Rare", "Legendary"} do
    local ratio = (luminance(paper) + 0.05) / (luminance(Config.RarityColor(rarity)) + 0.05)
    assert(ratio >= 4.5, "Small rarity labels must meet 4.5:1 contrast on the journal paper: " .. rarity)
end
print("PASS: progression boundaries, capture balance, journal references and development raid gates")
