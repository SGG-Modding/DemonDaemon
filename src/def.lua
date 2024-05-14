---@meta SGG_Modding-DemonDaemon
local daemon = {}

--[[
          Handles enacting the `modfile.txt` at the gtiven path on behalf of the given plugin
--]]
---@param env table plugin environment
---@param path string path to `modfile.txt` relative to the plugin's mod folder
---@param state table? internal state, useful for parsing sub-modfiles
function daemon.parse(env,path,state) end

--[[
          Automatically handles enacting *your plugin's* `modfile.txt`
    
    Usage:
        auto()
--]]
function daemon.auto() end

return daemon