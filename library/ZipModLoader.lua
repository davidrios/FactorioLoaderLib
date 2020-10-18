local ZipModLoader = {}
ZipModLoader.__index = ZipModLoader

local directory_stack = {}

function ZipModLoader.new(dirname, mod_name, arc_subfolder, base_name, dep_modules)
    local filename = dirname .. mod_name .. ".zip"
    local arc = assert(zip.open(filename))

    local mod = {
        mod_name = mod_name .. "/",
        archive = arc,
        archive_name = filename,
        arc_subfolder = arc_subfolder,
        base_name = base_name,
        dep_modules = dep_modules
    }

    return setmetatable(mod, ZipModLoader)
end

function ZipModLoader:__call(orig_name)
    orig_name = orig_name:gsub("//", "/")
    local name = orig_name:gsub("%.", "/")

    local potential_files = {
        self.arc_subfolder .. name:gsub("__" .. self.base_name .. "__/", "") .. ".lua",
        self.arc_subfolder .. orig_name:gsub("__" .. self.base_name .. "__/", "") .. ".lua",
    }

    if #directory_stack ~= 0 then
        table.insert(potential_files, directory_stack[#directory_stack] .. name .. ".lua")
    end

    local file = nil
    local filename = nil
    for _, f in ipairs(potential_files) do
        file = self.archive:open(f)
        if file then
            filename = f
            break
        end
    end

    if not file then
        local pos = name:find("/")
        local first_path = name:sub(0, pos - 1)
        if first_path:sub(0, 2) == "__" then
            first_path = first_path:gsub("__", "")

            local dependency = self.dep_modules[first_path]
            if dependency ~= nil then
                if dependency.localPath ~= nil then
                    return function()
                        local old_path = package.path
                        package.path = dependency.localPath .. "/?.lua;" .. package.path
                        local result = require(name:sub(pos + 1, -1))
                        package.path = old_path
                        return result
                    end
                else
                    error('Implement loading of zipped')
                end
            end
        end

        return "Not found: " .. name .. " in " .. self.archive_name
    end

    local content = file:read("*a")
    file:close()
    local loaded_chunk = load(content, filename)
    return function()
        table.insert(directory_stack, filename:sub(1, filename:find("/[^/]*$")))
        local result = loaded_chunk()
        table.remove(directory_stack)
        return result
    end
end

function ZipModLoader:close()
    self.archive:close()
end

return ZipModLoader
