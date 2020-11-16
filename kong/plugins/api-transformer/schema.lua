local typedefs = require "kong.db.schema.typedefs"


--config.add的参数存储 位置:参数名:值
--add table define      --[head,query]:param:value
local add_params = {
  type = "array",
  default = {},
  elements = { type = "string", match = "^[^:]+:[^:]+:.*$" },
}

--config.trans的参数存储 原参数位置:参数名;参数位置:参数名
--trans table define    --head:param1;query:param2
local trans_params = {
  type = "array",
  default = {},
  elements = { type = "string", match = "^[^:]+:.+>[^:]+:.+$" },
}

--config.api_fr_path_params  参数名称
--request param(path) array define
local api_fr_path_params = {
  type = "array",
  default = {},
  elements = { type = "string", match = "^[^/]+$" },
}

--config.api_fr_path_params  参数名称
--request param(path) array define
local api_bk_path_params = {
  type = "array",
  default = {},
  elements = { type = "string", match = "^[^/]+$" },
}


-- define request trans plugin schema
return {
  name = "api-transformer",
  fields = {
    --{ run_on = typedefs.run_on_first },
    --{ protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- backend method
          { http_method = typedefs.http_method },
          -- api front path prefix
          { api_fr_prefix = {type = "string"}},
          -- api frontend path define
          { api_fr_path = { type = "string"} },
          -- api backend path define
          { api_bk_path = { type = "string"} },
          -- api frontend path params
          { api_fr_params = api_fr_path_params },
          -- api backend path params
          -- { api_bk_params = api_bk_path_params }, 
          -- trans params schema define, e.g. query:name1>path:name2
          { trans = trans_params },
          { add  = add_params }
          -- { remove  = constant_params_array },
        }
      },
    },
  }
}