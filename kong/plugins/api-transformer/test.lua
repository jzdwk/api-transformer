-- for test
local access = require "access"

local config  = {
	api_fr_prefix="cmcc",
	api_bk_path="links/{n}/{offset}",
	api_fr_path="/cmcc/links",
	trans={"query:n>path:n","query:offset>path:offset"},
	api_fr_params = {},
    add={}
}

function access_test()
	-- Eventually, execute the parent implementation
	-- (will log that your plugin is entering this context)
	local start_time = os.clock()
	print("[api-transformer] start at "..start_time)
	local request_info = { 
		method = "http",
		headers = nil,
		querys = {n=20, offset=100},
		path = "cmcc/links?n=100&offset=20"
	}
	print("[api-transformer] start access execute. req path "..request_info.path)
	local transformed_request_table = access.execute(request_info, config)

	if transformed_request_table.method then
		print("[api-transformer]method trans to : "..transformed_request_table.method..".")
		--kong.service.request.set_method(transformed_request_table.method)
	end
	if transformed_request_table.headers then
		for k,v in ipairs(transformed_request_table.headers) do
			print("[api-transformer]headers trans to : ".."header name : "..k.."header value : "..v..".")
		end
		--kong.service.request.set_headers(transformed_request_table.headers)
	end
	if transformed_request_table.querys then
		for k,v in ipairs(transformed_request_table.querys) do
			print("[api-transformer]querys trans to : ".."query name : "..k.."query value : "..v..".")
		end
		--kong.service.request.set_query(transformed_request_table.querys)
	end
	if transformed_request_table.path then
		print("[api-transformer]path trans to : "..transformed_request_table.path..".")
		--kong.service.request.set_path(transformed_request_table.path)
	end
	print("[api-transformer] spend time : " .. os.clock() - start_time .. ".")
end

access_test()