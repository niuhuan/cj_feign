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

| 宏定义 | 说明 |
| -- | -- |
| `@FeignClient` | 将接口变为Http客户端实现 |


## 🔖 用例

完整代码参见 [lib_tests.cj](src/tests/lib_tests.cj)

运行单元测试 `cjpm test src/tests`


```cangjie
// 创建一个客户端
@FeignClient[path = "http://localhost:18080"]
public interface MyCLientC {
    @PostMapping[path="/hello"]
    func hello(@RequestBody body: Request): Response
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

`class Request` 和 `class Response` 均实现

## 🏆 贡献

欢迎您的issue和pull request, fork时请保留源仓库地址

#### 计划中的特性

- [ ] 避免用户import其他包


## 📕 协议

参考 [LICENSE](LICENSE) 文件

