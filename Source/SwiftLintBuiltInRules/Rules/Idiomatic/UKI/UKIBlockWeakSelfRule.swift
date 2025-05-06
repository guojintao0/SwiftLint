//
//  MyCustomRule.swift
//  SwiftLint
//
//  Created by guojintao on 2025/4/30.
//

import Foundation
import SwiftSyntax
struct UKIBlockWeakSelfRule: ConfigurationProviderRule, SwiftSyntaxRule {

    var configuration = SeverityConfiguration<Self>(.error)

    init() {}

    static let description = RuleDescription(
        identifier: "UKI_Block_Weak_Self_Rule",
        name: "UKI Block Weak Self Rule",
        description: "在Block中使用self必须使用弱捕获，避免循环引用导致的内存泄漏及其他异常问题",
        kind: .metrics,
        nonTriggeringExamples: [
            Example("""
            var block = { [weak self] in
                self?.test()
            }
        """)
        ],
        triggeringExamples: [
            Example("""
            var block = {  in
                self.test()
            }
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }
}


extension UKIBlockWeakSelfRule {

    final class Visitor: ViolationsSyntaxVisitor {

        var checkingClosureExprArray: [ClosureExprSyntax] = []
        var containSelfDic: [ClosureExprSyntax: Bool] = [:]

        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind  {

            /// 1. 如果是闭包声明时直接调用，与直接执行代码没有区别；过滤掉
            if let functionCallExpr = node.parent?.as(FunctionCallExprSyntax.self),
               let calledExpression =  functionCallExpr.calledExpression.as(ClosureExprSyntax.self),
               calledExpression == node  {
                return .visitChildren
            }

            /// 2. 筛除掉方法或函数传入的闭包都是同步调用，不会持有，不会引发内存问题
            ///     - 集合相关方法和高级函数；
            ///     - snpKit 方法
            let collectionFunctionNameArray = ["firstIndex", "first", "last", "lastIndex", "contains", "allSatisfy",  "map", "compactMap", "flatMap", "reduce", "filter", "sorted", "forEach","removeAll"]
            let snpkitArray: [String] = ["makeConstraints","remakeConstraints", "updateConstraints"]
            let uikitArray: [String] = ["dismiss"]
            let ignoreFunctionArray = collectionFunctionNameArray + snpkitArray + uikitArray

            let uikitCallExpressArray: [String] = ["UIView.animate","UIView.animateKeyframes", "UIView.addKeyframe","UIView.transition","UIView.modifyAnimations","UIView.performWithoutAnimation"]
            let dispatchQueueCallExpressArray: [String] = ["DispatchQueue.main.async","DispatchQueue.main.sync","DispatchQueue.main.asyncAfter","DuTProductDetailTools.excuteInMainThread","DispatchQueue.global().asyncAfter","DispatchQueue.global().async"]
            let ignoreCallExpressArray = uikitCallExpressArray + dispatchQueueCallExpressArray

            let ignoreSpecializeArray: [String] = ["TransformOf"]

            /// 找到闭包作为参数传递的函数调用
            var targetFunctionCallExpr: FunctionCallExprSyntax? = nil

            /// 闭包作为参数传入方法
            if let tupleExprElementNode = node.parent?.as(TupleExprElementSyntax.self),
               let tupleExprElementListNode = tupleExprElementNode.parent?.as(TupleExprElementListSyntax.self),
               let functionCallExpr = tupleExprElementListNode.parent?.as(FunctionCallExprSyntax.self) {
                targetFunctionCallExpr = functionCallExpr
            }

            /// 尾随闭包
            if let functionCallExpr = node.parent?.as(FunctionCallExprSyntax.self),
               let trailingClosure =  functionCallExpr.trailingClosure?.as(ClosureExprSyntax.self),
               trailingClosure == node {
                targetFunctionCallExpr = functionCallExpr
            }

            /// 额外尾随闭包
            if let additionTailClosure = node.parent?.as(MultipleTrailingClosureElementSyntax.self),
               let functionCallExpr = additionTailClosure.parent?.parent?.as(FunctionCallExprSyntax.self) {
                targetFunctionCallExpr = functionCallExpr
            }

            if let targetFunctionCallExpr {
                /// MemberAccess
                if let calledExpression = targetFunctionCallExpr.calledExpression.as(MemberAccessExprSyntax.self) {
                    let memberAccessStr = DuSwiftSyntaxTool.syntaxStr(calledExpression)
                    if ignoreFunctionArray.contains(calledExpression.name.text) {
                        return .visitChildren
                    }
                    if ignoreCallExpressArray.contains(memberAccessStr) {
                        return .visitChildren
                    }
                }
                ///
                if let specializeExpr = targetFunctionCallExpr.calledExpression.as(SpecializeExprSyntax.self),
                   let identifierExpr = specializeExpr.expression.as(IdentifierExprSyntax.self),
                   ignoreSpecializeArray.contains(identifierExpr.identifier.text) {
                    return .visitChildren
                }
            }


            /// 检查是否有weak self
            var hasWeakSelf = false
            if let captureItems = node.signature?.capture?.items {
                captureItems.forEach({ item in
                    if let specifierText = item.specifier?.specifier.text,
                       specifierText == "weak",
                       let identifierExpr = item.expression.as(IdentifierExprSyntax.self),
                       identifierExpr.identifier.text == "self"  {
                        hasWeakSelf = true
                    }
                })
            }
            if hasWeakSelf {
                return .skipChildren
            } else {
                checkingClosureExprArray.append(node)
                return .visitChildren
            }
        }

        override func visitPost(_ node: ClosureExprSyntax) {
            checkingClosureExprArray.removeAll(where: { $0 == node })
            if let res = containSelfDic[node], res {
                violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }

        override func visit(_ node: IdentifierExprSyntax) -> SyntaxVisitorContinueKind {
            if let lastClosureExpr = checkingClosureExprArray.last,
               node.identifier.text == "self" {
                containSelfDic[lastClosureExpr] = true
            }
            return .visitChildren
        }

    }
}
