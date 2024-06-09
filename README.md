# SwiftData-OrderedRelationship
A Swift macro taking away the pain in adding ordered relationships to SwiftData models.

## Description
Many SwiftData projects require explicitly ordered relationships. `SwiftData-OrderedRelationship` is a Swift macro that takes away the pain in implementing this and has implicit [CloudKit Sync Conflict Resolution](#conflict-resolution). No special handling on your part is required, when an array with a new order is supplied, `OrderedRelationship` does all the work for you.

## CloudKit Sync
OrderedRelationship is designed to support CloudKit synchronization, providing [fast syncing](#fast-syncing) and implicit [conflict resolution](#conflict-resolution). 

### Fast Syncing
OrderedRelationship doesn't store the order of its elements as the index of each element. It rather stores each elements position as a random number between `Int.min` and `Int.max`. When `B` gets inserted between `A` and `C` with the positions 100 and 104[^1], the position of `B` will be randomly chosen between 101, 102 and 103. This means only one object needs to be synced per change.

### Conflict Resolution
As detailed in [fast syncing](#fast-syncing), elements do not have consecutive position numbers, but are distributed randomly between `Int.min` and `Int.max`. By randomly choosing a new number between the numbers inbetween which a new element is inserted or an existing one is moved, having the same operation take place on two different devices with detached state does not require any explicit conflict resolution or re-assigning of indices after both changes have synced to either device.

## Example

Say you have a `SubItem` model:
```Swift
@Model
class SubItem {
    init() {}
}
```

Then you can add an ordered relationship to its container `Item`:
```Swift
@Model
final class Item {
    @OrderedRelationship
    var orderedSubItems: [OrderedSubItem]? = []
    
    init() {}
}
```

The type of the variable is an optional array of an undefined type, preferably the type you want to be ordered with a single word prefix. This type (`OrderedSubItem` in this example) will be defined by the `@OrderedRelationship` macro.

Now you add the inverse relationship to the `SubItem` model:
```Swift
var superitem: Item.OrderedSubItem? = nil
```

That's it. There is nothing more you need to do.

### Resulting Code
The resulting code will contain not only the `OrderedSubItem` model, but also a new variable:
```Swift
var subItems: [SubItem]
```
The variable name is inferred from your custom variable name, removing the first word. You can also specify it explicitly using the [`arrayVariableName` argument](#arrayvariablename). You can both get and set this array. All the work of storing the new order will be performed for you.

## Arguments
The `@OrderedRelationship` macro supports arguments to customize its behavior. All of them are optional, as seen in the example above.

### containingClassName
The name of the class containing the declaration (`Item` in the example above). If `nil`, this will be inferred by the name of the file in which the macro resides.

### itemClassName
The name of the class that the items are. If `nil`, will be inferred by name of the declared array contents without the prefix. In the example above with the array contents being of type `OrderedSubItem`, the type should be `SubItem`.

### inverseRelationshipName
The name of the property in `itemClassName` to use for the inverse relationship. Defaults to `superitem`, and in the example above would be `SubItem.superitem`. You are always required to create a property for the inverse relationship, and this argument allows you to tell the macro what it is.

### arrayVariableName
The variable name of the resulting array. If `nil`, will be inferred by the name of the declared variable without the prefix. In the example above with the variable name being called `orderedSubItems`, the resulting array will be called `subItems`.

### deleteRule
The delete rule to apply to the items. The default value is `.cascade`.

## Why is the macro applied to the ordered items and not the resulting array?
You might wonder why the `@OrderedRelationship` macro is applied to the stored array and not the resulting array, like this:
```Swift
@Model
final class Item {
    @OrderedRelationship
    var subItems: [SubItem]
    
    init() {}
}
```
While this code is easier to understand, it is simply an impossibility to create such a macro. Macros are expanded alongside each other on a code level basis. This means that the first macro to be expanded in the above code would be the `@Model` macro. The `@Model` macro cannot see the results of the `@OrderedRelationship` macro, since it is expanded after the `@Model` macro. That is why the stored array has to be the one that is declared by the macro user.



[^1]: The positions being this close to each other is a statistically irrelevant event, this is just an example to showcase the method.
