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
    end,

    -- restore state of the world map from history
    undo = function(self)
        local op = table.remove(self._list)
        if not op then
            return
        end

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
        return result
    end
}

-- Handle input from forms
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if terraform._latest_form and formname == terraform._latest_form.id then
        local tool_name = terraform._latest_form.tool_name
        local tool = terraform._tools[tool_name]
        if not tool.config_input then
            return
        end

        local itemstack = player:get_wielded_item()
        local reload = tool:config_input(player, fields, itemstack:get_meta())

        -- update tool description in the inventory
        if tool.get_description then
            itemstack:get_meta():set_string("description", tool:get_description(itemstack:get_meta()))
        end

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

    -- 16 logical tag colors
    colors = { "red", "yellow", "lime", "aqua", 
               "darkred", "orange", "darkgreen", "mediumblue",
               "violet", "wheat", "olive", "dodgerblue" },

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
            "size[17,12]"..
            "position[0.5,0.45]"..
            "anchor[0.5,0.5]"..
            "no_prepend[]"..

            "button_exit[14.5,10.5;2,1;quit;Close]".. -- Close button !Remember to offset when form size changes

            "container[0.5,0.5]".. -- shape
            "label[0,0.5; Shape:]"..
            "image_button[0,1;1,1;"..selection("terraform_shape_sphere.png",settings:get_string("shape") == "sphere")..";shape_sphere;]"..
            "image_button[1,1;1,1;"..selection("terraform_shape_cube.png", settings:get_string("shape") == "cube")..";shape_cube;]"..
            "image_button[2,1;1,1;"..selection("terraform_shape_cylinder.png", settings:get_string("shape") == "cylinder")..";shape_cylinder;]"..
            "image_button[0,2;1,1;"..selection("terraform_shape_plateau.png",settings:get_string("shape") == "plateau")..";shape_plateau;]"..
            "image_button[1,2;1,1;"..selection("terraform_shape_smooth.png",settings:get_string("shape") == "smooth")..";shape_smooth;]"..
            "container_end[]"..

            "container[0.5,4]".. -- size
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
            "list[detached:terraform."..player:get_player_name()..";paint;0,1;10,1]"..
            "container_end[]"..

            "container[4,8]".. -- Mask
            "label[0,0.5; Mask]"..
            "list[detached:terraform."..player:get_player_name()..";mask;0,1;10,1]"..
            "container_end[]"

        -- Color tags
        spec = spec..
            "container[0.5, 6]"..
            "label[0,0.5; Color Tag]"
        local count = 0
        local size = 0.5
        for _, color in ipairs(self.colors) do 
            local offset = size*(count % 4)
            local line = 0.75 + size*math.floor(count / 4)
            local texture = "terraform_tool_brush.png^[multiply:"..color..""
            spec = spec..
            "image_button["..offset..","..line..";"..size..","..size..";"..selection(texture,settings:get_string("color") == color)..";color_"..color..";]"

            count = count + 1
        end

        spec = spec..
            "container_end[]"..
            ""

        return spec
    end,

    config_input = function(self, player, fields, settings)
        local refresh = false
        if tonumber(fields.size) ~= nil then
            settings:set_int("size", math.min(math.max(tonumber(fields.size), 0), 10))
        end
        if fields.shape_sphere ~= nil then
            settings:set_string("shape", "sphere")
            refresh = true
        end
        if fields.shape_cube ~= nil then
            settings:set_string("shape", "cube")
            refresh = true
        end
        if fields.shape_plateau ~= nil then
            settings:set_string("shape", "plateau")
            refresh = true
        end
        if fields.shape_cylinder ~= nil then
            settings:set_string("shape", "cylinder")
            refresh = true
        end
        if fields.shape_smooth ~= nil then
            settings:set_string("shape", "smooth")
            refresh = true
        end
        if fields.search ~= nil then
            settings:set_string("search", fields.search)
            refresh = true
        end
        for _,color in ipairs(self.colors) do
            if fields["color_"..color] then
                settings:set_string("color", color)
                refresh = true
            end
        end

        local inv = terraform.get_inventory(player)
        if inv ~= nil then
            settings:set_string("paint", terraform.list_to_string(inv:get_list("paint")))
            settings:set_string("mask", terraform.list_to_string(inv:get_list("mask")))
        end

        return refresh
    end,

    get_description = function(self, settings)
        return "Terraform Brush ("..(settings:get_string("shape") or "shpere")..")\n"..
            "size "..(settings:get_int("size") or 0).."\n"..
            "paint "..(settings:get_string("paint")).."\n"..
            "mask "..(settings:get_string("mask"))
    end,

    execute = function(self, player, target, settings)

        -- Get position
        local target_pos = minetest.get_pointed_thing_position(target)
        if not target_pos then
            return
        end

        -- Define size in 3d
        local size = settings:get_int("size") or 3
        local size_3d = vector.new(size, size, size)

        -- Pick a shape
        local shape_name = settings:get_string("shape") or "sphere"
        if not self.shapes[shape_name] then shape_name = "sphere" end
        local shape = self.shapes[shape_name]()

        -- Define working area and load state
        local minp,maxp = shape:get_bounds(player, target_pos, size_3d)
        local v = minetest.get_voxel_manip()
        local minv, maxv = v:read_from_map(minp, maxp)
        local a = VoxelArea:new({MinEdge = minv, MaxEdge = maxv })

        -- Get data and capture history
        local data  = v:get_data()
        history:capture(data, a, minp, maxp)

        -- Set up context
        local ctx = {
            size_3d = size_3d,
            player = player
        }

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

        ctx.get_paint = function()
            return paint[math.random(1, #paint)]
        end

        -- Prepare Mask
        local mask = {}
        for i,v in ipairs(terraform.string_to_list(settings:get_string("mask"), 10)) do
            if v ~= "" then
                table.insert(mask, minetest.get_content_id(v))
            end
        end

        ctx.in_mask = function(cid)
            if #mask == 0 then return true end
            for i,v in ipairs(mask) do if v == cid then return true end end
            return false
        end

        -- Paint
        shape:paint(data, a, target_pos, minp, maxp, ctx)

        -- Save back to map
        v:set_data(data)
        v:write_to_map()
    end,


    -- Definition of shapes
    shapes = {
        cube = function()
            return {
                get_bounds = function(self, player, target_pos, size_3d)
                    if player:get_pos().y > target_pos.y then
                        -- place on top if looking down
                        return vector.subtract(target_pos, vector.new(size_3d.x, 0, size_3d.z)), vector.add(target_pos, vector.new(size_3d.x, 2*size_3d.y, size_3d.z))
                    else
                        -- place on bottom if looking up
                        return vector.subtract(target_pos, vector.new(size_3d.x, 2*size_3d.y, size_3d.z)), vector.add(target_pos, vector.new(size_3d.x, 0, size_3d.z))
                    end
                end,
                paint = function(self, data, a, target_pos, minp, maxp, ctx)
                    for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                        if ctx.in_mask(data[i]) then
                            data[i] = ctx.get_paint()
                        end
                    end
                end,
            }
        end,
        sphere = function()
            return {
                get_bounds = function(self, player, target_pos, size_3d)
                    return vector.subtract(target_pos, size_3d), vector.add(target_pos, size_3d)
                end,
                paint = function(self, data, a, target_pos, minp, maxp, ctx)
                    for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                        local ip = a:position(i)
                        local epsilon = 0.3
                        local delta = { x = ip.x - target_pos.x, y = ip.y - target_pos.y, z = ip.z - target_pos.z }
                        delta = { x = delta.x / (ctx.size_3d.x + epsilon), y = delta.y / (ctx.size_3d.y + epsilon), z = delta.z / (ctx.size_3d.z + epsilon) }
                        delta = { x = delta.x^2, y = delta.y^2, z = delta.z^2 }

                        if 1 > delta.x + delta.y + delta.z and ctx.in_mask(data[i]) then
                            data[i] = ctx.get_paint()
                        end
                    end
                end,
            }
        end,
        cylinder = function()
            return {
                get_bounds = function(self, player, target_pos, size_3d)
                    if player:get_pos().y > target_pos.y then
                        -- place on top if looking down
                        return vector.subtract(target_pos, vector.new(size_3d.x, 0, size_3d.z)), vector.add(target_pos, vector.new(size_3d.x, size_3d.y, size_3d.z))
                    else
                        -- place on bottom if looking up
                        return vector.subtract(target_pos, vector.new(size_3d.x, size_3d.y, size_3d.z)), vector.add(target_pos, vector.new(size_3d.x, 0, size_3d.z))
                    end
                end,
                paint = function(self, data, a, target_pos, minp, maxp, ctx)
                    for i in a:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
                        local ip = a:position(i)
                        local epsilon = 0.3
                        local delta = { x = ip.x - target_pos.x, z = ip.z - target_pos.z }
                        delta = { x = delta.x / (ctx.size_3d.x + epsilon), z = delta.z / (ctx.size_3d.z + epsilon) }
                        delta = { x = delta.x^2, z = delta.z^2 }

                        if 1 > delta.x + delta.z and ctx.in_mask(data[i]) then
                            data[i] = ctx.get_paint()
                        end
                    end
                end,
            }
        end,
        plateau = function()
            return {
                get_bounds = function(self, player, target_pos, size_3d)
                    local flat_size = vector.new(size_3d.x, 0, size_3d.z)
                    local minp = vector.subtract(target_pos, size_3d)
                    local maxp = vector.add(target_pos, size_3d)
                    minp.y = target_pos.y - 100 -- look up to 100 meters down
                    return minp, maxp
                end,
                paint = function(self, data, a, target_pos, minp, maxp, ctx)

                    local origin = a:indexp(target_pos)

                    -- find deepest level (as negative)
                    local depth = 0
                    for x = -ctx.size_3d.x,ctx.size_3d.x do
                        for z = -ctx.size_3d.z,ctx.size_3d.z do
                            -- look in the circle around origin
                            local r = (x/(ctx.size_3d.x+0.3))^2 + (z/(ctx.size_3d.z+0.3))^2
                            if r < 1 then
                                -- scan 100 levels down
                                for y = 0,-100,-1 do
                                    -- stop if the bottom is hit
                                    local p = origin + x + y * a.ystride + z * a.zstride
                                    if data[p] ~= minetest.CONTENT_AIR then
                                        if y < depth then depth = y end
                                        break
                                    end
                                end
                            end
                        end
                    end

                    -- fill
                    for x = -ctx.size_3d.x,ctx.size_3d.x do
                        for z = -ctx.size_3d.z,ctx.size_3d.z do
                            -- look in the circle around origin
                            local r = (x/(ctx.size_3d.x+0.3))^2 + (z/(ctx.size_3d.z+0.3))^2
                            if r < 1 then
                                -- fill with material down from cut off point to depth
                                local cutoff = math.min(0, math.floor(depth * math.sin((r - 0.3) * math.pi / 2)))
                                for y = cutoff,depth,-1 do
                                    i = origin + x + y * a.ystride + z * a.zstride

                                    if ctx.in_mask(data[i]) then
                                        data[i] = ctx.get_paint()
                                    end
                                end
                            end
                        end
                    end
                end
            }
        end,
        smooth = function()
            return {
                get_bounds = function(self, player, target_pos, size_3d)
                    return vector.subtract(target_pos, size_3d), vector.add(target_pos, size_3d)
                end,
                paint = function(self, data, a, target_pos, minp, maxp, ctx)
                    local origin = a:indexp(target_pos)
                    local b  = {}

                    local function get_weight(i)
                        local weight = 0

                        for lx = -1,1 do
                            for ly = -1,1 do
                                for lz = -1,1 do
                                    if data[i + lx + a.ystride*ly + a.zstride*lz] ~= minetest.CONTENT_AIR then
                                        weight = weight + (1 / math.max(1, math.abs(lx) + math.abs(ly) + math.abs(lz)))
                                    end
                                end
                            end
                        end
                        return weight
                    end

                    -- Spherical shape
                    -- Reduce all bounds by 1 to avoid edge glitches when looking for neighbours
                    for x = -ctx.size_3d.x+1,ctx.size_3d.x-1 do
                        for y = -ctx.size_3d.y+1,ctx.size_3d.y-1 do
                            for z = -ctx.size_3d.z+1,ctx.size_3d.z-1 do
                                local r = (x/ctx.size_3d.x)^2 + (y/ctx.size_3d.y)^2 + (z/ctx.size_3d.z)^2
                                if r <= 1 then
                                    local i = origin + x + a.ystride*y + a.zstride*z
                                    b[i] = get_weight(i) > 7.8  --max weight here is 15.6
                                end
                            end
                        end
                    end

                    for i,v in pairs(b) do
                        if v then
                            if ctx.in_mask(data[i]) then
                                data[i] = ctx.get_paint()
                            end
                        else
                            data[i] = minetest.CONTENT_AIR
                        end
                    end
                end,
            }
        end,
    }
})
minetest.register_alias("terraform:sculptor", "terraform:brush")

-- Colorize brush when putting to inventory
minetest.register_on_player_inventory_action(function(player,action,inventory,inventory_info)
    if inventory_info.listname ~= "main" or inventory_info.stack:get_name() ~= "terraform:brush" then
        return
    end
    local stack = inventory_info.stack
    if (stack:get_meta():get_string("color") or "") == "" then
        local colors = terraform._tools["brush"].colors
        local color = colors[math.random(1,#colors)]
        stack:get_meta():set_string("color", color)
        inventory:set_stack(inventory_info.listname, inventory_info.index, stack)
    end
end)

terraform:register_tool("undo", {
    description = "Terraform Undo\n\nUndoes changes to the world",
    short_description = "Terraform Undo",
    inventory_image = "terraform_tool_undo.png",
    execute = function(itemstack, player, target)
        history:undo()
    end
})


