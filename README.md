CJ_LOMBOK 基础代码生成器
=====================

仓颉编程语言 Http客户端代码生成器。Java Feign 的仓颉实现

## 📦 安装

使用git方式进行引入，并使用 `cjpm update` 进行更新

（当仓颉包管理器完善时，将会推送到仓库使用版本安装）

```yaml
[dependencies]

cj_lombok = { git = "https://gitcode.com/niuhuan_cn/cj_feign.git" }
```


## 📖 特性

| 宏定义 | 位置 | 说明 |
| -- | -- | -- |
| `@FeignClient` | 接口 | 将接口变为Http客户端实现 |
| `@RequestBody` | 方法 | 使用Json发送数据 |
| `@ReauestHeader` / `@RequestHeader["name"]` | 方法 | 增加Header |
| `@RequestParam` / `@RequestHeader["name"]` | 方法 | 声明该参数是form参数, 也是不加宏时候的默认处理方式 |


## 🔖 用例

完整代码参见 [lib_tests.cj](src/tests/lib_tests.cj)

运行单元测试 `cjpm test src/tests`

```cangjie


@Default
@ToString
@Serializable
@Json
@AllArgsConstructor
public class Request {
    var request_conetent: String
}

@Default
@ToString
@Serializable
@Json
@AllArgsConstructor
public class Response {
    var response_content: String
}

// 创建一个客户端
@FeignClient[path = "http://localhost:18080"]
public interface MyCLientC {
    @PostMapping[path="/hello"]
    func hello1(@RequestBody body: Request): Response
    @GetMapping
    func hello2(account_id: String, @RequestHeader["auth"] auth: String): Response
    @PostMapping
    func hello3(@RequestParam["account_id"] accountId: String): Response
}

// 使用
main () {
    let request = Request("Hello, World, Request!")
    let myClient = FeignClientBuilder.build<MyCLientC>();
    println("Server back : ${myClient.hello(request)}")
}
```

输出: 

```
Server back : Response(response_content = Hello, World, Response!)

cjpm run finished
```

提示:

部分宏来自`cj_lombok`

## 🏆 贡献

欢迎您的issue和pull request, fork时请保留源仓库地址

#### 计划中的特性

- [ ] 避免用户import其他包
- [ ] RequestBuilder过滤器, 请求前用户对请求做一些操作


## 📕 协议

参考 [LICENSE](LICENSE) 文件

