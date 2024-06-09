import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(OrderedRelationshipMacros)
import OrderedRelationshipMacros

let testMacros: [String: Macro.Type] = [
    "OrderedRelationship": OrderedRelationshipMacro.self,
]
#endif

final class OrderedRelationshipTests: XCTestCase {
    func testMacro() throws {
        #if canImport(OrderedRelationshipMacros)
        assertMacroExpansion(
            """
            @Model
            final class Item {
                @OrderedRelationship(containingClassName: "Item")
                var rawSubItems: [OrderedSubItem]? = []
            
                init() {}
            }
            
            @Model
            class SubItem {
                var superitem: Item.OrderedSubItem? = nil
            
                init() {}
            }
            """,
            expandedSource: """
            @Model
            final class Item {
                var rawSubItems: [OrderedSubItem]? = []
            
                @Model
                class OrderedSubItem {
                    var order: Int = 0
                    @Relationship(deleteRule: .cascade, inverse: \\SubItem.superitem) var item: SubItem? = nil
                    @Relationship(deleteRule: .nullify, inverse: \\Item.rawSubItems) var container: Item? = nil
            
                    init(order: Int, item: SubItem, container: Item) {
                        self.order = order
            
                        guard let context = container.modelContext else {
                            fatalError("Given container for OrderedSubItem has no modelContext.")
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
            
                var subItems: [SubItem] {
                    get {
                        (rawSubItems ?? []).sorted(using: SortDescriptor(\\.order)).compactMap(\\.item)
                    }
                    set {
                        guard let modelContext else {
                            fatalError("\\(self) is not inserted into a ModelContext yet.")
                        }
            
                        var oldOrder = (rawSubItems ?? []).sorted(using: SortDescriptor(\\.order))
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
            
                            for index in 0 ..< count {
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
                                        from = oldOrder[offset - 1].order + 1
                                    }
                                    if offset < oldOrder.count {
                                        to = oldOrder[offset].order
                                    }
            
                                    guard from < to else {
                                        completelyRearrangeArray()
                                        return
                                    }
            
                                    let range: Range<Int> = from ..< to
                                    element.order = range.randomElement()!
            
                                    oldOrder.insert(element, at: offset)
                            }
                        }
                    }
                }
            
                init() {}
            }
            
            @Model
            class SubItem {
                var superitem: Item.OrderedSubItem? = nil
            
                init() {}
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCustomizedInverseRelationshipNameMacro() throws {
#if canImport(OrderedRelationshipMacros)
        assertMacroExpansion(
            """
            @Model
            final class Item {
                @OrderedRelationship(containingClassName: "Item", inverseRelationshipName: "parentItem")
                var rawSubItems: [OrderedSubItem]? = []

                init() {}
            }

            @Model
            class SubItem {
                var parentItem: Item.OrderedSubItem? = nil

                init() {}
            }
            """,
            expandedSource: """
            @Model
            final class Item {
                var rawSubItems: [OrderedSubItem]? = []

                @Model
                class OrderedSubItem {
                    var order: Int = 0
                    @Relationship(deleteRule: .cascade, inverse: \\SubItem.parentItem) var item: SubItem? = nil
                    @Relationship(deleteRule: .nullify, inverse: \\Item.rawSubItems) var container: Item? = nil

                    init(order: Int, item: SubItem, container: Item) {
                        self.order = order

                        guard let context = container.modelContext else {
                            fatalError("Given container for OrderedSubItem has no modelContext.")
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

                var subItems: [SubItem] {
                    get {
                        (rawSubItems ?? []).sorted(using: SortDescriptor(\\.order)).compactMap(\\.item)
                    }
                    set {
                        guard let modelContext else {
                            fatalError("\\(self) is not inserted into a ModelContext yet.")
                        }

                        var oldOrder = (rawSubItems ?? []).sorted(using: SortDescriptor(\\.order))
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

                            for index in 0 ..< count {
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
                                        from = oldOrder[offset - 1].order + 1
                                    }
                                    if offset < oldOrder.count {
                                        to = oldOrder[offset].order
                                    }

                                    guard from < to else {
                                        completelyRearrangeArray()
                                        return
                                    }

                                    let range: Range<Int> = from ..< to
                                    element.order = range.randomElement()!

                                    oldOrder.insert(element, at: offset)
                            }
                        }
                    }
                }

                init() {}
            }

            @Model
            class SubItem {
                var parentItem: Item.OrderedSubItem? = nil

                init() {}
            }
            """,
            macros: testMacros
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }

    func testOmittedContainingClassName() throws {
#if canImport(OrderedRelationshipMacros)
        let fileName = "MyItem"

        assertMacroExpansion(
            """
            @Model
            final class \(fileName) {
                @OrderedRelationship(inverseRelationshipName: "parentItem")
                var rawSubItems: [OrderedSubItem]? = []

                init() {}
            }

            @Model
            class SubItem {
                var parentItem: \(fileName).OrderedSubItem? = nil

                init() {}
            }
            """,
            expandedSource: """
            @Model
            final class \(fileName) {
                var rawSubItems: [OrderedSubItem]? = []

                @Model
                class OrderedSubItem {
                    var order: Int = 0
                    @Relationship(deleteRule: .cascade, inverse: \\SubItem.parentItem) var item: SubItem? = nil
                    @Relationship(deleteRule: .nullify, inverse: \\\(fileName).rawSubItems) var container: \(fileName)? = nil

                    init(order: Int, item: SubItem, container: \(fileName)) {
                        self.order = order

                        guard let context = container.modelContext else {
                            fatalError("Given container for OrderedSubItem has no modelContext.")
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

                var subItems: [SubItem] {
                    get {
                        (rawSubItems ?? []).sorted(using: SortDescriptor(\\.order)).compactMap(\\.item)
                    }
                    set {
                        guard let modelContext else {
                            fatalError("\\(self) is not inserted into a ModelContext yet.")
                        }

                        var oldOrder = (rawSubItems ?? []).sorted(using: SortDescriptor(\\.order))
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

                            for index in 0 ..< count {
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
                                        from = oldOrder[offset - 1].order + 1
                                    }
                                    if offset < oldOrder.count {
                                        to = oldOrder[offset].order
                                    }

                                    guard from < to else {
                                        completelyRearrangeArray()
                                        return
                                    }

                                    let range: Range<Int> = from ..< to
                                    element.order = range.randomElement()!

                                    oldOrder.insert(element, at: offset)
                            }
                        }
                    }
                }

                init() {}
            }

            @Model
            class SubItem {
                var parentItem: \(fileName).OrderedSubItem? = nil

                init() {}
            }
            """,
            macros: testMacros,
            testFileName: fileName + ".swift"
        )
#else
        throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
    }
}
