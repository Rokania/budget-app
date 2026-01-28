import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var isDefault: Bool
    var sortOrder: Int
    var excludeFromBudget: Bool = false
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \BudgetAllocation.category)
    var allocations: [BudgetAllocation] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \AutoCategoryRule.category)
    var autoRules: [AutoCategoryRule] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.category)
    var recurringTransactions: [RecurringTransaction] = []

    init(
        name: String,
        icon: String = "folder.fill",
        color: String = "#0A84FF",
        isDefault: Bool = false,
        sortOrder: Int = 0,
        excludeFromBudget: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.excludeFromBudget = excludeFromBudget
        self.createdAt = Date()
    }
}
