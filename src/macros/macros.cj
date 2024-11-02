macro package cj_feign.macros

import std.ast.*
import std.collection.*

import cj_feign.commons.*

public macro FeignClient(inputTokens: Tokens) : Tokens {
    feignClient(quote(), inputTokens)
}


public macro FeignClient(attrTokens: Tokens, inputTokens: Tokens) : Tokens {
    feignClient(attrTokens, inputTokens)
}

func feignClient(attrTokens: Tokens, inputTokens: Tokens) : Tokens {
    var clientPath: Option<String>  = None
    let attrs = splitAttrTokens(attrTokens)
    for (attr in attrs) {
        match (attr) {
            case Attr.Name(value) => 
                if (value == "path") {
                    diagReport(
                        DiagReportLevel.ERROR,
                        attrTokens[0..(0 + 1)],
                        "invalid attribute",
                        "path attribute should have a value"
                    )
                }
            
            case Attr.NameAndValue(name, value) => 
                if (name == "path") {
                    clientPath = Some(value)
                } else {
                    diagReport(
                        DiagReportLevel.ERROR,
                        attrTokens[0..(0 + 1)],
                        "invalid attribute",
                        "only path attribute is supported"
                    )
                }
            
        }
    }
    // take the input and parse it as a class declaration
    let (decl, interfaceDecl) = parseInterfaceDecl(inputTokens)
    let initTokens = quote (
        public init(feignClientParams: FeignClientParams) {
            this.feignClientParams = feignClientParams
            this.feignClientConfigs = FeignClientConfigs()
            $(
                if (clientPath != None) {
                    quote ( this.feignClientConfigs.path = Some($(clientPath.getOrThrow())) )
                } else {
                    quote ()
                }
            )
        }
    )
    let buildTokens = quote (
        static public func build(feignClientParams: FeignClientParams): $(interfaceDecl.identifier) {
            $(interfaceDecl.identifier)(feignClientParams)
        }
    )
    // add the Serializable interface to the class declaration 
    let classIdentifierValue = interfaceDecl.identifier
    interfaceDecl.body.decls = processDecls(interfaceDecl.body.decls, inputTokens)
    interfaceDecl.superTypes.append(RefType(quote(FeignClientInterface < $(classIdentifierValue)  > )))
    interfaceDecl.body.decls.append(VarDecl(quote(let feignClientParams: FeignClientParams)))
    interfaceDecl.body.decls.append(VarDecl(quote(let feignClientConfigs: FeignClientConfigs)))
    interfaceDecl.body.decls.append(FuncDecl(initTokens))
    interfaceDecl.body.decls.append(FuncDecl(buildTokens))
    // return 
    let tokens = quote (
        $decl
    )
    var result = quote()
    for (token in tokens) {
        if (token.kind == INTERFACE)  {
            result += quote( class )
        } else {
          result += token
        }
    }
    result
}

func splitAttrTokens(attrTokens: Tokens) : ArrayList<Attr> {
    if (attrTokens.size == 0) {
        return ArrayList<Attr>()
    }
    let accAttrTokensList = ArrayList<(ArrayList<Token>, Int64)>()
    var accAttrTokens = ArrayList<Token>()
    var position = 0
    var curr = 0
    func putAttrToken() {
        if (accAttrTokens.size > 0) {
            accAttrTokensList.append((accAttrTokens, position))
            accAttrTokens = ArrayList<Token>()
        }
        position = curr + 1
    }
    for (attrToken in attrTokens) {
        if (COMMA == attrToken.kind) {
            putAttrToken()
        } else {
            accAttrTokens.append(attrToken)
        }
        curr++
    }
    putAttrToken()
    let attrs = ArrayList<Attr>()
    for ((accAttrTokens, position) in accAttrTokensList) {
        if (
            (accAttrTokens.size != 1 && accAttrTokens.size != 3) ||
            (accAttrTokens.size == 1 && accAttrTokens[0].kind != IDENTIFIER) ||
            (accAttrTokens.size == 3 && (accAttrTokens[0].kind != IDENTIFIER || accAttrTokens[1].kind != ASSIGN || accAttrTokens[2].kind != STRING_LITERAL))
        ) {
            diagReport(
                DiagReportLevel.ERROR,
                attrTokens[position..(position + 1)],
                "invalid attribute",
                "attribute should be identifier, or identifier = value, like `name` or `name = \"value\""
             )
        }
        if (accAttrTokens.size == 1) {
            attrs.append(Attr.Name(accAttrTokens[0].value))
        } else {
            attrs.append(Attr.NameAndValue(accAttrTokens[0].value, accAttrTokens[2].value))
        }
    }
    attrs
}

