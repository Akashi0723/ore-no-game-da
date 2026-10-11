-- Shared descriptions and tuning. Only the server grants coins, creatures, or XP.
local Config = {}

Config.StartCoins = 30
Config.LevelXP = 100
Config.WalkSpeed = 16
Config.SneakSpeed = 7
Config.LureRange = 15
Config.BefriendRange = 8
Config.LureSeconds = 2
Config.LureLifetime = 35
Config.TrustSeconds = 3
Config.TrustChanceBonus = 0.10
Config.FeedCooldownSeconds = 120
Config.FeedBond = 10
Config.MaxBond = 100
Config.PhotoRange = 18
Config.PhotoReward = 18
Config.PhotoXP = 12
Config.JobRange = 14
Config.ShopRange = 20
Config.DisplayIncomeSeconds = 30
Config.DisplayIncomePerCreature = 3
Config.SanctuaryUpgradeBaseCost = 90
Config.MaxSanctuaryLevel = 4
Config.BaseDisplayCapacity = 2
Config.MaxCreatures = 60
Config.WeatherSeconds = 120
Config.WeatherOrder = { "Clear", "Rain", "Dusk", "Fog" }
Config.PlayableBounds = { MinX = -73, MaxX = 173, MinZ = -155, MaxZ = 87, MinY = 7, MaxY = 100 }
Config.CreatureOrder = { "Mossbun", "Lanternwing", "Pebblehog", "Reedling", "Dewfin", "Moonhare", "Mistfox", "Bloomstag" }
Config.VariantOrder = { "Normal", "Moonlit", "Golden" }
Config.Variants = {
	Normal = { Name = "Natural", Color = Color3.fromRGB(145, 169, 105), Accent = Color3.fromRGB(246, 220, 158) },
	Moonlit = { Name = "Moonlit", Color = Color3.fromRGB(180, 195, 231), Accent = Color3.fromRGB(225, 237, 255) },
	Golden = { Name = "Golden", Color = Color3.fromRGB(226, 184, 90), Accent = Color3.fromRGB(255, 235, 165) },
}
Config.Snacks = {
	Berry = { Name = "Wild berries", Price = 8, UnlockLevel = 1, Description = "Sweet little treats for curious creatures." },
	Seed = { Name = "Sunflower seeds", Price = 12, UnlockLevel = 1, Description = "A crunchy favorite of wings and whiskers." },
}

