//
//  UKISafeSubscriptRuleHelper.swift
//  SwiftLint
//
//  Created by guojintao on 2025/5/6.
//

import Foundation
import SwiftSyntax
import SwiftLintCore

public struct UKISafeSubscriptRuleHelper {

   static var variableDeclsOfClass: [Syntax: [UKISafeSubscriptRule.NodeAndVariableDeclsCombine]] = [:]

    public static func traverseFilesAndFetchVariableInfo(files: [SwiftLintFile], configs: [Configuration]) {

       guard let _ = configs.first(where: { config in
           config.rules.contains { rule in
               rule.isEqualTo(UKISafeSubscriptRule())
           }
       }) else { return }

       for file in files {
           let visitor = VariableDeclsVisitor(viewMode: .sourceAccurate)
           visitor.walk(file.syntaxTree)
       }

       let extensionDeclArray: [ExtensionDeclSyntax] = variableDeclsOfClass.keys.compactMap { syntax in
           syntax.as(ExtensionDeclSyntax.self)
       }

       extensionDeclArray.forEach { syntax in

           if let idSyntax = syntax.extendedType.as(SimpleTypeIdentifierSyntax.self) {
               let name = idSyntax.name.text

               let targetSyntax = variableDeclsOfClass.keys.first { syntax in
                   if let classDecl = syntax.as(ClassDeclSyntax.self),
                      classDecl.identifier.text == name  {
                       return true
                   }
                   if let structDecl = syntax.as(StructDeclSyntax.self),
                      structDecl.identifier.text == name  {
                       return true
                   }
                   if let enumDecl = syntax.as(EnumDeclSyntax.self),
                      enumDecl.identifier.text == name  {
                       return true
                   }
                   return false
               }

               if let targetSyntax = targetSyntax,
                  let extendCombines = variableDeclsOfClass[Syntax(syntax)],
                  var combines = variableDeclsOfClass[targetSyntax]{

                   combines.append(contentsOf: extendCombines)
                   variableDeclsOfClass[targetSyntax] = combines
                   variableDeclsOfClass.removeValue(forKey: Syntax(syntax))
               }
           }
       }


   }
}

extension UKISafeSubscriptRuleHelper {

   final class VariableDeclsVisitor: SyntaxVisitor {

       override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {

           let variableCombines = dealWithVariableDecl(node: node.memberBlock.members).map { (id, type, node) in
               UKISafeSubscriptRule.NodeAndVariableDeclsCombine(node: node,
                                           variableType: type,
                                           identifier: id,
                                           isVariableDeclOrFuncParameter: true)
           }
           let syntax = Syntax(node)
           if var variableCombines = variableDeclsOfClass[syntax] {
               variableCombines.append(contentsOf: variableCombines)
               variableDeclsOfClass[syntax] = variableCombines
           } else {
               variableDeclsOfClass[syntax] = variableCombines
           }
           return .visitChildren
       }

       override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
           let variableCombines = dealWithVariableDecl(node: node.memberBlock.members).map { (id, type, node) in
               UKISafeSubscriptRule.NodeAndVariableDeclsCombine(node: node,
                                           variableType: type,
                                           identifier: id,
                                           isVariableDeclOrFuncParameter: true)
           }
           let syntax = Syntax(node)
           if var variableCombines = variableDeclsOfClass[syntax] {
               variableCombines.append(contentsOf: variableCombines)
               variableDeclsOfClass[syntax] = variableCombines
           } else {
               variableDeclsOfClass[syntax] = variableCombines
           }

           return .visitChildren
       }

