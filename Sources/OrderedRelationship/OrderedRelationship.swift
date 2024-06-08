import SwiftData

/// A macro that makes a relationship an ordered relationship. It has to be applied to a variable declaration that is an optional array containing a type name that is not yet defined. For example:
///
///     @OrderedRelationship var rawSubItems: [OrderedSubItem]? = nil
///
/// The model `OrderedSubItem` will be created by the macro.
///
/// - Parameters:
///   - containingClassName: The name of the class containing the declaration. If `nil`, will be inferred by filename.
///   - itemClassName: The name of the class that the items are. If `nil`, will be inferred by name of the declared array contents without the prefix. In the example above with the array contents being of type `OrderedSubItem`, the type should be `SubItem`.
///   - inverseRelationshipName: The name of the property in `itemClassName` to use for the inverse relationship. Defaults to `superitem`, and in the example above would be `SubItem.superitem`
///   - arrayVariableName: The variable name of the resulting array. If `nil`, will be inferred by the name of the declared variable without the prefix. In the example above with the variable name being called `rawSubItems`, the resulting array will be called `subItems`.
///   - deleteRule: The delete rule to apply to the items. The default value is `.cascade`.
@attached(peer, names: overloaded, arbitrary)
public macro OrderedRelationship(
    containingClassName: String? = nil,
    itemClassName: String? = nil,
    inverseRelationshipName: String? = nil,
    arrayVariableName: String? = nil,
    deleteRule: Schema.Relationship.DeleteRule = .cascade
) = #externalMacro(module: "OrderedRelationshipMacros", type: "OrderedRelationshipMacro")
