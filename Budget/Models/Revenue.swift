import Foundation
import SwiftData

@Model
final class Revenue {
    var id: UUID
    var name: String
    var amount: Decimal
    var month: Int
    var year: Int
    var isRecurring: Bool
    var createdAt: Date

    init(
        name: String,
        amount: Decimal,
        month: Int,
        year: Int,
        isRecurring: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.month = month
        self.year = year
        self.isRecurring = isRecurring
        self.createdAt = Date()
    }
}
