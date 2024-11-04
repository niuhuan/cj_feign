macro package cj_feign

public import cj_feign.macros.*
public import cj_feign.builder.*

public import net.http.{
    HttpRequestBuilder
}
public import encoding.url.{
    URL,
    Form
}
public import encoding.json.{
    ToJson,
    JsonValue
}
public import std.collection.{
    ArrayList
}
