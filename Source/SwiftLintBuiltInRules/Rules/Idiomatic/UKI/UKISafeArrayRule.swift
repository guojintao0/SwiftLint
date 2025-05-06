//
//  UKISafeArrayRule.swift
//  SwiftLint
//
//  Created by guojintao on 2025/5/6.
//


import Foundation
import SwiftSyntax
struct UKISafeArrayRule: SwiftSyntaxRule, ConfigurationProviderRule {
    var configuration = SeverityConfiguration<Self>(.error)

    init() {}
    
    static let description = RuleDescription(
        identifier: "no_direct_array_index_access",
        name: "No Direct Array Index Access",
        description: "直接通过整数字面量索引访问数组可能导致越界崩溃，请使用安全访问方式或检查索引有效性",
        kind: .lint,
        nonTriggeringExamples: [
            Example("let first = array.first"),
            Example("let last = array.last"),
            Example("if index < array.count { array[index] }"),
            Example("if array.indices.contains(index) { array[index] }")
        ],
        triggeringExamples: [
            Example("array[↓0]"),
            Example("array[↓5]")
        ]
    )
    
    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }
}

private extension UKISafeArrayRule {
    final class Visitor: ViolationsSyntaxVisitor {
        override func visitPost(_ node: SubscriptExprSyntax) {
            guard let integerLiteral = node.argumentList
                .first?
                .expression
                .as(IntegerLiteralExprSyntax.self)
            else {
                return
            }
            
            violations.append(integerLiteral.positionAfterSkippingLeadingTrivia)
        }
    }
}
