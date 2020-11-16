-- 引入base plugin是可选的，也可以直接定义handler，比如像key-auth的定义
local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.api-transformer.access"
local ApiTransformerHandler = BasePlugin:extend()

-- 定义插件的优先级和版本，其中优先级的定义参考https://docs.konghq.com/2.2.x/plugin-development/custom-logic/#plugins-execution-order
ApiTransformerHandler.VERSION  = "1.0.0"
ApiTransformerHandler.PRIORITY = 15


-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instantiate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function ApiTransformerHandler:new()
  ApiTransformerHandler.super.new(self, "api-transformer")
end

-- http module下，handler总共有8个阶段可以嵌入自己的逻辑，具体阶段见下述代码。
-- 因为my-plugin将主要处理access阶段，所以其余阶段可以忽略

function ApiTransformerHandler:init_worker()
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.init_worker(self)

  -- Implement any custom logic here
end


function ApiTransformerHandler:preread(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.preread(self)

  -- Implement any custom logic here
end


function ApiTransformerHandler:certificate(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.certificate(self)

  -- Implement any custom logic here
end

function ApiTransformerHandler:rewrite(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.rewrite(self)

  -- Implement any custom logic here
end

--主要处理access阶段的功能，config参数为插件在配置时,config内的配置项
function ApiTransformerHandler:access(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
   ApiTransformerHandler.super.access(self)

    local start_time = os.clock()
    local request_info = { 
        method = kong.request.get_method(),
        headers = kong.request.get_headers(),
        querys = kong.request.get_query(),
        path = kong.request.get_path()
    }
    kong.log.debug("[api-transformer] start access execute. req path"..request_info.path)
    local transformed_request_table = access.execute(request_info, config)

    if transformed_request_table.method then
        kong.log.debug("[api-transformer]method trans to : "..transformed_request_table.method..".")
        kong.service.request.set_method(transformed_request_table.method)
    end
    if transformed_request_table.headers then
        for k,v in ipairs(transformed_request_table.headers) do
          kong.log.debug("[api-transformer]headers trans to : ".."header name : "..k.."header value : "..v..".")
        end
        kong.service.request.set_headers(transformed_request_table.headers)
    end
    if transformed_request_table.querys then
        for k,v in ipairs(transformed_request_table.querys) do
          kong.log.debug("[api-transformer]querys trans to : ".."query name : "..k.."query value : "..v..".")
        end
        kong.service.request.set_query(transformed_request_table.querys)
    end
    if transformed_request_table.path then
        kong.log.debug("[api-transformer]path trans to : "..transformed_request_table.path..".")
        kong.service.request.set_path(transformed_request_table.path)
    end
    kong.log.debug("[api-transformer] spend time : " .. os.clock() - start_time .. ".")
end

function ApiTransformerHandler:header_filter(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.header_filter(self)

  -- Implement any custom logic here
end

function ApiTransformerHandler:body_filter(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.body_filter(self)

  -- Implement any custom logic here
end

function ApiTransformerHandler:log(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ApiTransformerHandler.super.log(self)

  -- Implement any custom logic here
end

return ApiTransformerHandler