func processDecls(decls: ArrayList<Decl>, inputTokens: Tokens) : ArrayList<Decl> {
    var newDecls = ArrayList<Decl>()
    for (decl in decls) {
        if (decl is MacroExpandDecl) {
            let macroExpandDecl = (decl as MacroExpandDecl).getOrThrow()
            let needExpandedDecl = macroExpandDecl.macroInputDecl
            if (needExpandedDecl is FuncDecl) {
                newDecls.append(processFuncDecl(macroExpandDecl,(needExpandedDecl as FuncDecl).getOrThrow(), inputTokens))
            } else {
                diagReport(
                    DiagReportLevel.ERROR,
                    inputTokens[0..(0 + 1)],
                    "invalid declaration",
                    "only function declaration is supported, check: ${quote($decl)}"
                )
            }
        } else {
            diagReport(
                DiagReportLevel.ERROR,
                inputTokens[0..(0 + 1)],
                "invalid declaration",
                "only function declaration is supported , check: ${quote($decl)}"
            )
        }
    }
    newDecls
}

func processFuncDecl(macroExpandDecl: MacroExpandDecl, funcDecl: FuncDecl, inputTokens: Tokens) : FuncDecl {
    let (mapping, path) = processFeignClientMapping(macroExpandDecl, inputTokens)
    let funcName = funcDecl.identifier
    let funcParams = funcDecl.funcParams
    var requestBody = Option<FeignFuncParam>.None
    var pathVariables = ArrayList<FeignFuncParam>()
    var queryParams = ArrayList<FeignFuncParam>()
    var funcParamsClean = quote()
    var first = true
    for (funcParam in funcParams) {
        let feignFuncParam = processFuncParam(funcParam, inputTokens)
        match (feignFuncParam) {
            case FeignFuncParam.RequestBody(name, idType) =>
                if (first) {
                    first = false
                } else {
                    funcParamsClean += quote ( , )
                }
                funcParamsClean.append(quote ( $(name): $(idType) ))
                if (requestBody.isNone()) {
                        match (mapping) {
                            case FeignClientMapping.GetMapping =>
                                diagReport(
                                    DiagReportLevel.ERROR,
                                    inputTokens[0..(0 + 1)],
                                    "invalid function parameter",
                                    "GetMapping does not support RequestBody"
                                )
                            case _ => 
                                if (queryParams.size > 0) {
                                    diagReport(
                                        DiagReportLevel.ERROR,
                                        inputTokens[0..(0 + 1)],
                                        "invalid function parameter",
                                        "RequestBody and QueryParam can not be used together"
                                    )
                                } else {
                                    requestBody = Some(feignFuncParam) 
                                }     
                        }
                } else {
                        diagReport(
                            DiagReportLevel.ERROR,
                            inputTokens[0..(0 + 1)],
                            "invalid function parameter",
                            "only one RequestBody is supported"
                        )
                }
            case FeignFuncParam.PathVariable(name, idType) =>
                if (first) {
                    first = false
                } else {
                    funcParamsClean += quote ( , )
                }
                funcParamsClean.append(quote ( $(name): $(idType) ))
                pathVariables.append(feignFuncParam)
            case FeignFuncParam.QueryParam(name, idType) =>
                if (first) {
                    first = false
                } else {
                    funcParamsClean += quote ( , )
                }
                funcParamsClean.append(quote ( $(name): $(idType) ))
                if (requestBody.isNone()) {
                        queryParams.append(feignFuncParam)
                } else {
                    diagReport(
                        DiagReportLevel.ERROR,
                        inputTokens[0..(0 + 1)],
                        "invalid function parameter",
                        "RequestBody and QueryParam can not be used together"
                    )
                }
        }
    }
    let funcReturnType = funcDecl.declType
    var replacePathTokens = quote()
    for (pv in pathVariables) {
        match (pv) {
            case FeignFuncParam.PathVariable(id, _) =>
                let replaceKey = "{${id.value}}"
                replacePathTokens += quote (
                    .replace($(replaceKey), $(id).ToString())
                )
            case _ => throw Exception("invalid path variable")
        }
    }
    // gen tokens
    let formTokens = formTokens(mapping, queryParams)
    let requestBodyTokens = requestBodyTokens(mapping, requestBody)
    let result = quote (
        public func $(funcName) ($(funcParamsClean)) : $(funcReturnType) {
            let funcCfg = FeignFuncConfigs();
            $(
                if (path != None) {
                    quote ( funcCfg.path = Some($(path.getOrThrow())) )
                } else {
                    quote ()
                }
            )
            let url = URL.parse(FeignClientRequestBuilder.url(
                this.feignClientParams,
                this.feignClientConfigs,
                funcCfg
            )$(replacePathTokens))
            let client = FeignClientRequestBuilder.client(
                this.feignClientParams,
                this.feignClientConfigs,
                funcCfg
            )
            try {
                 //  request body,  query param (url encode)
                 $(
                    if (queryParams.size > 0) {
                        formTokens
                    } else {
                        requestBodyTokens
                    }
                 )
                 FeignClientRequestBuilder.execute<$(funcReturnType)>(client, request)
            } finally {
                client.close()
            }
        }
    )
    FuncDecl(result)
}

