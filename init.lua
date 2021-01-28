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
    end,

    get_inventory = function(player)
        return minetest.get_inventory({type = "detached", name = "terraform."..player:get_player_name()})
    end,

    -- Helpers for storing inventory into settings
    string_to_list = function(s,size)
        -- Accept: a comma-separated list of content names and desired list size
        -- Return: a table with item names, compatible with inventory lists
        local result = {}
        for part in s:gmatch("[^,]+") do
            table.insert(result, part)
        end
        while #result < size do table.insert(result, "") end
        minetest.chat_send_all("string_to_list "..s.." "..dump(result))
        return result
    end,
    list_to_string = function(list)
        -- Accept: result of InvRef:get_list
        -- Retrun: a comma-separated list of items
        local result = ""
        for k,v in pairs(list) do
            if v.get_name ~= nil then v = v:get_name() end -- ItemStack to string
            if v ~= "" then
                if string.len(result) > 0 then
                    result = result..","
                end
                result = result..v
            end
        end
        minetest.chat_send_all("list_to_string "..dump(list).." "..result)
        return result
    end
}

-- Handle input from forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if terraform._latest_form and formname == terraform._latest_form.id then
        local tool_name = terraform._latest_form.tool_name
        if not terraform._tools[tool_name].config_input then
            return
        end

        local itemstack = player:get_wielded_item()
        local reload = terraform._tools[tool_name]:config_input(player, fields, itemstack:get_meta())
        player:set_wielded_item(itemstack)

        if fields.quit then
            terraform._latest_form = nil
            return
        end

        if reload then
            terraform:show_config(player, tool_name, itemstack)
        end
    end
end)

-- Inventory
minetest.register_on_joinplayer(function(player)
    minetest.create_detached_inventory("terraform."..player:get_player_name(), {
        allow_move = function(a,b,c)
            minetest.chat_send_all("allow_move "..a.." "..b.." "..c)
            return 0
        end,
        allow_take = function(a,b,c)
            minetest.chat_send_all("allow_take "..a.." "..b.." "..c)
            return 0
        end,
        allow_put = function(a,b,c)
            minetest.chat_send_all("allow_put "..a.." "..b.." "..c)
            return 0
        end
    })
end)

minetest.register_on_leaveplayer(function(player)
    minetest.remove_detached_inventory("terraform."..player:get_player_name())
end)

-- Tools

