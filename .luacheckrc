unused_args = false
allow_defined_top = true

read_globals = {
	"DIR_DELIM",
	"MultiCraft",
	"dump",
	"vector",
	"VoxelManip", "VoxelArea",
	"PseudoRandom", "PcgRandom",
	"ItemStack",
	"Settings",
	"unpack",
	-- Silence errors about custom table methods.
	table = { fields = { "copy", "indexof" } },
	-- Silence warnings about accessing undefined fields of global 'math'
	math = { fields = { "sign" } }
}

-- Overwrites MultiCraft.handle_node_drops
files["mods/creative/init.lua"].globals = { "MultiCraft" }

-- Overwrites MultiCraft.calculate_knockback
files["mods/player_api/api.lua"].globals = { "MultiCraft" }

-- Don't report on legacy definitions of globals.
files["mods/default/legacy.lua"].global = false
