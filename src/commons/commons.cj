package cj_feign.commons

import std.ast.*

public func parseClassDecl(input: Tokens): (Decl, ClassDecl) {
    let decl = parseDecl(input)
    var thisDecl = decl
    while(thisDecl is MacroExpandDecl) {
        thisDecl = (thisDecl as MacroExpandDecl).getOrThrow().macroInputDecl
    }
    if (decl is ClassDecl) {
        return (decl, (decl as ClassDecl).getOrThrow())
    }
    diagReport(DiagReportLevel.ERROR, input[0..(0 + 1)], "macro can only be applied to classes", "should be class")
    throw Exception("macro can only be applied to classes")
}

public func parseInterfaceDecl(input: Tokens): (Decl, InterfaceDecl) {
    let decl = parseDecl(input)
    var thisDecl = decl
    while(thisDecl is MacroExpandDecl) {
        thisDecl = (thisDecl as MacroExpandDecl).getOrThrow().macroInputDecl
    }
    if (decl is InterfaceDecl) {
        return (decl, (decl as InterfaceDecl).getOrThrow())
    }
    diagReport(DiagReportLevel.ERROR, input[0..(0 + 1)], "macro can only be applied to interfaces", "should be interface")
    throw Exception("macro can only be applied to interfaces")
}


/*
public func parseInterfaceDecl(input: Tokens): (Decl, InterfaceDecl, Option<MacroExpandDecl>) {
    let decl = parseDecl(input)
    var thisDecl = decl
    var parentDecl: Option<MacroExpandDecl> = None
    while(thisDecl is MacroExpandDecl) {
        parentDecl = Some((thisDecl as MacroExpandDecl).getOrThrow())
        thisDecl = (thisDecl as MacroExpandDecl).getOrThrow().macroInputDecl
    }
    if (decl is InterfaceDecl) {
        return (decl, (decl as InterfaceDecl).getOrThrow(), parentDecl)
    }
    diagReport(DiagReportLevel.ERROR, input[0..(0 + 1)], "macro can only be applied to interfaces", "should be interface")
    throw Exception("macro can only be applied to interfaces")
}
*/