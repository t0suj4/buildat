-- Buildat: minigame/client_lua/init.lua
-- http://www.apache.org/licenses/LICENSE-2.0
-- Copyright 2014 Perttu Ahola <celeron55@gmail.com>
-- Copyright 2014 Břetislav Štec <valsiterb@gmail.com>
local log = buildat.Logger("minigame")
local dump = buildat.dump
local cereal = require("buildat/extension/cereal")
local magic = require("buildat/extension/urho3d")
log:info("minigame/init.lua loaded")

-- 3D things

-- NOTE: Create global variable so that it doesn't get automatically deleted
scene = magic.Scene()
scene:CreateComponent("Octree")

-- Note that naming the scene nodes is optional
local plane_node = scene:CreateChild("Plane")
plane_node.scale = magic.Vector3(10.0, 1.0, 10.0)
local plane_object = plane_node:CreateComponent("StaticModel")
plane_object.model = magic.cache:GetResource("Model", "Models/Plane.mdl")
plane_object.material = magic.cache:GetResource("Material", "Materials/Stone.xml")
plane_object.material:SetTexture(magic.TU_DIFFUSE,
		magic.cache:GetResource("Texture2D", "minigame/green_texture.png"))

local light_node = scene:CreateChild("DirectionalLight")
light_node.direction = magic.Vector3(-0.6, -1.0, 0.8) -- The direction vector does not need to be normalized
local light = light_node:CreateComponent("Light")
light.lightType = magic.LIGHT_DIRECTIONAL
light.castShadows = true
light.shadowBias = magic.BiasParameters(0.00025, 0.5)
light.shadowCascade = magic.CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
light.brightness = 0.8

light_node = scene:CreateChild("DirectionalLight")
light_node.direction = magic.Vector3(0.6, -1.0, -0.8) -- The direction vector does not need to be normalized
light = light_node:CreateComponent("Light")
light.lightType = magic.LIGHT_DIRECTIONAL
light.brightness = 0.2

-- Add a camera so we can look at the scene
local camera_node = scene:CreateChild("Camera")
camera_node:CreateComponent("Camera")
camera_node.position = magic.Vector3(7.0, 7.0, 7.0)
--camera_node.rotation = Quaternion(0, 0, 0.0)
camera_node:LookAt(magic.Vector3(0, 1, 0))
-- And this thing so the camera is shown on the screen
local viewport = magic.Viewport:new(scene, camera_node:GetComponent("Camera"))
magic.renderer:SetViewport(0, viewport)

-- Add some text
local title_text = magic.ui.root:CreateChild("Text")
title_text:SetText("minigame/init.lua")
title_text:SetFont(magic.cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 15)
title_text.horizontalAlignment = magic.HA_CENTER
title_text.verticalAlignment = magic.VA_CENTER
title_text:SetPosition(0, magic.ui.root.height*(-0.33))

magic.ui:SetFocusElement(nil)

local field = {}
local players = {}
local player_boxes = {}
local field_boxes = {}

-- Create some containers for objects
local field_node = scene:CreateChild("Field")
local players_node = scene:CreateChild("Players")

function inside_field(x, y, w, h)
	if x >= w or x < 0 then
		return false
	end
	if y >= h or y < 0 then
		return false
	end
	return true
end

