import Foundation
import SwiftData

@Model
final class AutoCategoryRule {
    var id: UUID
    var matchPattern: String
    var matchField: MatchField
    var createdAt: Date

    var category: Category?

    init(
        matchPattern: String,
        matchField: MatchField = .merchantName,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.matchPattern = matchPattern.lowercased()
        self.matchField = matchField
        self.category = category
        self.createdAt = Date()
    }

    func matches(transaction: Transaction) -> Bool {
        let value: String?
        switch matchField {
        case .merchantName:
            value = transaction.merchantName
        case .label:
            value = transaction.label
        }
        guard let value else { return false }
        return value.lowercased().contains(matchPattern)
    }
}