private func formTokens(mapping: FeignClientMapping, queryParams: ArrayList<FeignFuncParam>) : Tokens {
    var formAddTokens = quote ( let form = Form() )
    for (qp in queryParams) {
        match (qp) {
            case FeignFuncParam.QueryParam(id, idType) =>
                if (idType.value == "String") {
                    formAddTokens += quote (
                        form.add($(id.value), $(id))
                    )
                } else {
                    formAddTokens += quote (
                        form.add($(id.value), $(id).ToString())
                    )
                }
            case _ => throw Exception("invalid query param")
        }
    }
    match (mapping) {
        case FeignClientMapping.GetMapping =>
            formAddTokens += quote (
                let fullUrl = url.toString() + "?" + form.toEncodeString()
                let request = HttpRequestBuilder()
                .url(fullUrl)
                .get()
                .build()
            )
        case _ =>
            formAddTokens += quote (
                let request = HttpRequestBuilder()
                    .url(url)
                    .body(form.toEncodeString())
                    .header("Content-Type", "application/x-www-form-urlencoded")
            )
            match (mapping) {
                case FeignClientMapping.PostMapping =>
                    formAddTokens += quote (
                        .post()
                        .build()
                    )
                case FeignClientMapping.PutMapping =>
                    formAddTokens += quote (
                        .put()
                        .build()
                    )
                case FeignClientMapping.DeleteMapping =>
                    formAddTokens += quote (
                        .delete()
                        .build()
                    )
                case _ => throw Exception("invalid mapping")
            }
    }
    formAddTokens
}

private func requestBodyTokens(mapping: FeignClientMapping, requestBody: Option<FeignFuncParam>) : Tokens {
    var requestBodyTokens = quote (
        let request = HttpRequestBuilder()
                            .url(url)
    )
    match (requestBody) {
        case Some(FeignFuncParam.RequestBody(id, _)) =>
            requestBodyTokens += quote (
                .body($(id).serialize().toJson().toJsonString())
                .header("Content-Type", "application/json")
            )
        case _ => 
            requestBodyTokens += quote ()
    }
    match (mapping) {
        case FeignClientMapping.PostMapping =>
            requestBodyTokens += quote (
                .post()
                .build()
            )
        case FeignClientMapping.PutMapping =>
            requestBodyTokens += quote (
                .put()
                .build()
            )
        case FeignClientMapping.DeleteMapping =>
            requestBodyTokens += quote (
                .delete()
                .build()
            )
        case FeignClientMapping.GetMapping =>
            requestBodyTokens += quote (
                .get()
                .build()
            )
    }
    requestBodyTokens
}

