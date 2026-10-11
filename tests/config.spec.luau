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
assert(#Config.CreatureOrder == 8, "The expanded journal must contain all eight authored species")
local alwaysPond=0
for _,species in Config.CreatureOrder do
    local definition=Config.Creatures[species]
    if definition.Zone=="Pond" and definition.Weather=="Any" then alwaysPond+=1 end
end
assert(alwaysPond>0,"Pond progress must have an encounter available in every weather")
assert(Config.CaptureChance("Mistfox", 1) < Config.CaptureChance("Mossbun", 1), "Rare creatures should be harder to capture")
for _, snack in Config.Snacks do
    assert(snack.Price > 0 and snack.Price % 1 == 0, "Shop prices must be positive whole coins")
    assert(snack.UnlockLevel >= 1, "Snack unlock levels must be valid")
end
assert(Config.Raid.ProductId == 0, "Unreviewed monetized raids must remain disabled")
assert(Config.Raid.NetHits == 3, "Raid recovery requires the agreed three hits")
assert(Config.Raid.ChaseSeconds == 60, "Extraction must preserve the agreed recovery window")
assert(Config.MaxBond==100 and Config.FeedBond>0 and Config.FeedCooldownSeconds>0,
    "Companion care must have bounded progress and a positive cooldown")
assert(Config.TrustSeconds>0 and Config.TrustChanceBonus>0 and Config.TrustChanceBonus<1,
    "Patient approaches must improve odds gradually within a bounded bonus")

-- Run the production weighted roll at exact boundaries, including hostile inputs.
assert(table.concat(Config.VariantOrder,",")=="Normal,Moonlit,Golden")
for _,variant in Config.VariantOrder do assert(Config.Variants[variant],"Variant order must reference a known definition") end
for _,sample in {
    {0,"Clear","Normal"},{0.959999,"Clear","Normal"},{0.96,"Clear","Moonlit"},
    {0.989999,"Clear","Moonlit"},{0.99,"Clear","Golden"},{1,"Clear","Golden"},
    {0.929999,"Fog","Normal"},{0.93,"Fog","Moonlit"},{0.989999,"Fog","Moonlit"},{0.99,"Fog","Golden"},
    {-1,"Clear","Normal"},{2,"Clear","Golden"},{0/0,"Clear","Normal"},
    {math.huge,"Clear","Normal"},{-math.huge,"Clear","Normal"},
} do
    assert(Config.RollVariant(sample[1],sample[2])==sample[3],
        "Variant boundary changed for roll "..tostring(sample[1]).." during "..sample[2])
end
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
print("PASS: progression boundaries, eight-species journal, capture balance, weighted variants, companion tuning and development raid gates")
