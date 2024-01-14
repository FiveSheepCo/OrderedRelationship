import Foundation
import SwiftData
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension LabeledExprListSyntax {
    /// Retrieve the first element with the given label.
    func first(labeled name: String) -> Element? {
        return first { element in
            if let label = element.label, label.text == name {
                return true
            }
            
            return false
        }
    }
}
