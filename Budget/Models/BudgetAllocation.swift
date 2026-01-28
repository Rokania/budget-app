import Foundation
import SwiftData

@Model
final class BudgetAllocation {
    var id: UUID
    var budgetedAmount: Decimal

    var category: Category?
    var monthlyBudget: MonthlyBudget?

    init(budgetedAmount: Decimal, category: Category? = nil) {
        self.id = UUID()
        self.budgetedAmount = budgetedAmount
        self.category = category
    }
}
