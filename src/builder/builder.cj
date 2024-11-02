package cj_feign.builder

import net.http.*
import serialization.serialization.*
import encoding.json.*
import std.io.*

public class FeignClientConfigs {
    public var path: Option<String> = None
}

public class FeignClientParams {
    public var path: Option<String> = None
}

public class FeignFuncConfigs {
    public var path: Option<String> = None
}

public interface FeignClientInterface<T> {
   static func build(params: FeignClientParams): T
}

public class FeignClientBuilder {

    public static func build<T>():T  where T <: FeignClientInterface<T> {
        T.build(FeignClientParams())
    } 

}

public class FeignClientRequestBuilder {
     public static func url(
        feignClientParams: FeignClientParams,
        feignClientConfigs: FeignClientConfigs,
        feignFuncConfigs: FeignFuncConfigs
     ): String {
        let paths: Array<Option<String>> = [
            feignClientParams.path,
            feignClientConfigs.path,
            feignFuncConfigs.path
        ]
        joinPath(paths)
     }

    public static func client(
        feignClientParams: FeignClientParams,
        feignClientConfigs: FeignClientConfigs,
        feignFuncConfigs: FeignFuncConfigs
     ) : Client {
        ClientBuilder().build()
    }

    public static func execute<T>(
        client: Client,
        request: HttpRequest
    ) :T where T <: Serializable<T> {
        let response = client.send(request)
        let body = response.body
        let jsonString = StringReader(body).readToEnd()
        let jv: JsonValue = JsonValue.fromStr(jsonString)
        let jdm = DataModel.fromJson(jv)
        T.deserialize(jdm)
    }

    public static func joinPath(paths: Array<Option<String>>): String {
        var path = ""
        for (p in paths) {
            if (p != None) {
                let current = p.getOrThrow()
                if (current != "") {
                    if (path == "") {
                        path = current
                    } else {
                        if (path.endsWith("/")) {
                            if (current.startsWith("/")) {
                                path = path + current[1..current.size]
                            } else {
                                path = path + current
                            }
                        } else {
                            if (current.startsWith("/")) {
                                path = path + current
                            } else {
                                path = path + "/" + current
                            }
                        }
                    }
                }
            }
        }
        path
    }
}
