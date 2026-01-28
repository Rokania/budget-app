import Foundation
import SwiftData

@Model
final class MonthlyBudget {
    var id: UUID
    var month: Int
    var year: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BudgetAllocation.monthlyBudget)
    var allocations: [BudgetAllocation] = []

    var totalBudgeted: Decimal {
        allocations.reduce(0) { $0 + $1.budgetedAmount }
    }

    init(month: Int, year: Int) {
        self.id = UUID()
        self.month = month
        self.year = year
        self.createdAt = Date()
    }
}
