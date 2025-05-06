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
        identifier: "UKI_Safe_Array_Rule",
        name: "UKI Safe Array Rule",
        description: "直接对数组进行取值操作可能会引发越界错误，请使用安全的访问方式，例如 `array[safe: index]`。",
        kind: .metrics,
        nonTriggeringExamples: [
                    Example("array.first"),
                    Example("array.last"),
                    Example("array[safe: 2]"),
                    Example("if index < array.count { array[index] }"),
                    Example("let index: UInt = 1; array[Int(index)]"), // 非Int类型不触发
                    Example("array[getIndex()]") // 非常量变量不触发
        ],
        triggeringExamples: [
            Example("array[↓0]"),
            Example("array[↓5]"),
            Example("let index: ↓Int = 2; array[↓index]"), // 变量声明和使用都触发
            Example("array[↓index] where index: Int") // 仅使用处触发
        ]
    )
    
    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor {
        Visitor(viewMode: .sourceAccurate)
    }
}


private extension UKISafeArrayRule {
    final class Visitor: ViolationsSyntaxVisitor {
        private var intVariables = Set<String>()
        
        // MARK: - 变量声明收集
        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            for binding in node.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    continue
                }
                
                // 情况1：显式声明为 Int（如 let index: Int）
                if let type = binding.typeAnnotation?.type.as(SimpleTypeIdentifierSyntax.self),
                   type.name.text == "Int" {
                    intVariables.insert(identifier) // ✅ 仅记录变量名，不标记位置
                }
                // 情况2：隐式推断为 Int（如 let index = 0）
                else if binding.typeAnnotation == nil,
                        let initializer = binding.initializer?.value.as(IntegerLiteralExprSyntax.self) {
                    intVariables.insert(identifier) // ✅ 仅记录变量名，不标记位置
                }
            }
            return .visitChildren
        }
        
        // MARK: - 下标访问检测
        override func visitPost(_ node: SubscriptExprSyntax) {
            guard let indexExpr = node.argumentList.first?.expression else { return }
            
            // 检测整数字面量（如 array[0]）
            if let integerLiteral = indexExpr.as(IntegerLiteralExprSyntax.self) {
                violations.append(integerLiteral.positionAfterSkippingLeadingTrivia) // ✅ 标记字面量位置
            }
            // 检测变量使用（如 array[index]）
            else if let identifierExpr = indexExpr.as(IdentifierExprSyntax.self) {
                let identifier = identifierExpr.identifier.text
                if intVariables.contains(identifier) {
                    violations.append(identifierExpr.positionAfterSkippingLeadingTrivia) // ✅ 标记变量使用位置
                }
            }
        }
    }
}
private extension TypeSyntax {
    var isArray: Bool {
        if let arrayType = self.as(ArrayTypeSyntax.self) {
            return true
        }
        if let simpleType = self.as(SimpleTypeIdentifierSyntax.self),
           simpleType.name.text == "Array" {
            return true
        }
        return false
    }

    var isInt: Bool {
        if let simpleType = self.as(SimpleTypeIdentifierSyntax.self),
           simpleType.name.text == "Int" {
            return true
        }
        return false
    }
}