Config.Creatures = {
	Mossbun = {
		Name = "Mossbun", Rarity = "Common", Color = Color3.fromRGB(145, 169, 105),
		Accent = Color3.fromRGB(246, 220, 158), Snack = "Berry", XP = 30,
		Hint = "Follow the rustling leaves beside the garden paths.", Weather = "Any", BaseChance = 0.84,
		Zone = "Garden", Description = "A gentle leaf-eared friend with a soft spot for berries.",
		RespawnSeconds = 25,
	},
	Lanternwing = {
		Name = "Lanternwing", Rarity = "Uncommon", Color = Color3.fromRGB(228, 185, 100),
		Accent = Color3.fromRGB(152, 109, 171), Snack = "Seed", XP = 40,
		Hint = "A golden shimmer dances above the flowers at dusk.", Weather = "Dusk", BaseChance = 0.72,
		Zone = "Garden", Description = "A tiny moth whose wings glow in the evening light.",
		RespawnSeconds = 55,
	},
	Pebblehog = {
		Name = "Pebblehog", Rarity = "Uncommon", Color = Color3.fromRGB(149, 158, 164),
		Accent = Color3.fromRGB(217, 171, 136), Snack = "Seed", XP = 40,
		Hint = "Listen for tapping stones near the garden's rock piles.", Weather = "Any", BaseChance = 0.76,
		Zone = "Garden", Description = "A pocket-sized explorer with a back full of polished stones.",
		RespawnSeconds = 40,
	},
	Dewfin = {
		Name = "Dewfin", Rarity = "Rare", Color = Color3.fromRGB(115, 182, 182),
		Accent = Color3.fromRGB(207, 229, 182), Snack = "Berry", XP = 65,
		Hint = "Raindrops ripple around the pond's mossy stepping stones.", Weather = "Rain", BaseChance = 0.62,
		Zone = "Pond", Description = "An amphibious little companion who loves a rainy afternoon.",
		RespawnSeconds = 90,
	},
	Reedling = {
		Name = "Reedling", Rarity = "Common", Color = Color3.fromRGB(120, 162, 115),
		Accent = Color3.fromRGB(218, 228, 156), Snack = "Seed", XP = 35,
		Hint = "Watch for little reed crowns beside Stillwater's shallow banks.", Weather = "Any", BaseChance = 0.82,
		Zone = "Pond", Description = "A cheerful marsh dweller wearing a crown of fresh green reeds.",
		RespawnSeconds = 35,
	},
	Moonhare = {
		Name = "Moonhare", Rarity = "Rare", Color = Color3.fromRGB(182, 174, 211),
		Accent = Color3.fromRGB(243, 224, 182), Snack = "Berry", XP = 70,
		Hint = "Long ears peek over the willow roots when the evening turns lavender.", Weather = "Dusk", BaseChance = 0.60,
		Zone = "Pond", Description = "A silver-footed hare that follows the last light across the water.",
		RespawnSeconds = 110,
	},
	Mistfox = {
		Name = "Mistfox", Rarity = "Legendary", Color = Color3.fromRGB(205, 191, 217),
		Accent = Color3.fromRGB(234, 241, 227), Snack = "Berry", XP = 90,
		Hint = "Pale pawprints appear beyond the pond when fog settles.", Weather = "Fog", BaseChance = 0.48,
		Zone = "Pond", Description = "A shy woodland spirit that slips between ribbons of fog.",
		RespawnSeconds = 240,
	},
	Bloomstag = {
		Name = "Bloomstag", Rarity = "Legendary", Color = Color3.fromRGB(192, 148, 111),
		Accent = Color3.fromRGB(227, 169, 163), Snack = "Seed", XP = 100,
		Hint = "Flowering antlers sway on the far shore during a clear afternoon.", Weather = "Clear", BaseChance = 0.46,
		Zone = "Pond", Description = "A rare woodland guardian whose antlers bloom with tiny flowers.",
		RespawnSeconds = 300,
	},
}

Config.Raid = {
	StudioFree = true,
	-- Real paid raids are deliberately unavailable in this release. Setting an ID
	-- alone must never activate them: durable ownership and receipt recovery are required.
	ProductId = 0,
	ProductionEnabled = false,
	ChaseSeconds = 60,
	StealSeconds = 6,
	EscapeSeconds = 90,
	StealRange = 12,
	ExtractionRange = 14,
	AttemptCooldown = 12,
	NetHits = 3,
	NetRange = 12,
	NetCooldown = 1.5,
}

Config.Persistence = {
	StoreName = "WildboundProfiles_v1",
	EnableInStudio = false,
	LockSeconds = 180,
	SaveInterval = 60,
}

function Config.GetLevel(xp)
	return 1 + math.floor(math.max(0, xp) / Config.LevelXP)
end

function Config.CaptureChance(species, level)
	local creature = Config.Creatures[species]
	if not creature then return 0 end
	return math.clamp(creature.BaseChance + math.max(0, level - 1) * 0.025, 0.05, 0.95)
end

-- Resolve once when a wild creature spawns. Clients cannot choose or reroll it.
-- Fog brings more moonlit visitors; golden variants stay at one percent.
function Config.RollVariant(randomFloat, weather)
	local roll = if type(randomFloat) == "number" and randomFloat == randomFloat and math.abs(randomFloat) ~= math.huge
		then math.clamp(randomFloat, 0, 1) else 0
	local moonlitStart = if weather == "Fog" then 0.93 else 0.96
	if roll >= 0.99 then return "Golden" end
	if roll >= moonlitStart then return "Moonlit" end
	return "Normal"
end

function Config.RarityColor(rarity)
	local colors = {
		Common = Color3.fromRGB(71, 105, 56),
		Uncommon = Color3.fromRGB(54, 103, 117),
		Rare = Color3.fromRGB(97, 73, 151),
		Legendary = Color3.fromRGB(135, 91, 27),
	}
	return colors[rarity] or colors.Common
end

return Config
