---@meta _
---@diagnostic disable

---@module 'SGG_Modding-ENVY'
local envy = rom.mods['SGG_Modding-ENVY']
---@module 'SGG_Modding-ENVY-auto'
envy.auto()

---@module 'SGG_Modding-ReLoad'
local reload = rom.mods['SGG_Modding-ReLoad']
local loader = reload.auto()

---@module 'SGG_Modding-Chalk'
local chalk = rom.mods['SGG_Modding-Chalk']
---@module 'SGG_Modding-SJSON'
local sjson = rom.mods['SGG_Modding-SJSON']
private.sjson = sjson

-- read this to know what to import
local modfile_name = 'modfile.txt'

-- special names
local register_lua = 'register.lua'
local config_lua = 'config.lua'
local config_toml = 'config.toml'

local arg_pattern = '["%\']*([_%.%w\\/]+)["%\']*$'
local arg_pattern_target_scripts = '["%\']*Scripts[\\/]([_%.%w\\/]+)["%\']*$'
local arg_pattern_target_game = '["%\']*Game[\\/]([_%.%w\\/]+)["%\']*$'
local start_pattern = '^[%s]*'
local command_target_scripts = start_pattern .. 'To ' .. arg_pattern_target_scripts
local command_target_game = start_pattern .. 'To ' .. arg_pattern_target_game
local command_include = start_pattern .. 'Include ' .. arg_pattern
local command_import_pre = start_pattern .. 'Top Import ' .. arg_pattern
local command_import_post = start_pattern .. 'Import ' .. arg_pattern
local command_sjson = start_pattern .. 'SJSON ' .. arg_pattern

local function script_import(env,stub)
	local globals = rom.game
	local modutil = rom.mods['SGG_Modding-ModUtil']
	if modutil then
		globals = modutil.globals or globals
	end
	if stub == config_lua then
		local default = envy.import(env,stub,globals)
		rom.path.create_directory(env._PLUGIN.config_mod_folder_path)
		local toml = rom.path.combine(env._PLUGIN.config_mod_folder_path,config_toml)
		local config = chalk.config.save_if_new_else_load_and_merge(toml,default)
		env.config = config
		if env.mod then
			env.mod.Config = config
		end
		return config
	end
	if stub == register_lua then
		local mod = envy.import(env,stub,globals) 
		env.mod = mod
		mod.Plugin = env
		return mod
	end
	return envy.import(env,stub,rom.game)
end

local sjson_merge = import 'sjson.lua'

local function debug_dump(data)
	local folder = _PLUGIN.plugins_data_mod_folder_path
	rom.path.create_directory(folder)
	sjson.encode_file(rom.path.combine(folder,'latest.sjson'),data)
	sjson.encode_file(rom.path.combine(folder,'latest_indent.sjson'),data,{indent=true})
	sjson.encode_file(rom.path.combine(folder,'latest_pretty.sjson'),data,{pretty=true})
end

local function parse_modfile(env,file_path,state)
	state = state or {}
	state.target_scripts = state.target_scripts or 'RoomLogic.lua'
	local file = io.open(file_path,'r')
	for line in file:lines() do
		local i, ts, tg, b, a, s = 
			select(3,line:find(command_include)),
			select(3,line:find(command_target_scripts)),
			select(3,line:find(command_target_game)),
			select(3,line:find(command_import_pre)),
			select(3,line:find(command_import_post)),
			select(3,line:find(command_sjson))
		if i then
			local parent = rom.path.get_parent(file_path)
			parse_modfile(env, rom.path.combine(parent, i), state)
		elseif ts then
			state.target_scripts = ts
		elseif tg then
			state.target_game = tg
		elseif b then
			local first = true
			loader.queue.pre_import_file(state.target_scripts, function()
				if first then
					first = false
					script_import(env, b)
				end
			end)
		elseif a then
			local first = true
			loader.queue.post_import_file(state.target_scripts, function()
				if first then
					first = false
					script_import(env, a)
				end
			end)
		elseif s then
			local first = true
			local parent = rom.path.get_parent(file_path)
			local merge = sjson.decode_file(rom.path.combine(parent, s))
			local path = sjson.get_game_data_path(state.target_game)
			sjson.hook(path, function(data)
				data = sjson_merge(data, merge)
				debug_dump(data)
				return data
			end)
		end
	end
	file:close()
end

public.parse = parse_modfile
function public.auto()
	local env = envy.getfenv(2)
	local path = rom.path.combine(env._PLUGIN.plugins_mod_folder_path, modfile_name)
	return parse_modfile(env, path)
end