private func processFeignClientMapping(macroExpandDecl: MacroExpandDecl, inputTokens: Tokens) : (FeignClientMapping, Option<String>) {
    let fullIdentifier = macroExpandDecl.fullIdentifier.value
    let macroAttrs = macroExpandDecl.macroAttrs
    var mapping = Option<FeignClientMapping>.None
    match (fullIdentifier) {
        case "PostMapping" =>
            mapping = Some(FeignClientMapping.PostMapping)
        case "PutMapping" =>
            mapping = Some(FeignClientMapping.PutMapping)
        case "DeleteMapping" =>
            mapping = Some(FeignClientMapping.DeleteMapping)
        case "GetMapping" =>
            mapping = Some(FeignClientMapping.GetMapping)
        case _ =>
            diagReport(
                DiagReportLevel.ERROR,
                inputTokens[0..(0 + 1)],
                "invalid function declaration",
                "only PostMapping, PutMapping, DeleteMapping, GetMapping is supported"
            )
    }
    let attr = splitAttrTokens(macroAttrs)
    var path = Option<String>.None
    for (a in attr) {
        match (a) {
            case Attr.NameAndValue(name, value) => 
                if (name == "path") {
                    path = Some(value)
                } else {
                    diagReport(
                        DiagReportLevel.ERROR,
                        inputTokens[0..(0 + 1)],
                        "invalid attribute",
                        "only path attribute is supported"
                    )
                }
            case _ => 
                diagReport(
                    DiagReportLevel.ERROR,
                    inputTokens[0..(0 + 1)],
                    "invalid attribute",
                    "only path attribute is supported"
                )
        }
    }
    (mapping.getOrThrow(), path)
}

private func processFuncParam(funcParam: FuncParam, inputTokens: Tokens) : FeignFuncParam {
        let paramTokens = quote ( $funcParam )
        if (paramTokens[0].kind == AT) {
          // [0] @(AT) | [1] RequestBody(IDENTIFIER) | [2] \n(NL) | [3]  body(IDENTIFIER)| [4] :(COLON) | [5] Request(IDENTIFIER)
          if (paramTokens.size != 6 || paramTokens[1].kind != IDENTIFIER || paramTokens[2].kind != NL || paramTokens[3].kind != IDENTIFIER || paramTokens[4].kind != COLON || paramTokens[5].kind != IDENTIFIER) {
                diagReport(
                    DiagReportLevel.ERROR,
                    inputTokens[0..(0 + 1)],
                    "invalid function parameter",
                    "function parameter should be like `@RequestBody body: Request`"
                )
          }
          match (paramTokens[1].value) {
            case "RequestBody" => 
                return FeignFuncParam.RequestBody(paramTokens[3], paramTokens[5])
            case "PathVariable" =>
                return FeignFuncParam.PathVariable(paramTokens[3], paramTokens[5])
            case "QueryParam" =>
                return FeignFuncParam.QueryParam(paramTokens[3], paramTokens[5])
            case _ =>
                diagReport(
                    DiagReportLevel.ERROR,
                    inputTokens[0..(0 + 1)],
                    "invalid function parameter",
                    "function parameter should be like `@RequestBody body: Request` or `@PathVariable id: String` or `@QueryParam name: String`"
                )
                throw Exception("invalid function parameter")
          }
        } else if (paramTokens[0].kind == IDENTIFIER) {
            // [0]  body(IDENTIFIER)| [1] :(COLON) | [2] Request(IDENTIFIER)
            if (paramTokens.size != 3 || paramTokens[1].kind != COLON || paramTokens[2].kind != IDENTIFIER) {
                diagReport(
                    DiagReportLevel.ERROR,
                    inputTokens[0..(0 + 1)],
                    "invalid function parameter",
                    "function parameter should be like `body: Request`"
                )
            }
            return FeignFuncParam.QueryParam(paramTokens[0], paramTokens[2])
        } else {
            diagReport(
                DiagReportLevel.ERROR,
                inputTokens[0..(0 + 1)],
                "invalid function parameter",
                "function parameter should be like `@RequestBody body: Request` or `body: Request`"
            )
            throw Exception("invalid function parameter")
        }
}

enum FeignFuncParam {
    | RequestBody(Token, Token) // paramName, paramType
    | PathVariable(Token, Token) // paramName, paramType
    | QueryParam(Token, Token) // paramName, paramType
}

enum Attr {
    | Name(String)
    | NameAndValue(String, String)
}

enum FeignClientMapping {
    | PostMapping
    | PutMapping
    | DeleteMapping
    | GetMapping
}

