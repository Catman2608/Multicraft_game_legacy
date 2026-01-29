-- map/init.lua

-- Mod global namespace

map = {}


-- Load support for MT game translation.
local S = MultiCraft.get_translator("map")


-- Update HUD flags
-- Global to allow overriding

function map.update_hud_flags(player)
	local creative_enabled = MultiCraft.is_creative_enabled(player:get_player_name())

	local minimap_enabled = creative_enabled or
		player:get_inventory():contains_item("main", "map:mapping_kit")
	local radar_enabled = creative_enabled

	player:hud_set_flags({
		minimap = minimap_enabled,
		minimap_radar = radar_enabled
	})
end


-- Set HUD flags 'on joinplayer'

MultiCraft.register_on_joinplayer(function(player)
	map.update_hud_flags(player)
end)


-- Cyclic update of HUD flags

local function cyclic_update()
	for _, player in ipairs(MultiCraft.get_connected_players()) do
		map.update_hud_flags(player)
	end
	MultiCraft.after(5.3, cyclic_update)
end

MultiCraft.after(5.3, cyclic_update)


-- Mapping kit item

MultiCraft.register_craftitem("map:mapping_kit", {
	description = S("Mapping Kit") .. "\n" .. S("Use with 'Minimap' key"),
	inventory_image = "map_mapping_kit.png",
	stack_max = 1,
	groups = {flammable = 3, tool = 1},

	on_use = function(itemstack, user, pointed_thing)
		map.update_hud_flags(user)
	end,
})


-- Crafting

MultiCraft.register_craft({
	output = "map:mapping_kit",
	recipe = {
		{"default:glass", "default:paper", "group:stick"},
		{"default:steel_ingot", "default:paper", "default:steel_ingot"},
		{"group:wood", "default:paper", "dye:black"},
	}
})


-- Fuel

MultiCraft.register_craft({
	type = "fuel",
	recipe = "map:mapping_kit",
	burntime = 5,
})
