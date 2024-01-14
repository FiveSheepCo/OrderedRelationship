import Foundation
import SwiftData
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct OrderedRelationshipMacro {}

extension OrderedRelationshipMacro: PeerMacro {
    
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        
        let argumentList = node.arguments?.as(LabeledExprListSyntax.self) ?? []
        let containingModelName: String? = argumentList.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
        
        // Find variable and its name
        guard
            let varDecl = declaration.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first, varDecl.bindings.count == 1,
            let orderedVariableName = binding.pattern.as(IdentifierPatternSyntax.self)?.description
        else {
            throw OrderedRelationshipError.message("@OrderedRelationship only works on single variables")
        }
        
        // Find the item variable name
        let itemsVariableName: String
        if let name = argumentList.first(labeled: "arrayVariableName")?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue {
            itemsVariableName = name
        } else if let name = try! Regex("[a-z]+([A-Z].*)").wholeMatch(in: orderedVariableName)?[1].substring {
            var name = String(name)
            let firstLetter = name.removeFirst()
            name.insert(contentsOf: firstLetter.lowercased(), at: name.startIndex)
            itemsVariableName = name
        } else {
            throw OrderedRelationshipError.message("Could not infer the items class name, please provide one using the `itemClassName` argument.")
        }
        
        // Extract optional array type
        guard
            let optional = binding.typeAnnotation?.type.as(OptionalTypeSyntax.self),
            let array = optional.wrappedType.as(ArrayTypeSyntax.self)
        else {
            throw OrderedRelationshipError.message("@OrderedRelationship requires an optional array type annotation")
        }
        let orderedClass = array.element
        let orderedClassName = orderedClass.description
        
        // Find the item class name
        let itemClassName: String
        if let itemModelName = argumentList.first(labeled: "itemClassName")?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue {
            itemClassName = itemModelName
        } else if let itemModelName = try! Regex("[A-Z][a-z]*(.+)").wholeMatch(in: orderedClassName)?[1].substring {
            itemClassName = String(itemModelName)
        } else {
            throw OrderedRelationshipError.message("Could not infer the items class name, please provide one using the `itemClassName` argument.")
        }
        
        // Make sure there is no accessorBlock
        guard binding.accessorBlock == nil else {
            throw OrderedRelationshipError.message("@OrderedRelationship does not support get and set blocks")
        }
        
        // Get the container class name
        guard
            let className = containingModelName ?? context.location(of: declaration, at: .afterLeadingTrivia, filePathMode: .fileID)?.file.description.trimmingCharacters(in: ["\""]).components(separatedBy: "/").last?.replacingOccurrences(of: ".swift", with: "")
        else {
            throw OrderedRelationshipError.message("No containing class name was found. Please supply one using the `containingClassName` argument.")
        }
        
        let deleteRule = argumentList.first(labeled: "deleteRule")?.expression.description ?? ".cascade"
        
        return [
            """
            @Model
            class \(orderedClass) {
                var order: Int = 0
                @Relationship(deleteRule: \(raw: deleteRule), inverse: \\\(raw: itemClassName).superitem) var item: \(raw: itemClassName)? = nil
                @Relationship(deleteRule: .nullify, inverse: \\\(raw: className).\(raw: orderedVariableName)) var container: \(raw: className)? = nil
                
                init(order: Int, item: \(raw: itemClassName), container: \(raw: className)) {
                    self.order = order
                    
                    guard let context = container.modelContext else {
                        fatalError("Given container for \(orderedClass) has no modelContext.")
                    }
                    context.insert(self)
                    
                    if item.modelContext == nil {
                        context.insert(item)
                    } else if item.modelContext != context {
                        fatalError("New item has different modelContext than its container.")
                    }
                    
                    self.item = item
                    self.container = container
                }
            }
            """,
            """
            var \(raw: itemsVariableName): [\(raw: itemClassName)] {
                get {
                    (\(raw: orderedVariableName) ?? []).sorted(using: SortDescriptor(\\.order)).compactMap(\\.item)
                }
                set {
                    guard let modelContext else { fatalError("\\(self) is not inserted into a ModelContext yet.") }
                    
                    var oldOrder = (\(raw: orderedVariableName) ?? []).sorted(using: SortDescriptor(\\.order))
                    let newOrder = newValue.map({ newValueItem in
                        oldOrder.first { 
                            $0.item == newValueItem
                        } ?? .init(order: 0, item: newValueItem, container: self)
                    })
                    let differences = newOrder.difference(from: oldOrder)
            
                    func completelyRearrangeArray() {
                        let count = newOrder.count
                        switch count {
                            case 0: 
                                return
                            case 1:
                                newOrder[0].order = 0
                                return
                            default: 
                                break
                        }
                        
                        let offset = Int.min / 2
                        let portion = Int.max / (count - 1)
                        
                        for index in 0..<count {
                            newOrder[index].order = offset + portion * index
                        }
                    }
                        
                    for difference in differences {
                        switch difference {
                            case .remove(let offset, let element, _):
                                if !newOrder.contains(element) {
                                    modelContext.delete(element)
                                }
                                oldOrder.remove(at: offset)
                            case .insert(let offset, let element, _):
                                if oldOrder.isEmpty {
                                    element.order = 0
                                    oldOrder.insert(element, at: offset)
                                    continue
                                }
                                
                                var from = Int.min / 2
                                var to = Int.max / 2
                                
                                if offset > 0 {
                                    from = oldOrder[offset-1].order + 1
                                }
                                if offset < oldOrder.count {
                                    to = oldOrder[offset].order
                                }
                                
                                guard from < to else {
                                    completelyRearrangeArray()
                                    return
                                }
                                
                                let range: Range<Int> = from..<to
                                element.order = range.randomElement()!
                                
                                oldOrder.insert(element, at: offset)
                        }
                    }
                }
            }
            """
        ]
    }
}
