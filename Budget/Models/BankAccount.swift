import Foundation
import SwiftData

@Model
final class BankAccount {
    var id: UUID
    var name: String
    var institution: String
    var type: AccountType
    var balance: Decimal
    var goCardlessRequisitionID: String? // Enable Banking session_id
    var enableBankingAccountUID: String? // Enable Banking account UID for direct API calls
    var isManual: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.bankAccount)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringTransaction.bankAccount)
    var recurringTransactions: [RecurringTransaction] = []

    init(
        name: String,
        institution: String = "",
        type: AccountType = .checking,
        balance: Decimal = 0,
        goCardlessRequisitionID: String? = nil,
        isManual: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.institution = institution
        self.type = type
        self.balance = balance
        self.goCardlessRequisitionID = goCardlessRequisitionID
        self.isManual = isManual
        self.createdAt = Date()
    }
}
