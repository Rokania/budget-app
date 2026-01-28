import Foundation
import SwiftData

struct AutoCategorizationService {

    /// Attempts to auto-categorize a transaction using existing rules.
    /// Returns the matched category, or nil if no rule matches.
    static func categorize(
        transaction: Transaction,
        rules: [AutoCategoryRule]
    ) -> Category? {
        for rule in rules {
            if rule.matches(transaction: transaction) {
                return rule.category
            }
        }
        return nil
    }

    /// Creates a new auto-categorization rule from a transaction that was
    /// manually categorized by the user.
    static func createRule(
        from transaction: Transaction,
        category: Category,
        context: ModelContext
    ) {
        // Prefer merchant name, fall back to label
        let pattern: String
        let field: MatchField

        if let merchant = transaction.merchantName, !merchant.isEmpty {
            pattern = merchant.lowercased()
            field = .merchantName
        } else {
            pattern = transaction.label.lowercased()
            field = .label
        }

        // Check if rule already exists
        let existing = try? context.fetch(FetchDescriptor<AutoCategoryRule>())
        let alreadyExists = existing?.contains { rule in
            rule.matchPattern == pattern &&
            rule.matchField == field &&
            rule.category?.id == category.id
        } ?? false

        guard !alreadyExists else { return }

        let rule = AutoCategoryRule(
            matchPattern: pattern,
            matchField: field,
            category: category
        )
        context.insert(rule)
    }

    /// Applies all rules to uncategorized transactions.
    static func applyRules(context: ModelContext) {
        guard let rules = try? context.fetch(FetchDescriptor<AutoCategoryRule>()),
              !rules.isEmpty else { return }

        var descriptor = FetchDescriptor<Transaction>()
        descriptor.predicate = #Predicate<Transaction> { $0.category == nil }

        guard let uncategorized = try? context.fetch(descriptor) else { return }

        for transaction in uncategorized {
            if let category = categorize(transaction: transaction, rules: rules) {
                transaction.category = category
            }
        }
    }
}
