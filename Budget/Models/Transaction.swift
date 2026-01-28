import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var amount: Decimal
    var label: String
    var merchantName: String?
    var date: Date
    var isManual: Bool
    var goCardlessTransactionID: String?
    var createdAt: Date

    var category: Category?
    var bankAccount: BankAccount?
    var wallet: Wallet?

    var isExpense: Bool {
        amount < 0
    }

    var absoluteAmount: Decimal {
        abs(amount)
    }

    var monthComponent: Int {
        Calendar.current.component(.month, from: date)
    }

    var yearComponent: Int {
        Calendar.current.component(.year, from: date)
    }

    init(
        amount: Decimal,
        label: String,
        merchantName: String? = nil,
        date: Date = Date(),
        isManual: Bool = true,
        goCardlessTransactionID: String? = nil,
        category: Category? = nil,
        bankAccount: BankAccount? = nil,
        wallet: Wallet? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.label = label
        self.merchantName = merchantName
        self.date = date
        self.isManual = isManual
        self.goCardlessTransactionID = goCardlessTransactionID
        self.category = category
        self.bankAccount = bankAccount
        self.wallet = wallet
        self.createdAt = Date()
    }
}