       override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
           let variableCombines = dealWithVariableDecl(node: node.memberBlock.members).map { (id, type, node) in
               UKISafeSubscriptRule.NodeAndVariableDeclsCombine(node: node,
                                           variableType: type,
                                           identifier: id,
                                           isVariableDeclOrFuncParameter: true)
           }
           let syntax = Syntax(node)
           if var variableCombines = variableDeclsOfClass[syntax] {
               variableCombines.append(contentsOf: variableCombines)
               variableDeclsOfClass[syntax] = variableCombines
           } else {
               variableDeclsOfClass[syntax] = variableCombines
           }
           return .visitChildren
       }

       override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
           let variableCombines = dealWithVariableDecl(node: node.memberBlock.members).map { (id, type, node) in
               UKISafeSubscriptRule.NodeAndVariableDeclsCombine(node: node,
                                           variableType: type,
                                           identifier: id,
                                           isVariableDeclOrFuncParameter: true)
           }
           let syntax = Syntax(node)
           if var variableCombines = variableDeclsOfClass[syntax] {
               variableCombines.append(contentsOf: variableCombines)
               variableDeclsOfClass[syntax] = variableCombines
           } else {
               variableDeclsOfClass[syntax] = variableCombines
           }
           return .visitChildren
       }


       func dealWithVariableDecl(node: MemberDeclListSyntax) -> [(String, UKISafeSubscriptRule.VariableType, VariableDeclSyntax)] {
           var result: [(String, UKISafeSubscriptRule.VariableType, VariableDeclSyntax)] = []

           for member in node {
               if let variableDecl = member.decl.as(VariableDeclSyntax.self) {

                   for binding in variableDecl.bindings {
                       var identifier = ""
                       var type: UKISafeSubscriptRule.VariableType = .unknown

                       if binding.pattern._syntaxNode.kind == .identifierPattern,
                          let idPatternSyntax: IdentifierPatternSyntax = IdentifierPatternSyntax(binding.pattern._syntaxNode) {
                           /// 标识符名
                           identifier = idPatternSyntax.identifier.text
                       }

                       if var typAnnotation: TypeSyntax = binding.typeAnnotation?.type {
                           if let optionalTypeSyntax = typAnnotation.as(OptionalTypeSyntax.self) {
                               typAnnotation = optionalTypeSyntax.wrappedType
                           }
                           switch typAnnotation._syntaxNode.kind {
                           case .arrayType:
                               type = .Array
                           case .tupleType, .dictionaryType, .functionType:
                               type = .NoArray
                           case .simpleTypeIdentifier:
                               if let typeSyntax = typAnnotation.as(SimpleTypeIdentifierSyntax.self),
                                  typeSyntax.name.text == "Int" {
                                   type = .Int
                               } else {
                                   type = .unknown
                               }
                           default:
                               type = .unknown
                           }
                       } else if let value: ExprSyntax = binding.initializer?.value {
                           switch value._syntaxNode.kind {
                           case .arrayExpr:
                               type = .Array
                           case .tupleExpr,.dictionaryType,.floatLiteralExpr,.booleanLiteralExpr,.stringLiteralExpr:
                               type = .NoArray
                           case .integerLiteralExpr:
                               type = .Int
                           case .sequenceExpr:
                               type = .unknown
                               if let sequenceExpr = value.as(SequenceExprSyntax.self) {
                                   for expr in sequenceExpr.elements {
                                       if let operatorExpr = expr.as(BinaryOperatorExprSyntax.self),
                                          !["+","-","*","/","%"].contains(where: {
                                              operatorExpr.operatorToken.text == $0
                                          }) {
                                           /// 不包含算术运算符，必然是非整数
                                           type = .NoInt
                                           break
                                       }
                                   }
                               }
                           default:
                               type = .unknown
                           }
                       }
                       result.append((identifier,type,variableDecl))
                   }
               }
           }

           return result
       }

   }
}
extension UKISafeSubscriptRule {
    static func getVariableType(_ node: VariableDeclSyntax) -> [(String,VariableType)] {

        var result: [(String, VariableType)] = []

        for binding in node.bindings {
            var identifier = ""
            var type: VariableType = .unknown

            if binding.pattern._syntaxNode.kind == .identifierPattern,
               let idPatternSyntax: IdentifierPatternSyntax = IdentifierPatternSyntax(binding.pattern._syntaxNode) {
                /// 标识符名
                identifier = idPatternSyntax.identifier.text
            }

            if var typAnnotation: TypeSyntax = binding.typeAnnotation?.type {
                if let optionalTypeSyntax = typAnnotation.as(OptionalTypeSyntax.self) {
                    typAnnotation = optionalTypeSyntax.wrappedType
                }
                switch typAnnotation._syntaxNode.kind {
                case .arrayType:
                    type = .Array
                case .tupleType, .dictionaryType, .functionType:
                    type = .NoArray
                case .simpleTypeIdentifier:
                    if let typeSyntax = typAnnotation.as(SimpleTypeIdentifierSyntax.self),
                       typeSyntax.name.text == "Int" {
                        type = .Int
                    } else {
                        type = .unknown
                    }
                default:
                    type = .unknown
                }
            } else if let value: ExprSyntax = binding.initializer?.value {
                switch value._syntaxNode.kind {
                case .arrayExpr:
                    type = .Array
                case .tupleExpr,.dictionaryType,.floatLiteralExpr,.booleanLiteralExpr,.stringLiteralExpr:
                    type = .NoArray
                case .integerLiteralExpr:
                    type = .Int
                case .sequenceExpr:
                    type = .unknown
                    if let sequenceExpr = value.as(SequenceExprSyntax.self) {
                        for expr in sequenceExpr.elements {
                            if let operatorExpr = expr.as(BinaryOperatorExprSyntax.self),
                               !["+","-","*","/","%"].contains(where: {
                                   operatorExpr.operatorToken.text == $0
                               }) {
                                /// 不包含算术运算符，必然是非整数
                                type = .NoInt
                                break
                            }
                        }
                    }
                default:
                    type = .unknown
                }
            }
            result.append((identifier,type))
        }

        return result
    }

