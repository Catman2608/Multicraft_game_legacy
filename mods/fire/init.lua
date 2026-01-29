-- fire/init.lua

-- Global namespace for functions
fire = {}

-- Load support for MT game translation.
local S = MultiCraft.get_translator("fire")

-- 'Enable fire' setting
local fire_enabled = MultiCraft.settings:get_bool("enable_fire")
if fire_enabled == nil then
	-- enable_fire setting not specified, check for disable_fire
	local fire_disabled = MultiCraft.settings:get_bool("disable_fire")
	if fire_disabled == nil then
		-- Neither setting specified, check whether singleplayer
		fire_enabled = MultiCraft.is_singleplayer()
	else
		fire_enabled = not fire_disabled
	end
end

--
-- Items
--

-- Flood flame function
local function flood_flame(pos, _, newnode)
	-- Play flame extinguish sound if liquid is not an 'igniter'
	if MultiCraft.get_item_group(newnode.name, "igniter") == 0 then
		MultiCraft.sound_play("fire_extinguish_flame",
			{pos = pos, max_hear_distance = 16, gain = 0.15}, true)
	end
	-- Remove the flame
	return false
end

-- Flame nodes
local fire_node = {
	drawtype = "firelike",
	tiles = {{
		name = "fire_basic_flame_animated.png",
		animation = {
			type = "vertical_frames",
			aspect_w = 16,
			aspect_h = 16,
			length = 1
		}}
	},
	inventory_image = "fire_basic_flame.png",
	paramtype = "light",
	light_source = 13,
	walkable = false,
	buildable_to = true,
	sunlight_propagates = true,
	floodable = true,
	damage_per_second = 4,
	groups = {igniter = 2, dig_immediate = 3, fire = 1},
	drop = "",
	on_flood = flood_flame
}

-- Basic flame node
local flame_fire_node = table.copy(fire_node)
flame_fire_node.description = S("Fire")
flame_fire_node.groups.not_in_creative_inventory = 1
flame_fire_node.on_timer = function(pos)
	if not MultiCraft.find_node_near(pos, 1, {"group:flammable"}) then
		MultiCraft.remove_node(pos)
		return
	end
	-- Restart timer
	return true
end
flame_fire_node.on_construct = function(pos)
	MultiCraft.get_node_timer(pos):start(math.random(30, 60))
end

MultiCraft.register_node("fire:basic_flame", flame_fire_node)

-- Permanent flame node
local permanent_fire_node = table.copy(fire_node)
permanent_fire_node.description = S("Permanent Fire")

MultiCraft.register_node("fire:permanent_flame", permanent_fire_node)

-- Flint and Steel
MultiCraft.register_tool("fire:flint_and_steel", {
	description = S("Flint and Steel"),
	inventory_image = "fire_flint_steel.png",
	sound = {breaks = "default_tool_breaks"},

	on_use = function(itemstack, user, pointed_thing)
		local sound_pos = pointed_thing.above or user:get_pos()
		MultiCraft.sound_play("fire_flint_and_steel",
			{pos = sound_pos, gain = 0.5, max_hear_distance = 8}, true)
		local player_name = user:get_player_name()
		if pointed_thing.type == "node" then
			local node_under = MultiCraft.get_node(pointed_thing.under).name
			local nodedef = MultiCraft.registered_nodes[node_under]
			if not nodedef then
				return
			end
			if MultiCraft.is_protected(pointed_thing.under, player_name) then
				MultiCraft.chat_send_player(player_name, "This area is protected")
				return
			end
			if nodedef.on_ignite then
				nodedef.on_ignite(pointed_thing.under, user)
			elseif MultiCraft.get_item_group(node_under, "flammable") >= 1
					and MultiCraft.get_node(pointed_thing.above).name == "air" then
				MultiCraft.set_node(pointed_thing.above, {name = "fire:basic_flame"})
			end
		end
		if not MultiCraft.is_creative_enabled(player_name) then
			-- Wear tool
			local wdef = itemstack:get_definition()
			itemstack:add_wear(1000)

			-- Tool break sound
			if itemstack:get_count() == 0 and wdef.sound and wdef.sound.breaks then
				MultiCraft.sound_play(wdef.sound.breaks,
					{pos = sound_pos, gain = 0.5}, true)
			end
			return itemstack
		end
	end
})

MultiCraft.register_craft({
	output = "fire:flint_and_steel",
	recipe = {
		{"default:flint", "default:steel_ingot"}
	}
})

