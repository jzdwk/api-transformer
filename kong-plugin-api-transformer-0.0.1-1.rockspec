package = "kong-plugin-api-transformer"
version = "0.0.1-1"

source = {
  url = "https://github.com/jzdwk/notes/tree/master/kong/api-transformer",
  tag = "v0.0.1-1"
}

supported_platforms = {"linux"}

description = {
  summary = "Api Plugin",
}

dependencies = {
   "lua >= 5.1"
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.api-transformer.handler"] = "kong/plugins/api-transformer/handler.lua",
    ["kong.plugins.api-transformer.schema"] = "kong/plugins/api-transformer/schema.lua",
    ["kong.plugins.api-transformer.access"] = "kong/plugins/api-transformer/access.lua",
    ["kong.plugins.api-transformer.path_params"] = "kong/plugins/api-transformer/path_params.lua"
  }
}
