import Foundation
import SwiftData

struct RecurringTransactionService {

    /// Pre-creates expected transactions for the given month from active recurring definitions.
    static func generateForMonth(
        month: Int,
        year: Int,
        context: ModelContext
    ) {
        guard let recurrings = try? context.fetch(
            FetchDescriptor<RecurringTransaction>(
                predicate: #Predicate { $0.isActive }
            )
        ) else { return }

        let existingTransactions = fetchMonthTransactions(month: month, year: year, context: context)

        for recurring in recurrings {
            let alreadyExists = existingTransactions.contains { t in
                t.label == recurring.label &&
                t.amount == recurring.amount
            }

            guard !alreadyExists else { continue }

            let cal = Calendar.current
            let day = min(recurring.dayOfMonth, cal.range(of: .day, in: .month,
                for: cal.date(from: DateComponents(year: year, month: month, day: 1))!)!.upperBound - 1)
            let date = cal.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()

            let transaction = Transaction(
                amount: recurring.amount,
                label: recurring.label,
                date: date,
                isManual: false,
                category: recurring.category,
                bankAccount: recurring.bankAccount
            )
            context.insert(transaction)
        }
    }

    /// Returns alerts for recurring transactions that haven't been matched
    /// after their expected day + grace period.
    static func checkMissing(
        month: Int,
        year: Int,
        today: Date = Date(),
        context: ModelContext
    ) -> [RecurringTransaction] {
        guard let recurrings = try? context.fetch(
            FetchDescriptor<RecurringTransaction>(
                predicate: #Predicate { $0.isActive }
            )
        ) else { return [] }

        let existingTransactions = fetchMonthTransactions(month: month, year: year, context: context)
        let cal = Calendar.current
        let currentDay = cal.component(.day, from: today)

        var missing: [RecurringTransaction] = []

        for recurring in recurrings {
            let expectedDay = recurring.dayOfMonth
            // Grace period of 3 days
            guard currentDay >= expectedDay + 3 else { continue }

            let matched = existingTransactions.contains { t in
                t.label == recurring.label ||
                (t.amount == recurring.amount && abs(cal.component(.day, from: t.date) - expectedDay) <= 3)
            }

            if !matched {
                missing.append(recurring)
            }
        }

        return missing
    }

    private static func fetchMonthTransactions(
        month: Int,
        year: Int,
        context: ModelContext
    ) -> [Transaction] {
        let cal = Calendar.current
        guard let startDate = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = cal.date(byAdding: .month, value: 1, to: startDate)
        else { return [] }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startDate && $0.date < endDate }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