-- Override coalblock to enable permanent flame above
-- Coalblock is non-flammable to avoid unwanted basic_flame nodes
MultiCraft.override_item("default:coalblock", {
	after_destruct = function(pos)
		pos.y = pos.y + 1
		if MultiCraft.get_node(pos).name == "fire:permanent_flame" then
			MultiCraft.remove_node(pos)
		end
	end,
	on_ignite = function(pos)
		local flame_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
		if MultiCraft.get_node(flame_pos).name == "air" then
			MultiCraft.set_node(flame_pos, {name = "fire:permanent_flame"})
		end
	end
})


--
-- Sound
--

-- Enable if no setting present
local flame_sound = MultiCraft.settings:get_bool("flame_sound", true)

if flame_sound then
	local handles = {}
	local timer = 0

	-- Parameters
	local radius = 8 -- Flame node search radius around player
	local cycle = 3 -- Cycle time for sound updates

	-- Update sound for player
	function fire.update_player_sound(player)
		local player_name = player:get_player_name()
		-- Search for flame nodes in radius around player
		local ppos = player:get_pos()
		local areamin = vector.subtract(ppos, radius)
		local areamax = vector.add(ppos, radius)
		local fpos, num = MultiCraft.find_nodes_in_area(
			areamin,
			areamax,
			{"fire:basic_flame", "fire:permanent_flame"}
		)
		-- Total number of flames in radius
		local flames = (num["fire:basic_flame"] or 0) +
			(num["fire:permanent_flame"] or 0)
		-- Stop previous sound
		if handles[player_name] then
			MultiCraft.sound_stop(handles[player_name])
			handles[player_name] = nil
		end
		-- If flames
		if flames > 0 then
			-- Find centre of flame positions
			local fposmid = fpos[1]
			-- If more than 1 flame
			if #fpos > 1 then
				local fposmin = areamax
				local fposmax = areamin
				for i = 1, #fpos do
					local fposi = fpos[i]
					if fposi.x > fposmax.x then
						fposmax.x = fposi.x
					end
					if fposi.y > fposmax.y then
						fposmax.y = fposi.y
					end
					if fposi.z > fposmax.z then
						fposmax.z = fposi.z
					end
					if fposi.x < fposmin.x then
						fposmin.x = fposi.x
					end
					if fposi.y < fposmin.y then
						fposmin.y = fposi.y
					end
					if fposi.z < fposmin.z then
						fposmin.z = fposi.z
					end
				end
				fposmid = vector.divide(vector.add(fposmin, fposmax), 2)
			end
			-- Play sound
			local handle = MultiCraft.sound_play("fire_fire", {
				pos = fposmid,
				to_player = player_name,
				gain = math.min(0.06 * (1 + flames * 0.125), 0.18),
				max_hear_distance = 32,
				loop = true -- In case of lag
			})
			-- Store sound handle for this player
			if handle then
				handles[player_name] = handle
			end
		end
	end

	-- Cycle for updating players sounds
	MultiCraft.register_globalstep(function(dtime)
		timer = timer + dtime
		if timer < cycle then
			return
		end

		timer = 0
		local players = MultiCraft.get_connected_players()
		for n = 1, #players do
			fire.update_player_sound(players[n])
		end
	end)

	-- Stop sound and clear handle on player leave
	MultiCraft.register_on_leaveplayer(function(player)
		local player_name = player:get_player_name()
		if handles[player_name] then
			MultiCraft.sound_stop(handles[player_name])
			handles[player_name] = nil
		end
	end)
end


-- Deprecated function kept temporarily to avoid crashes if mod fire nodes call it
function fire.update_sounds_around() end

--
-- ABMs
--

if fire_enabled then
	-- Ignite neighboring nodes, add basic flames
	MultiCraft.register_abm({
		label = "Ignite flame",
		nodenames = {"group:flammable"},
		neighbors = {"group:igniter"},
		interval = 7,
		chance = 12,
		catch_up = false,
		action = function(pos)
			local p = MultiCraft.find_node_near(pos, 1, {"air"})
			if p then
				MultiCraft.set_node(p, {name = "fire:basic_flame"})
			end
		end
	})

	-- Remove flammable nodes around basic flame
	MultiCraft.register_abm({
		label = "Remove flammable nodes",
		nodenames = {"fire:basic_flame"},
		neighbors = "group:flammable",
		interval = 5,
		chance = 18,
		catch_up = false,
		action = function(pos)
			local p = MultiCraft.find_node_near(pos, 1, {"group:flammable"})
			if not p then
				return
			end
			local flammable_node = MultiCraft.get_node(p)
			local def = MultiCraft.registered_nodes[flammable_node.name]
			if def.on_burn then
				def.on_burn(p)
			else
				MultiCraft.remove_node(p)
				MultiCraft.check_for_falling(p)
			end
		end
	})
end
