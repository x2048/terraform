-- In-memory history/undo engine
local history = {
    -- list of history entries
    _list = {},

    -- capture a cuboid in space using voxel manipulator
    capture = function(self, data, va, minp, maxp)
        local capture = {}
        for i in va:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
            table.insert(capture,data[i])
        end
        local op = {minp = minp, maxp = maxp, data = capture}
        table.insert(self._list, op)
        minetest.chat_send_all("captured " .. string.sub(dump(op), 1, 100))
    end,

    -- restore state of the world map from history
    undo = function(self)
        local op = table.remove(self._list)
        if not op then
            return
        end

        minetest.chat_send_all("undoing " .. string.sub(dump(op), 1, 100))
        local vm = minetest.get_voxel_manip()
        local minv,maxv = vm:read_from_map(op.minp, op.maxp)
        local va = VoxelArea:new({MinEdge = minv, MaxEdge = maxv})
        local si = 1
        local data = vm:get_data()
        for i in va:iter(op.minp.x, op.minp.y, op.minp.z, op.maxp.x, op.maxp.y, op.maxp.z) do
            data[i] = op.data[si]
            si = si + 1
        end
        vm:set_data(data)
        vm:write_to_map()
    end 
}

-- public module API
terraform = {
    _tools = {},
    _history = history,

    -- register a terraform tool
    register_tool = function(self, name, spec)
        spec.tool_name = name
        self._tools[spec.tool_name] = spec
        minetest.register_tool("terraform:"..spec.tool_name, {
            description = spec.description,
            short_description = spec.short_description,
            inventory_image = spec.inventory_image,
            full_punch_interval = 1.5,
            wield_scale = {x=1,y=1,z=1},
            stack_max = 1,
            range = spec.range or 128.0,
            liquids_pointable = true,
            node_dig_prediction = "",
            on_use = function(itemstack, player, target)
                terraform:show_config(player, spec.tool_name, itemstack)
            end,
            on_place = function(itemstack, player, target)
                spec:execute(player, target, itemstack:get_meta())
            end
        })
    end,

    -- show configuration form for the specific tool
    show_config = function(self, player, tool_name)
        minetest.chat_send_all("show_config "..tool_name)
        if not self._tools[tool_name].render_config then
            return
        end

        local itemstack = player:get_wielded_item()
        self._latest_form = { id = "terraform:props:"..tool_name, tool_name = tool_name}
        local formspec = self._tools[tool_name]:render_config(player, itemstack:get_meta())
        minetest.show_formspec(player:get_player_name(), terraform._latest_form.id, formspec)
    end
}

-- Handle input from forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if terraform._latest_form and formname == terraform._latest_form.id then
        if fields.quit then
            terraform._latest_form = nil
            return
        end
        local tool_name = terraform._latest_form.tool_name
        if not terraform._tools[tool_name].config_input then
            return
        end
        local itemstack = player:get_wielded_item()
        local reload = terraform._tools[tool_name]:config_input(player, fields, itemstack:get_meta())
        player:set_wielded_item(itemstack)
        if reload then
            terraform:show_config(player, tool_name, itemstack)
        end
    end
end)

--
terraform:register_tool("sculptor", {
    description = "Sculptor\n\nAdds or removes shapes to the world",
    short_description = "Sculptor",
    inventory_image = "terraform_tool_brush.png",
    render_config = function(self, player, settings)
        local function selection(texture, selected)
            if selected then return texture.."^terraform_selection.png" end
            return texture
        end

        spec = 
            "formspec_version[3]"..
            "size[13,9]"..
            "position[0.1,0.15]"..
            "anchor[0,0]"..
            "no_prepend[]"..

            "container[0,0]".. -- shape
            "label[0.2,0.5; Shape:]"..
            "image_button[0,1;1,1;"..selection("terraform_brush_sphere.png",settings:get_string("brush") == "sphere")..";brush_sphere;]"..
            "image_button[1,1;1,1;"..selection("terraform_brush_cube.png", settings:get_string("brush") == "cube")..";brush_cube;]"..
            "container_end[]"..

            "container[0,3]".. -- size
            "field[3,0;2,1;size;Size;"..(settings:get_int("size") or 3).."]"..
            "container_end[]"..
            "container[4,0]".. -- creative
            "label[0,0; All items]"..
            "list[current_player;creative;0,1;9,4]"..
            "container_end[]"..
            "container[4,5]".. -- material
            "label[0,0; Materials]"..
            "checkbox[4,0;air;Air;false]"..
            "list[current_player;main;0,1;10,1]"..
            "container_end[]"..
            "container[4,7]".. -- Mask
            "label[0,0; Mask]"..
            "list[current_player;main;0,1;10,1]"..
            "container_end[]"
        return spec
    end,
    config_input = function(self, player, fields, settings)
        minetest.chat_send_all("fields: "..dump(fields))
        local refresh = false
        if fields.size ~= nil then
            minetest.chat_send_all("input: "..fields.size)
            settings:set_int("size", tonumber(fields.size))
        end
        if fields.brush_sphere ~= nil then
            settings:set_string("brush", "sphere")
            refresh = true
        end
        if fields.brush_cube ~= nil then
            settings:set_string("brush", "cube")
            refresh = true
        end
        return refresh
    end,
    execute = function(self, player, target, settings)
        local target_pos = minetest.get_pointed_thing_position(target)
        if not target_pos then
            return
        end

        local size = settings:get_int("size") or 3
        local size_3d = { x = size, y = size, z = size }
        local minp = { x = target_pos.x - size_3d.x, y = target_pos.y - size_3d.y, z = target_pos.z - size_3d.z }
        local maxp = { x = target_pos.x + size_3d.x, y = target_pos.y + size_3d.y, z = target_pos.z + size_3d.z }
        local v = minetest.get_voxel_manip()
        local minv, maxv = v:read_from_map(minp, maxp)
        local a = VoxelArea:new({MinEdge = minv, MaxEdge = maxv })
        local data  = v:get_data()
        history:capture(data, a, minp, maxp)
        local cid = {
            air = minetest.CONTENT_AIR,
            solid = data[a:index(target_pos.x, target_pos.y, target_pos.z)]
        }

        local brushes = {
            cube = function()
                for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                    data[i] = cid.solid
                end
            end,
            sphere = function()
                for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                    local ip = a:position(i)
                    local epsilon = 0.3
                    local delta = { x = ip.x - target_pos.x, y = ip.y - target_pos.y, z = ip.z - target_pos.z }
                    delta = { x = delta.x / (size_3d.x + epsilon), y = delta.y / (size_3d.y + epsilon), z = delta.z / (size_3d.z + epsilon) }
                    delta = { x = delta.x^2, y = delta.y^2, z = delta.z^2 }

                    if 1 > delta.x + delta.y + delta.z and data[i] == cid.air then
                        data[i] = cid.solid
                    end
                end
            end,
        }

        local brush = settings:get_string("brush") or "sphere"
        if not brushes[brush] then brush = "sphere" end

        brushes[brush]()

        v:set_data(data)
        v:write_to_map()
    end
})

terraform:register_tool("undo", {
    description = "Terraform Undo\n\nUndoes changes to the world",
    short_description = "Terraform Undo",
    inventory_image = "terraform_tool_undo.png",
    execute = function(itemstack, player, target)
        history:undo()
    end
})