buildat.sub_packet("minigame:update", function(data)
	log:info("data="..buildat.dump(buildat.bytes(data)))
	local values = cereal.binary_input(data, {"object",
		{"peer", "int32_t"},
		{"players", {"unordered_map",
			"int32_t",
			{"object",
				{"peer", "int32_t"},
				{"x", "int32_t"},
				{"y", "int32_t"},
			},
		}},
		{"playfield", {"object",
			{"w", "int32_t"},
			{"h", "int32_t"},
			{"tiles", {"array", "int32_t"}},
		}},
	})
	--log:info("values="..dump(values))

	field = values.playfield

	for y=1,field.h do
		for x=1,field.w do
			local pos = (y-1)*field.w + (x-1) + 1
			local v = field.tiles[pos]
			if v ~= 0 then
				if field_boxes[pos] == nil then
					local box = field_node:CreateChild("")
					local object = box:CreateComponent("StaticModel")

					object.model = magic.cache:GetResource("Model",
						"Models/Box.mdl")
					assert(object.model)

					object.material = magic.Material:new()

					object.material:SetTechnique(0,
					magic.cache:GetResource("Technique", "Techniques/Diff.xml"))

					object.material:SetTexture(magic.TU_DIFFUSE,
					magic.cache:GetResource("Texture2D", "minigame/green_texture.png"))
					object.castShadows = true

					field_boxes[pos] = box
				end
				field_boxes[pos].position = magic.Vector3(x-6, v*0.25, y-6)
				field_boxes[pos].scale    = magic.Vector3(1.0, v*0.5, 1.0)
			else
				-- if v is 0, we have to remove the field box
				if field_boxes[pos] then
					field_boxes[pos] = nil
				end
			end
		end
	end

	local player_map = values.players
	local old_players = players
	players = {}
	for k, player in pairs(player_map) do
		table.insert(players, player)
	end
	log:info("players="..dump(players))

	for _, player in ipairs(players) do
		local is_new = true
		for _, old_player in ipairs(old_players) do
			if old_player.peer == player.peer then
				is_new = false
				break
			end
		end
		if is_new then

			-- New boxes for new players
			local box = players_node:CreateChild("")

			box.scale = magic.Vector3(0.9, 0.9, 0.9)

			-- Let's make them their brand new and very original body
			local object = box:CreateComponent("StaticModel")
			object.model = magic.cache:GetResource("Model", "Models/Box.mdl")
			assert(object.model)

			object.material = magic.Material:new()

			-- We use this Diff.xml file to define that we want diffuse
			-- rendering. It doesn't make much sense to define it ourselves
			-- as it consists of quite many paremeters:
			object.material:SetTechnique(0,
			magic.cache:GetResource("Technique", "Techniques/Diff.xml"))

			-- And load the texture from a file:
			object.material:SetTexture(magic.TU_DIFFUSE,
			magic.cache:GetResource("Texture2D", "minigame/pink_texture.png"))
			object.castShadows = true

			player_boxes[player.peer] = box
		end
		local v = 0
		-- Stand on top of boxes that are INISDE the playfield
		if inside_field(player.x, player.y, field.w, field.h) then
			v = field.tiles[(player.y)*field.w + (player.x) + 1]
		end
		player_boxes[player.peer].position = 
			magic.Vector3(player.x-5, 0.45+v*0.5, player.y-5) or nil
	end
	for _, old_player in ipairs(old_players) do
		local was_removed = true
		for _, player in ipairs(players) do
			if player.peer == old_player.peer then
				was_removed = false
				break
			end
		end
		if was_removed then
			players_node:RemoveChild(player_boxes[old_player.peer])
		end
	end
end)

function handle_keydown(event_type, event_data)
	local key = event_data:GetInt("Key")
	if key == magic.KEY_ESC then
		log:info("KEY_ESC pressed")
		buildat.disconnect()
	end

	if key == magic.KEY_UP then
		buildat.send_packet("minigame:move", "up")
	end
	if key == magic.KEY_DOWN then
		buildat.send_packet("minigame:move", "down")
	end
	if key == magic.KEY_LEFT then
		buildat.send_packet("minigame:move", "left")
	end
	if key == magic.KEY_RIGHT then
		buildat.send_packet("minigame:move", "right")
	end
	if key == magic.KEY_SPACE then
		buildat.send_packet("minigame:move", "place")
	end
	--if key == magic.GetScancodeFromName("c") then
	--	buildat.send_packet("minigame:clear")
	--end
end
magic.SubscribeToEvent("KeyDown", "handle_keydown")

-- vim: set noet ts=4 sw=4:
