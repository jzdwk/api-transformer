-- local cjson = require "cjson.safe"
local path_params_mgr = require "kong.plugins.api-transformer.path_params"
-- local path_params_mgr = require "path_params"

local _M = {}
--define
local CONTENT_TYPE = "Content-Type"
local CONTENT_LENGTH = "Content-Length"
local HOST = "host"

local JSON = "json"
local FORM = "form"
local MULTIPART = "multipart"
local HEAD = "head"
local QUERY = "query"
local PATH = "path"

local ngx = ngx
local kong = kong
local next = next
local type = type
local find = string.find
local upper = string.upper
local lower = string.lower
local gsub = string.gsub
local pairs = pairs
local insert = table.insert
local noop = function() end

local function append_value(current_value, value)
    local current_value_type = type(current_value)

    if current_value_type  == "table" then
      insert(current_value, value)
      return current_value
  end
  
  if current_value_type == "string"  or
   current_value_type == "boolean" or
   current_value_type == "number" then
      return { current_value, value }
  end
  
  return { value }
end

local function get_content_type(content_type)
    if content_type == nil then
        return nil
    end

    content_type = lower(content_type)

    if find(content_type, "application/json", nil, true) then
        return JSON
    end 
    if find(content_type, "application/x-www-form-urlencoded", nil, true) then
        return FORM
    end 
    if find(content_type, "multipart/form-data", nil, true) then
        return MULTIPART
    end

    return nil
end

-- retuern iter func，iter func return trans element
-- e.g. trans = "head:h1;query:q1"
-- return head h1 query q1
local function iter(config_array)
    kong.log.debug("[api-transformer] iter compose.")
    if type(config_array) ~= "table" then
        return
    end
    local i = 0
    return function(config_array)
        kong.log.debug("[api-transformer] iter start.")
        i = i + 1
        local current_pair = config_array[i]
        if current_pair == nil then
            return nil
        end
        local pos_fr, key1, 
            pos_bk, key2 = current_pair:match("^([^:]+):(.+)>([^:]+):(.+)$")
            kong.log.debug("[api-transformer] iter end.".." pos_fr "..pos_fr.." key1 "..key1.." pos_bk "..pos_bk.." key2 "..key2)
        return pos_fr, key1, pos_bk, key2
    end, config_array
end

local function set_json_value(table, key, value)
    if not key or not value or key == '' then
        return table
    end

    local json_table = table
    if not json_table then 
        json_table = {}
    end

    local json_path = key
    
    local pos = string.find(json_path, "%.")
    if not pos then
        if json_table[json_path] ~= nil then
            json_table[json_path] = append_value(json_table[json_path], value)
        else
            json_table[json_path] = value
        end
    elseif pos == 1 then
        json_path = string.sub(json_path, pos + 1, #json_path)
        json_table = set_json_value(json_table, json_path, value)
    elseif pos == #json_path then
        json_path = string.sub(json_path, 1, #json_path - 1)
        json_table = set_json_value(json_table, json_path, value)
    else
        local node_name = string.sub(json_path, 1, pos - 1)
        json_path = string.sub(json_path, pos + 1, #json_path)
        if not json_table[node_name] then
            json_table[node_name] = {}
        end
        json_table[node_name] = set_json_value(json_table[node_name], json_path, value)
    end
    return json_table
end

--[[******************************************************************
FunctionName:	change_head_value
Purpose:		修改请求中head参数值
Parameter:
        1 opt       [int]                 处理类型 0:提取参数值 1：设置参数
        2 headers   [table]               请求头参数表
        3 key       [string]              参数的key
        4 value     [string, number, nil] 待设置的参数值

Return:		
        opt为0，返回headers表和提取的参数值
        opt为1，返回headers表

Remark:     value为可选参数。opt == 1时传入
********************************************************************--]]
local function change_head_value(opt, headers, key, value)
    local val
    --local clear_header = kong.service.request.clear_header
    if opt == 0 then
      val = headers[key]
      headers[key] = nil
      --clear_header(key)

      return headers, val
  elseif opt == 1 then
      local temp_value = headers[key]
      if temp_value == nil then
        headers[key] = value --暂不考虑header里面重名key情况
    end

    return headers
end
end

--[[******************************************************************
FunctionName:	change_query_value
Purpose:		修改请求中query参数值
Parameter:
        1 opt       [int]                 处理类型 0:提取参数值 1：设置参数
        2 querys    [table]               query参数表
        3 key       [string]              参数的key
        4 value     [string, number, nil] 待设置的参数值

Return:	
        opt为0，返回querys表和提取的参数值
        opt为1，返回querys表

Remark:     value为可选参数。opt == 1时传入
********************************************************************--]]
local function change_query_value(opt, querys, key, value)
    local val
    if opt == 0 then
      val = querys[key]
      querys[key] = nil

      return querys, val
  elseif opt == 1 then
      local temp_value = querys[key]
      if temp_value == nil then
        querys[key] = value
    end

    return querys
end
end

--[[******************************************************************
FunctionName:	set_body_value
Purpose:		修改请求body
Parameter:
        1 key       [string]              参数的key
        2 value     [string, number, nil] 待设置的参数值
        3 body      [table]               body参数表 
        4 content_type  [string]          Content-Type属性 

Return:	
        返回body参数表

Remark: 
********************************************************************--]]
local function set_body_value(key, value, body, content_type)
  --[[
  if content_type == JSON then
  elseif content_type == FORM then
    if type(body) == "table" then
      body[key] = value
    end
  end

  return body
  --]]
end

--主函数
-- real_req, 真实http req
-- trans_table, 为经过http method转换的req
-- conf, 给插件配置的config项
local function transform_param(real_req, trans_table, conf)
    kong.log.debug("[api-transformer] transform_param start.")
    --原req info
    local headers = real_req.headers
    local querys = real_req.querys
    --调用path_params的parse_params，返回path的参数map
    -- e.g.
    -- api_fr_path = "/get/{id1}/info/{id2}"
    -- real_path = "/cmcc/get/100/info/200"
    -- api_fr_params = {"id1","id2"}
    -- api_fr_prefix = "cmcc"
    -- return {id1=100,id2=200}
    kong.log.debug("[api-transformer] parse_params start.")
    local api_fr_params = path_params_mgr.parse_params(conf.api_fr_path, real_req.path, conf.api_fr_params, conf.api_fr_prefix)
    kong.log.debug("[api-transformer] parse_params end.")
    -- debug log
    if api_fr_params then
        for k,v in ipairs(api_fr_params) do
            kong.log.debug("[api-transformer] api_fr_prams: "..k..": "..v..".")
        end
    end
    local api_bk_path = conf.api_bk_path  
    -- set host to nil
    --headers = change_head_value(1, headers, HOST, nil)
    --是否在config.XX中设置了config.trans / config.add, 
    local trans  = 0 < #conf.trans
    local add = 0 < #conf.add
    if not trans and not add then
         --如果不需要处理参数，直接返回后端路径 
        trans_table.path = api_bk_path 
        return trans_table
    end
    local query_changed
    local path_changed

    --读取config.add中设置的每项，根据配置，将conf描述参数添加到query和header
    kong.log.debug("[api-transformer] add params start.")
    for i = 1, #conf.add do
      local pos, key, value = conf.add[i]:match("^([^:]+):([^:]+):(.+)$")
      --调用各自函数处理，因为是add，逻辑比较简单
      if pos == HEAD then
        kong.log.debug("[api-transformer] add params in [HEAD]: "..key..": "..value..".")
        headers = change_head_value(1, headers, key, value)
        elseif pos == QUERY then
        kong.log.debug("[api-transformer] add params in [QUERY]: "..key..": "..value..".")
        querys = change_query_value(1, querys, key, value)
        if not query_changed then
          query_changed = true
        end
      end
    end
    kong.log.debug("[api-transformer] add params end.")
    -- headers.host = nil
    kong.log.debug("[api-transformer] api trans start.")
    --解析config.trans
    for api_fr_param_pos, api_fr_param, api_bk_param_pos, api_bk_param in iter(conf.trans) do
        --api_fr_param_pos=原参数位置，api_fr_param=原参数名，api_bk_param_pos=现参数位置，api_bk_param=现参数名
        if api_fr_param_pos and api_fr_param and api_bk_param_pos and api_bk_param then
            kong.log.debug("[api-transformer] trans info :".."api_fr_param_pos "..api_fr_param_pos.." api_fr_param "..api_fr_param.." api_bk_param_pos"..api_bk_param_pos.." api_bk_param "..api_bk_param)
            while true do
                local value
                --根据参数位置，提取参数值
                local pos_fr = lower(api_fr_param_pos)
                if pos_fr == QUERY then
                    -- 提取http real req中,query=api_fr_param的参数值value,并删除querys的对应项
                    querys, value = change_query_value(0, querys, api_fr_param)  
                    kong.log.debug("[api-transformer] trans fr_params in [QUERY]: "..value..".")                  
                    if not query_changed then query_changed = true end        
                elseif pos_fr == HEAD then
                    -- 提取http real req中,header=api_fr_param的参数值value,并删除headers的对应项
                    headers, value = change_head_value(0, headers, api_fr_param)
                    kong.log.debug("[api-transformer] trans fr_params in [HEAD]: "..value..".")           
                elseif pos_fr == PATH then
                    --根据config.trans中path:paramName的定义，取出api_fr_params中保存的api_fr_param对应的值
                    if type(api_fr_params) == "table" and next(api_fr_params) then	
                        value = api_fr_params[api_fr_param]
                    end
                    kong.log.debug("[api-transformer] trans fr_params in [PATH]: "..value..".")
                end

                if value == nil then break end 

                --映射参数值,将刚才取出的value值根据api_bk_param_pos的描述重新填入
                local pos_bk = lower(api_bk_param_pos)
                if pos_bk == HEAD then
                    kong.log.debug("[api-transformer] trans fr_params in [HEAD], set: "..value.." to "..api_bk_param)
                    headers[api_bk_param] = value
                elseif pos_bk == QUERY then
                    kong.log.debug("[api-transformer] trans fr_params in [QUERY], set: "..value.." to "..api_bk_param)
                    querys[api_bk_param] = value
                    if not query_changed then query_changed = true end 
                elseif pos_bk == PATH then
                    --如果是替换位置在path,替换
                    kong.log.debug("[api-transformer] trans fr_params in [PATH], set: "..value.." to "..api_bk_param)
                    api_bk_path = gsub(api_bk_path, '{'.. api_bk_param .. '}', value)
                    --config.replace如果有path的项，则标志位置true
                    if not path_changed then path_changed = true end
                end
                break
            end
        end
    end
    --将最终的替换后的值赋给trans_table并返回
    trans_table.headers = headers
    if query_changed then
        kong.log.debug("[api-transformer] set query info")
        trans_table.querys = querys
    end
    --替换path
    if path_changed then
        kong.log.debug("[api-transformer] set path info")
        trans_table.path = api_bk_path
    end
    return trans_table
end

--real_req为原始req的封装，conf为提交的所有config.XXX配置
function _M.execute(real_req, conf)
    local trans_table = {}
    --trans method，如果config.http_method有值并且不等于原method，替换
    if conf.http_method then
        local method = upper(conf.http_method)
        if method ~= real_req.method then
            trans_table.method = method
        end
    end
    --调用参数替换函数
    trans_table = transform_param(real_req, trans_table, conf)
    kong.log.debug("[api-transformer] get trans_table.")
    return trans_table
end

return _M

