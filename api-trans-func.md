# api-transfunc

## 需求

用go实现一个trans函数，能够根据api模板中描述的front api以及back api，输出一个config结构，该config结构能够用于kong插件[api-transformer](https://github.com/jzdwk/api-transformer)

## 接口定义
```go
//apimd.ApiTplPost 即在apigw中对应的apimd目录下struct
//ApiTransConfig定义如下：

type ApiTransConfig struct {
	//back http method
	HttpMethod int
	//api prefix,apiTransProcess暂时不用考虑
	ApiFrPrefix string
	//front api path
	ApiFrPath string
	//back api path
	ApiBkPath string
	//位于front api path上的参数描述
	ApiFrParams []string
	//转换规则
	Trans []ParamTrans
	//新增参数
	Add []ParamAdd
}

type ParamTrans struct {
	//参数原位置
	ParamSrcPos int
	//参数原名称
	ParamSrcName string
	//参数目标位置
	ParamDescPos int
	//参数目标名称
	ParamDescName string
}

type ParamAdd struct {
	//参数位置
	ParamPos int
	//参数名称
	ParamName string
	//参数值
	ParamValue interface{}
}


func apiTransProcess(templateInfo *apimd.ApiTplPost) (conf *ApiTransConfig, err error) 

```

## 示例

假设用户想通过kong代理的对外暴露的api(即front_api)定义为：
```
http GET /query/{name1}/info/{name2}?id=xxx
```

而被kong代理的后端api(即back_api)定义为:
```
http HEAD /get/{id}/info?name1="xxx"&&name2="xxx"
```

根据以上场景，对于api模板的`CreateApiTemplate(templateInfo *apimd.ApiTplPost) (uuid string, err error)`接口来说(/apigw/manager/api_tpl.go)，其body值为,其中xxxx表示不涉及转换逻辑的值：
```json
{
  "group_id": "xxxx",
  "desc": "xxxx",
  "front": {
    "name": "xxxx",
    "path": "/query/{name1}/info/{name2}",
    "method": 0,
    "protocol": 0,
    "args": [
      {
        "name": "name1", 
        "location": 1,
        "type": 0,
        "required": xxxx,
        "defalut": "xxxx",
        "max": "xxxx",
        "min": "xxxx",
        "exmaple": "xxxx",
        "desc": "xxxx"
      },
      {
        "name": "name2",
        "location": 1,
        "type": 0,
        "required": xxxx,
        "defalut": "xxxx",
        "max": "xxxx",
        "min": "xxxx",
        "exmaple": "xxxx",
        "desc": "xxxx"
      },
	  {
        "name": "id",
        "location": 2,
        "type": 1,
        "required": xxxx,
        "defalut": "xxxx",
        "max": "xxxx",
        "min": "xxxx",
        "exmaple": "xxxx",
        "desc": "xxxx"
      }
    ]
  },
  "back": {
    "path": "/get/{id}/info",
    "method": 5,
    "protocol": 0,
    "auth": xxxx,
    "args": [
      {
        "name": "name1",
        "location": 2
      },
      {
        "name": "name2",
        "location": 2
      },
	  {
        "name": "name3",
        "location": 2
      }
    ]
  }
}
```
此时，调用函数`func apiTransProcess(templateInfo *apimd.ApiTplPost) (conf *ApiTransConfig, err error)`，返回的`conf`值的json格式为：
```go
{
  "HttpMethod": 5, //http 方法，GET-0,POST-1,DELETE-2,PUT-3,PATCH-4-HEAD-5,OPTIONS-6,ANY-7
  "ApiFrPrefix": "xxx",//暂不考虑
  "ApiFrPath": "/query/{name1}/info/{name2}",
  "ApiBkPath": "/get/{id}/info",
  "ApiFrParams": [
    "name1",
    "name2"
  ],
  "Trans": [
    {
      "ParamSrcPos": 1, //参数位置 HEAD-0 PATH-1 QUERY-2， 下同
      "ParamSrcName": "name1",
      "ParamDescPos": 2,
      "ParamDescName": "name1"
    },
    {
      "ParamSrcPos": 1,
      "ParamSrcName": "name2",
      "ParamDescPos": 2,
      "ParamDescName": "name2"
    },
    {
      "ParamSrcPos": 2,
      "ParamSrcName": "id",
      "ParamDescPos": 1,
      "ParamDescName": "id"
    }
  ]
}
```
