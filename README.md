# api-transformer

该插件用于对定义的由kong代理的api进行参数转换操作，将代理的api转换为后端的实际api,参考：https://github.com/cheriL/apig-request-transformer

## 目录结构

```
api-transformer
├─ api-transformer-0.0.1-1.rockspec  //插件使用luarocks安装卸载，rockspec是插件包的安装描述文件
└─ kong
   └─ plugins
      └─ api-transformer
         ├─ handler.lua //基础模块，封装openresty的不同阶段的调用接口
         ├─ schema.lua //schema配置模块，定义插件的config配置
         ├─ access.lua //access阶段的处理模块
         └─ path_params.lua //path参数处理模块
```

## 使用说明

该插件主要应用于kong route对象，支持http/https协议。kong插件配置说明：

```
config.http_method 将实际发送给backend的请求类型修改为指定类型
config.api_fr_prefix kong代理的请求参数前缀，主要用于处理api的path冲突问题
config.api_fr_path kong代理的api请求路径，path中可携带参数，比如/get/{id}/info
config.api_bk_path 实际的上游服务api请求路径，path中可携带参数，比如/get/{id2}/info
config.api_fr_params  kong代理的api中，在path上的请求参数组成的列表，比如/get/{id2}/info/{name},即为id2,name
config.trans 参数转换列表，语法为 原参数位置:原参数名>参数位置，参数名，参数位置的取值为head,query,path
config.add 参数增添列表，语法为 参数位置：参数名：参数值，参数位置的取值为head,query,path
```

## 例子

假设后端upsteam的api定义为:
```
[HTTP HEAD]
...省略
h1:v1
...省略
HEAD /get/{id}/info?name="xxx"
```
而用户想通过kong代理的对外暴露的api定义为（注：cmcc123为前缀）：
```
GET /cmcc123/query/{name}/info?id=xxx
```

则对应于`api-transformer`插件，其定义为：
```json
curl -X POST http://<admin-hostname>:8001/routes/<route>/plugins \
    --data "name=api-transformer"  \
    --data "config.http_method=HEAD" \
    --data "config.api_fr_prefix=cmcc123" \
    --data "config.api_fr_path=/cmcc123/query/{name}/info" \
    --data "config.api_bk_path=/get/{id}/info" \
    --data "config.api_fr_params=name" \
    --data "config.trans=query:id>path:id" \
    --data "config.trans=path:name>query:id" \
    --data "config.add=head:h1:v1" \
```



