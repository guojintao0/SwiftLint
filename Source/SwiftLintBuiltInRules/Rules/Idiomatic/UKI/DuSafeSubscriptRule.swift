//
//  UKISafeSubscriptRule.swift
//  SwiftLint
//
//  Created by guojintao on 2025/5/6.
//

import Foundation
import SwiftSyntax

struct UKISafeSubscriptRule:ConfigurationProviderRule, SwiftSyntaxRule {

    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "UKI_Safe_Subscript_Rule",
        name: "Safe Subscript Rule",
        description: "Swift中通过subscript访问数组元素，都要使用[safe:]；避免数组越界异常",
        kind: .lint,
        nonTriggeringExamples: [
            Example("array[safe:1]")
        ],
        triggeringExamples: [
            Example("array[1]\n")
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }

}


extension UKISafeSubscriptRule {

    enum VariableType {
        case Array
        case NoArray
        case Int
        case NoInt
        case unknown
    }

    struct NodeAndVariableDeclsCombine {
        let node: SyntaxProtocol
        let variableType: VariableType
        let identifier: String
        let isVariableDeclOrFuncParameter: Bool // true 为变量声明否则为方法参数
    }

    final class Visitor: ViolationsSyntaxVisitor {

        var SyntaxAndVariableDic: [Syntax: [NodeAndVariableDeclsCombine]] = [:]

        /// 访问 FunctionDeclSyntax
        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {

            let paramTypes = UKISafeSubscriptRule.getParamsType(node)

            let newParamCombines = paramTypes.map { (id, type) in
                NodeAndVariableDeclsCombine(node: node,
                                            variableType: type,
                                            identifier: id,
                                            isVariableDeclOrFuncParameter: false)
            }
            let syntax = Syntax(node)
            if var variableCombines = SyntaxAndVariableDic[syntax] {
                variableCombines.append(contentsOf: newParamCombines)
                SyntaxAndVariableDic[syntax] = variableCombines
            } else {
                SyntaxAndVariableDic[syntax] = newParamCombines
            }
            return super.visit(node)
        }

        /// 访问 ClosureExprSyntax
        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {

            let paramTypes = UKISafeSubscriptRule.getParamsType(node)

            let newParamCombines = paramTypes.map { (id, type) in
                NodeAndVariableDeclsCombine(node: node,
                                            variableType: type,
                                            identifier: id,
                                            isVariableDeclOrFuncParameter: false)
            }
            let syntax = Syntax(node)
            if var variableCombines = SyntaxAndVariableDic[syntax] {
                variableCombines.append(contentsOf: newParamCombines)
                SyntaxAndVariableDic[syntax] = variableCombines
            } else {
                SyntaxAndVariableDic[syntax] = newParamCombines
            }
            return super.visit(node)
        }

        /// 访问 VariableDeclSyntax
        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {

            let variableTypes = UKISafeSubscriptRule.getVariableType(node)
            /// 找寻Class，function，Struct，Enum，Init,  closure, sourceFile 父容器
            var containterParent: Syntax?
            var currentSyntax: Syntax? = node._syntaxNode.parent
            while let parent = currentSyntax {
                switch parent.kind {
                case .classDecl,.functionDecl,.structDecl,.enumDecl,.initializerDecl,.sourceFile,.closureExpr:
                    containterParent = parent
                default:
                    break
                }
                if containterParent != nil {
                    break
                } else {
                    currentSyntax = currentSyntax?.parent
                }
            }

            if let containterParent = containterParent {

                let newVariableCombines = variableTypes.map { (id, type) in
                    NodeAndVariableDeclsCombine(node: node,
                                                variableType: type,
                                                identifier: id,
                                                isVariableDeclOrFuncParameter: true)
                }
                if var variableCombines = SyntaxAndVariableDic[containterParent] {
                    variableCombines.append(contentsOf: newVariableCombines)
                    SyntaxAndVariableDic[containterParent] = variableCombines
                } else {
                    SyntaxAndVariableDic[containterParent] = newVariableCombines
                }
            }

            return super.visit(node)
        }


        override func visit(_ node: SubscriptExprSyntax) -> SyntaxVisitorContinueKind {
            return .visitChildren
        }

