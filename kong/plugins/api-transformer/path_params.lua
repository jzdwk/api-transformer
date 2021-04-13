local _M = {}
local API_PATH_PREFIX = 1

local function reverse_table(tab)
	local revtab = {}
	for k, v in pairs(tab) do
		revtab[v] = k
	end
	return revtab
end

local function encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

local function decodeURI(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end


-- api_fr_path 即config.api_fr_path的定义, e.g. /req/{id1}/info/{id2}
-- real_path 即实际的请求uri，比如 /cmcc/req/100/info/200
-- api_fr_params 即config.api_fr_params，e.g. id1 id2
-- e.g.
-- api_fr_path = "/get/{id1}/info/{id2}"
-- real_path = "/cmcc/get/100/info/200"
-- api_fr_params = {"id1","id2"}
-- api_fr_prefix = "cmcc"
-- return {id1=100,id2=200}
function _M.parse_params(api_fr_path, real_path, api_fr_params, api_fr_prefix)
	if not api_fr_path or not next(api_fr_params) then
		return
	end

	local params_map = {}
	local key_list = {}
	local value_list = {}

	--参数key的list, e.g. /req/{id1}/info/{id2}->{req,{id1},info,{id2}}
	for k in string.gmatch(api_fr_path, "([^/]+)") do
		table.insert(key_list, k)
	end

	--翻转key_list,根据下标配置，e.g. {req,{id1},info,{id2}}->{req=1,{id1}=2,info=3,{id2}=4}
	key_list = reverse_table(key_list)

	--提取的value的list
	for v in string.gmatch(real_path, "([^/]+)") do
		local str = v
		--如果参数值经过urlEncode处理，则进行urlDecode.(转换后的请求到kong时也会被urlEncode)
		if string.find(str, "%%") ~= nil then
			str = decodeURI(str)
		end
		--实际path的list, e.g. /req/100/info/200->{req,100,info,200}
		table.insert(value_list, str)
	end

	-- remove path prefix
	if api_fr_prefix then
		for k in string.gmatch(api_fr_prefix, "([^/]+)") do	
			if value_list[API_PATH_PREFIX] ==  k then
				table.remove(value_list ,API_PATH_PREFIX)
			end
		end
	end
	

	--get values from config.api_fr_params e.g. id1,id2
	for i = 1, #api_fr_params do
		local param = api_fr_params[i]
		local pattern = "{" .. param .. "}"
		--get index of params xxx from reversed keylist 
		local pos = key_list[pattern]
		--params_map[id1]=100
		params_map[param] = value_list[pos]
	end

	return params_map
end


return _M

