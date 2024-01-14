import Foundation
import SwiftData
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct OrderedRelationshipPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OrderedRelationshipMacro.self
    ]
}