-- Brush
--
terraform:register_tool("brush", {
    description = "Brush\n\nPaints the world with broad strokes",
    short_description = "Brush",
    inventory_image = "terraform_tool_brush.png",

    render_config = function(self, player, settings)
        local function selection(texture, selected)
            if selected then return texture.."^terraform_selection.png" end
            return texture
        end

        local inventory = minetest.create_detached_inventory("terraform."..player:get_player_name(), {
            allow_move = function(inv,source,sindex,dest,dindex,count)
                if source == "palette" and dest ~= "palette" then
                    inv:set_stack(dest,dindex, inv:get_stack(source, sindex))
                elseif dest == "palette" and source ~= "palette" then
                    inv:set_stack(source, sindex, "")
                end
                return 0
            end
        })

        local all_nodes = {}
        local count = 0
        local pattern = settings:get_string("search")
        for k,v in pairs(minetest.registered_nodes) do
            if not pattern or string.find(k, pattern) ~= nil then
                table.insert(all_nodes, k)
                count = count + 1
            end
        end
        while count < 40 do table.insert(all_nodes, "") count = count + 1 end

        local paint = terraform.string_to_list(settings:get_string("paint"), 10)
        local mask = terraform.string_to_list(settings:get_string("mask"), 10)

        inventory:set_list("palette", all_nodes)
        inventory:set_list("paint", paint)
        inventory:set_list("mask", mask)

        spec = 
            "formspec_version[3]"..
            "size[15,11]"..
            "position[0.1,0.15]"..
            "anchor[0,0]"..
            "no_prepend[]"..

            "container[0.5,0.5]".. -- shape
            "label[0.2,0.5; Shape:]"..
            "image_button[0,1;1,1;"..selection("terraform_brush_sphere.png",settings:get_string("brush") == "sphere")..";brush_sphere;]"..
            "image_button[1,1;1,1;"..selection("terraform_brush_cube.png", settings:get_string("brush") == "cube")..";brush_cube;]"..
            "container_end[]"..

            "container[0.5,3]".. -- size
            "field[0,0;2,1;size;Size;"..(settings:get_int("size") or 3).."]"..
            "field_close_on_enter[size;false]"..
            "container_end[]"..

            "container[4,0.5]".. -- creative
            "label[0,0.5; All items]"..
            "label[4,0.5; Search:]"..
            "field[5.5,0;2,1;search;;"..(settings:get_string("search") or "").."]"..
            "field_close_on_enter[search;false]"..
            "list[detached:terraform."..player:get_player_name()..";palette;0,1;10,3]"..
            "container_end[]"..

            "container[4,6]".. -- paint
            "label[0,0.5; Paint]"..
            "checkbox[4,0.5;air;Air;false]"..
            "list[detached:terraform."..player:get_player_name()..";paint;0,1;10,1]"..
            "container_end[]"..

            "container[4,8]".. -- Mask
            "label[0,0.5; Mask]"..
            "list[detached:terraform."..player:get_player_name()..";mask;0,1;10,1]"..
            "container_end[]"
        return spec
    end,

    config_input = function(self, player, fields, settings)
        minetest.chat_send_all("fields: "..dump(fields))
        local refresh = false
        if tonumber(fields.size) ~= nil then
            minetest.chat_send_all("input: "..fields.size)
            settings:set_int("size", math.min(math.max(tonumber(fields.size), 0), 10))
        end
        if fields.brush_sphere ~= nil then
            settings:set_string("brush", "sphere")
            refresh = true
        end
        if fields.brush_cube ~= nil then
            settings:set_string("brush", "cube")
            refresh = true
        end
        if fields.search ~= nil then
            settings:set_string("search", fields.search)
            refresh = true
        end
        local inv = terraform.get_inventory(player)
        if inv ~= nil then
            settings:set_string("paint", terraform.list_to_string(inv:get_list("paint")))
            settings:set_string("mask", terraform.list_to_string(inv:get_list("mask")))
        end

        return refresh
    end,

    execute = function(self, player, target, settings)
        -- Get position
        local target_pos = minetest.get_pointed_thing_position(target)
        if not target_pos then
            return
        end

        -- Define size in 3d
        local size = settings:get_int("size") or 3
        local size_3d = { x = size, y = size, z = size }

        -- Define working area and load state
        local minp = { x = target_pos.x - size_3d.x, y = target_pos.y - size_3d.y, z = target_pos.z - size_3d.z }
        local maxp = { x = target_pos.x + size_3d.x, y = target_pos.y + size_3d.y, z = target_pos.z + size_3d.z }
        local v = minetest.get_voxel_manip()
        local minv, maxv = v:read_from_map(minp, maxp)
        local a = VoxelArea:new({MinEdge = minv, MaxEdge = maxv })

        -- Get data and capture history
        local data  = v:get_data()
        history:capture(data, a, minp, maxp)

        -- Prepare Paint
        local paint = {}
        for i,v in ipairs(terraform.string_to_list(settings:get_string("paint"), 10)) do
            if v ~= "" then
                table.insert(paint, minetest.get_content_id(v))
            end
        end
        if #paint == 0 then
            table.insert(paint, minetest.CONTENT_AIR)
        end

        local function get_paint()
            return paint[math.random(1, #paint)]
        end

        -- Prepare Mask
        local mask = {}
        for i,v in ipairs(terraform.string_to_list(settings:get_string("mask"), 10)) do
            if v ~= "" then
                table.insert(mask, minetest.get_content_id(v))
            end
        end

        local function in_mask(cid)
            if #mask == 0 then return true end
            for i,v in ipairs(mask) do if v == cid then return true end end
            return false
        end

        local brushes = {
            cube = function()
                for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                    if in_mask(data[i]) then
                        data[i] = get_paint()
                    end
                end
            end,
            sphere = function()
                for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                    local ip = a:position(i)
                    local epsilon = 0.3
                    local delta = { x = ip.x - target_pos.x, y = ip.y - target_pos.y, z = ip.z - target_pos.z }
                    delta = { x = delta.x / (size_3d.x + epsilon), y = delta.y / (size_3d.y + epsilon), z = delta.z / (size_3d.z + epsilon) }
                    delta = { x = delta.x^2, y = delta.y^2, z = delta.z^2 }

                    if 1 > delta.x + delta.y + delta.z and in_mask(data[i]) then
                        data[i] = get_paint()
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
minetest.register_alias("terraform:sculptor", "terraform:brush")

terraform:register_tool("undo", {
    description = "Terraform Undo\n\nUndoes changes to the world",
    short_description = "Terraform Undo",
    inventory_image = "terraform_tool_undo.png",
    execute = function(itemstack, player, target)
        history:undo()
    end
})


