import Foundation
import SwiftData

@Model
final class Wallet {
    var id: UUID
    var name: String
    var monthlyAllowance: Decimal
    var currentBalance: Decimal

    @Relationship
    var allowedCategories: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.wallet)
    var transactions: [Transaction] = []

    var createdAt: Date

    init(
        name: String,
        monthlyAllowance: Decimal,
        currentBalance: Decimal = 0,
        allowedCategories: [Category] = []
    ) {
        self.id = UUID()
        self.name = name
        self.monthlyAllowance = monthlyAllowance
        self.currentBalance = currentBalance
        self.allowedCategories = allowedCategories
        self.createdAt = Date()
    }
}
