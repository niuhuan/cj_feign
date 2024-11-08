package cj_feign.tests

import std.unittest.*
import std.unittest.testmacro.*

import std.io.*
import std.log.*
import log.*
import std.time.*
import std.sync.*
import net.http.ServerBuilder

import cj_lombok.*
import cj_feign.*

@When[test]
@Default
@ToString
@Serializable
@Json
@AllArgsConstructor
public class Request {
    var request_conetent: String
}

@When[test]
@Default
@ToString
@Serializable
@Json
@AllArgsConstructor
public class Response {
    var response_content: String
}

@FeignClient[path = "http://localhost:18080"]
public interface MyCLientC {
    @PostMapping[path="/hello"]
    func hello1(@RequestBody body: Request): Response
    @GetMapping
    func hello2(account_id: String, @RequestHeader["auth"] auth: String): Response
    @PostMapping
    func hello3(@RequestParam["account_id"] accountId: String): Response
}

@When[test]
@Test
public class TestRunner{
    let logger = getGlobalLogger(("name", "TestRunner"))

    // 1. 构建 Server 实例
    let server = ServerBuilder()
        .addr("127.0.0.1")
        .port(18080)
        .build()

    func startServer(): Unit {
        // 2. 注册请求处理逻辑
        server.distributor.register("/hello", {httpContext =>
            let stringReader = StringReader(httpContext.request.body)
            let all = stringReader.readToEnd()
            println("Request body : ${all}")
            httpContext.responseBuilder.body("{\"response_content\":\"Hello, World, Response!\"}")
        })
        server.logger.level = OFF
        // 3. 启动服务
        server.serve()
    }

    @TestCase
    func toStringTest(): Unit {
        spawn {
            startServer()
        }
        sleep(Duration.second)
        let request = Request("Hello, World, Request!")
        let myClient = FeignClientBuilder.build<MyCLientC>();
        println("Server back : ${myClient.hello1(request)}")
    }
}

