import Foundation
import SwiftData

@Model
final class RecurringTransaction {
    var id: UUID
    var label: String
    var amount: Decimal
    var dayOfMonth: Int
    var isActive: Bool
    var createdAt: Date

    var category: Category?
    var bankAccount: BankAccount?

    init(
        label: String,
        amount: Decimal,
        dayOfMonth: Int,
        isActive: Bool = true,
        category: Category? = nil,
        bankAccount: BankAccount? = nil
    ) {
        self.id = UUID()
        self.label = label
        self.amount = amount
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
        self.category = category
        self.bankAccount = bankAccount
        self.createdAt = Date()
    }
}