    static func getParamsType(_ node: SyntaxProtocol) -> [(String,VariableType)] {

        var result: [(String, VariableType)] = []


        if let node = node.as(FunctionDeclSyntax.self) {

            for paramSyntax in node.signature.input.parameterList {
                var identifier = ""
                var type: VariableType = .unknown

                if let secondName = paramSyntax.secondName {
                    identifier = secondName.text
                } else {
                    identifier = paramSyntax.firstName.text
                }

                var typAnnotation: TypeSyntax = paramSyntax.type

                if let optionalTypeSyntax = typAnnotation.as(OptionalTypeSyntax.self) {
                    typAnnotation = optionalTypeSyntax.wrappedType
                }
                switch typAnnotation._syntaxNode.kind {
                case .arrayType:
                    type = .Array
                case .tupleType, .dictionaryType, .functionType:
                    type = .NoArray
                case .simpleTypeIdentifier:
                    if let typeSyntax = typAnnotation.as(SimpleTypeIdentifierSyntax.self),
                       typeSyntax.name.text == "Int" {
                        type = .Int
                    } else {
                        type = .unknown
                    }
                default:
                    type = .unknown
                }
                result.append((identifier,type))
            }
        }

        if let node = node.as(ClosureExprSyntax.self),
           case let .input(input) = node.signature?.input {

            for paramSyntax in input.parameterList {
                var identifier = ""
                var type: VariableType = .unknown

                if let secondName = paramSyntax.secondName {
                    identifier = secondName.text
                } else if let firstName = paramSyntax.secondName {
                    identifier = firstName.text
                }

                if var typAnnotation: TypeSyntax = paramSyntax.type {

                    if let optionalTypeSyntax = typAnnotation.as(OptionalTypeSyntax.self) {
                        typAnnotation = optionalTypeSyntax.wrappedType
                    }
                    switch typAnnotation._syntaxNode.kind {
                    case .arrayType:
                        type = .Array
                    case .tupleType, .dictionaryType, .functionType:
                        type = .NoArray
                    case .simpleTypeIdentifier:
                        if let typeSyntax = typAnnotation.as(SimpleTypeIdentifierSyntax.self),
                           typeSyntax.name.text == "Int" {
                            type = .Int
                        } else {
                            type = .unknown
                        }
                    default:
                        type = .unknown
                    }
                }
                result.append((identifier,type))
            }
        }

        return result
    }

}
