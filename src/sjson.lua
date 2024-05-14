---@meta _
---@diagnostic disable
-- ported modimporter code for merging SJSON

local type,pairs,ipairs,tonumber,unpack,insert,remove,getmetatable,setmetatable
	= type,pairs,ipairs,tonumber,table.unpack,table.insert,table.remove,getmetatable,setmetatable

local _isarray = private.sjson.is_array
local _joinorder = private.sjson.join_order

local _ENV = nil

local _reserved_sequence = "_sequence"
local _reserved_append = "_append"
local _reserved_replace = "_replace"
local _reserved_delete = "_delete"
local _reserved_search = "_search"

local function _iter(data)
	if _isarray(data) then
		return ipairs
	elseif type(data) == 'table' then
		return pairs
	end
end

local function _pred(dat,mat)
	local iter = _iter(mat)
	if iter then
		local pass = true
		for k,v in iter(mat) do
			if not _pred(dat[k],v) then
				pass = false
				break
			end
		end
		return pass
	end
	return dat == mat
end

local _merge

local function _search(indata,search)
	local queries = {}
	for i = 1, #search/2, 1 do
		queries[i] = {search[2*i-1], search[2*i]}
	end

	local iter = _iter(queries)
	for _, data in iter(queries) do
		local matdata, mapdata = unpack(data)
		local iter = _iter(indata)
		for k,v in iter(indata) do
			if _pred(v,matdata) then
				indata[k] = _merge(v,mapdata)
			end
		end
	end
	return indata
end

function _merge(indata,mapdata)
	if mapdata == nil then
		return indata
	elseif mapdata == _reserved_delete then
		return nil
	elseif mapdata[_reserved_sequence] then
		local s = {}
		for k,v in pairs(mapdata) do
			local n = tonumber(k)
			if n then s[n] = v end
		end
		mapdata = s
	end
	if type(indata) == type(mapdata) and _isarray(indata) == _isarray(mapdata) then
		if _isarray(mapdata) and mapdata[1] == _reserved_append then
			for i = 2, #mapdata, 1 do
				insert(indata,mapdata[i])
			end
			return indata
		end
		if _isarray(mapdata) then
			if mapdata[1] == _reserved_search then
				return _search(indata, mapdata[2])
			end
			if mapdata[1] == _reserved_replace then
				remove(mapdata,1)
				return mapdata
			end
		elseif type(mapdata) == 'table' then
			local search = mapdata[_reserved_search]
			if search then
				return _search(indata,search)
			end
			if mapdata[_reserved_replace] then
				mapdata[_reserved_replace] = nil
				return mapdata
			end
			local ma, mb = getmetatable(indata), getmetatable(mapdata)
			local oa, ob = ma and ma.__sjsonorder, mb and mb.__sjsonorder
			local meta, order
			if ob ~= nil then
				meta = {}
				for k,v in pairs(ma) do
					meta[k] = v
				end
				if oa == nil then
					meta.__sjsonorder = oa
				else
					meta.__sjsonorder = _joinorder(oa,ob)
				end
				setmetatable(indata,meta)
			end
		end
		local iter = _iter(mapdata)
		if iter then
			for k,v in iter(mapdata) do
				indata[k] = _merge(indata[k],v)
			end
			return indata
		end
	end
	return mapdata
end

return _merge