        override func visitPost(_ node: SubscriptExprSyntax) {

            // 1. 下标表达式作为左值，不用检查
            if let token = node.nextToken(viewMode: .sourceAccurate),
               ["="].contains(token.text){
                /// 赋值表达式，不用检查
                return
            }

            var hasSafe = false
            var isArray = false

            if node.argumentList.count > 1 || node.argumentList.isEmpty   {
                /// 2. 下标表达式超过1个参数，则一定不是数组
                isArray = false
                return
            } else if let firstArgument = node.argumentList.first {
                /// 3. 下标表达式中包含区间运算符，则一定不是数组
                if let sequenceExprSyntax =  firstArgument.expression.as(SequenceExprSyntax.self) {
                    for expr in sequenceExprSyntax.elements {
                        if let operatorExpr = expr.as(BinaryOperatorExprSyntax.self),
                        ["...","..<"].contains(where: { operatorExpr.operatorToken.text == $0 }) {
                           /// 包含区间运算符为区间取值计算，不检查
                           isArray = false
                           return
                        }
                    }
                }

                /// 4. 判断是否包含safe
                if firstArgument.label?.text == "safe" && firstArgument.colon?.text == ":" {
                    /// 使用了safe
                    hasSafe = true
                    return
                }
                /// 没有 safe
                hasSafe = false

                /// 5. 检查下标表达式 CallExpression 类型
                let result = checkSubscriptCallExpressionType(node: node.calledExpression)
                isArray = result.0
                let isConfirm = result.1

                if !isConfirm {
                    /// 2. 类型不确定，判断表达式参数
                    let result = checkSubscriptArguments(node: firstArgument.expression)
                    isArray = result.1 ? result.0 : false
                }
            }


            if !hasSafe && isArray {
                violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }

        func checkSubscriptArguments(node: ExprSyntax) -> (Bool,Bool) {
            var isArray = true
            var isConfirm = false
            // 1. 分析下标表达式参数类型
            /// 判断下标表达式参数是非整形字面值
            if node._syntaxNode.kind == .stringLiteralExpr ||
                node._syntaxNode.kind == .floatLiteralExpr ||
                node._syntaxNode.kind == .booleanLiteralExpr {
                /// key 非int类型，则非array
                isArray = false
                isConfirm = true
            }

            /// 如果是 整形字面值，就认为是数组
            if node.is(IntegerLiteralExprSyntax.self) {

                isArray = true
                isConfirm = true
            }

            /// 为计算表达式
            if node._syntaxNode.kind == .prefixOperatorExpr || // -a
                node._syntaxNode.kind == .binaryOperatorExpr { // -a
                isArray = false
                isConfirm = true
            }

            if let sequenceExpr = node.as(SequenceExprSyntax.self) {
                for expr in sequenceExpr.elements {
                    if let operatorExpr = expr.as(BinaryOperatorExprSyntax.self),
                       !["+","-","*","/","%"].contains(where: {
                           operatorExpr.operatorToken.text == $0
                       }) {
                        /// 不包含算术运算符，必然是非整数
                        isArray = false
                        isConfirm = false
                    }
                }
            }

            /// 为标识符
            if let argumentIdExpr = node.as(IdentifierExprSyntax.self) {
                if let combine = self.searchIdentifierDecl(identifier: argumentIdExpr.identifier.text,
                                                           syntax: node._syntaxNode) {
                    if combine.variableType != .Int && combine.variableType != .unknown {
                        isArray = false
                        isConfirm = false
                    }
                    /// 标识符类型为整数
                    if combine.variableType == .Int {
                        isArray = true
                        isConfirm = true
                    }
                }
            }

            /// 参数带. , 直接判断为非数组
            if let memberAccessExpr = node.as(MemberAccessExprSyntax.self) {
                /// 枚举/或其他类型
                if let base = memberAccessExpr.base?.as(IdentifierExprSyntax.self),
                   (base.identifier.text == "self" || base.identifier.text == "indexPath") {

                } else {
                    isArray = false
                    isConfirm = false
                }
            }

            return (isArray,isConfirm)
        }


        func checkSubscriptCallExpressionType(node: ExprSyntax) -> (Bool,Bool) {
            var isArray = true
            var isConfirm = false
            switch node._syntaxNode.kind {
            case .arrayExpr:
                isArray = true
                isConfirm = true
            case .functionCallExpr,.subscriptExpr:
                /// 类型无法判断，默认true
                isArray = true
            case .identifierExpr:
                isArray = true
                if let identifierExpr = node.as(IdentifierExprSyntax.self) {
                    if let combine = self.searchIdentifierDecl(identifier: identifierExpr.identifier.text,
                                                               syntax: node._syntaxNode) {
                        if combine.variableType == .Array {
                            isArray = true
                            isConfirm = true
                        } else if combine.variableType == .Int || combine.variableType == .NoArray {
                            isArray = false
                            isConfirm = true
                        } else {
                            isArray = true
                            isConfirm = false
                        }
                    }
                }
            default:
                isArray = true
                break
            }
            return (isArray,isConfirm)
        }



        func searchIdentifierDecl(identifier: String, syntax: Syntax) -> NodeAndVariableDeclsCombine? {
            var currentSyntax: Syntax? = syntax
            while let realSyntax = currentSyntax {

                var realSyntaxs: [Syntax] = [realSyntax]

                /// 1. 如果是扩展，找到原类声明
                if let extensionDecl = realSyntax.as(ExtensionDeclSyntax.self),
                   let nameID = extensionDecl.extendedType.as(SimpleTypeIdentifierSyntax.self) {
                    let name = nameID.typeName
                    if let classOrStruct =  SyntaxAndVariableDic.keys.first(where: { syntax in

                        if let classDecl = syntax.as(ClassDeclSyntax.self),
                           classDecl.identifier.text == name {
                            return true
                        }

                        if let structDecl = syntax.as(StructDeclSyntax.self),
                           structDecl.identifier.text == name {
                            return true
                        }

                        if let enumDecl = syntax.as(EnumDeclSyntax.self),
                           enumDecl.identifier.text == name {
                            return true
                        }

                        return false

                    }) {
                        realSyntaxs.append(classOrStruct)
                    }
                }

                for syntax in realSyntaxs {
                    if let variablesArray = SyntaxAndVariableDic[syntax] {

                        /// 优先使用变量声明
                        if let variableCombine = variablesArray.first(where: { combine in
                            combine.identifier == identifier && combine.isVariableDeclOrFuncParameter
                        }) {
                            return variableCombine
                        }

                        /// 再次使用方法/闭包的参数
                        if let variableCombine = variablesArray.first(where: { combine in
                            combine.identifier == identifier
                        }) {
                            return variableCombine
                        }
                    }

                    if let variablesArray = UKISafeSubscriptRuleHelper.variableDeclsOfClass[syntax] {

                        /// 优先使用变量声明
                        if let variableCombine = variablesArray.first(where: { combine in
                            combine.identifier == identifier && combine.isVariableDeclOrFuncParameter
                        }) {
                            return variableCombine
                        }

                        /// 再次使用方法/闭包的参数
                        if let variableCombine = variablesArray.first(where: { combine in
                            combine.identifier == identifier
                        }) {
                            return variableCombine
                        }
                    }


                }

                currentSyntax = realSyntax.parent
            }
            return nil
        }
    }

}
