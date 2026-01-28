import Foundation
import SwiftData

@MainActor
final class BankSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var lastSyncDate: Date?

    private let client = EnableBankingClient.shared

    /// Syncs all connected (non-manual) bank accounts.
    func syncAllAccounts(context: ModelContext) async {
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let descriptor = FetchDescriptor<BankAccount>(
            predicate: #Predicate { !$0.isManual }
        )
        guard let accounts = try? context.fetch(descriptor) else { return }

        let rules = (try? context.fetch(FetchDescriptor<AutoCategoryRule>())) ?? []

        for account in accounts {
            guard let uid = account.enableBankingAccountUID else { continue }

            do {
                // Update balance
                if let balanceResp = try? await client.getAccountBalances(accountUID: uid),
                   let balance = balanceResp.balances.first,
                   let amount = Decimal(string: balance.balance_amount.amount) {
                    account.balance = amount
                }

                // Import transactions
                let txResp = try await client.getAccountTransactions(accountUID: uid)
                let transactions = txResp.transactions ?? []

                for ebTx in transactions {
                    // Only import booked transactions (API uses "BOOK" / "PDNG")
                    if ebTx.status == "PDNG" { continue }
                    try importTransaction(ebTx, into: account, rules: rules, context: context)
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        lastSyncDate = Date()
        try? context.save()
    }

    private func importTransaction(
        _ ebTx: EBTransaction,
        into account: BankAccount,
        rules: [AutoCategoryRule],
        context: ModelContext
    ) throws {
        let txId = ebTx.id

        // Check duplicate
        let existing = try context.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.goCardlessTransactionID == txId }
        ))
        guard existing.isEmpty else { return }

        guard let amount = ebTx.decimalAmount else { return }

        let transaction = Transaction(
            amount: amount,
            label: ebTx.label,
            merchantName: ebTx.merchantName,
            date: ebTx.parsedDate ?? Date(),
            isManual: false,
            goCardlessTransactionID: txId,
            bankAccount: account
        )

        // Auto-categorize
        if let category = AutoCategorizationService.categorize(transaction: transaction, rules: rules) {
            transaction.category = category
        }

        context.insert(transaction)
        matchRecurring(transaction: transaction, context: context)
    }

    private func matchRecurring(transaction: Transaction, context: ModelContext) {
        guard let recurrings = try? context.fetch(
            FetchDescriptor<RecurringTransaction>(predicate: #Predicate { $0.isActive })
        ) else { return }

        let cal = Calendar.current
        let txDay = cal.component(.day, from: transaction.date)

        for recurring in recurrings {
            let amountMatch = transaction.amount == recurring.amount
            let labelMatch = transaction.label.localizedCaseInsensitiveContains(recurring.label)
            let dayClose = abs(txDay - recurring.dayOfMonth) <= 3

            if (amountMatch && dayClose) || (labelMatch && amountMatch) {
                if transaction.category == nil, let cat = recurring.category {
                    transaction.category = cat
                }
                break
            }
        }
    }
}
