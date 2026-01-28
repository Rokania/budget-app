import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking = "checking"
    case savings = "savings"
    case investment = "investment"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .checking: "Compte courant"
        case .savings: "Epargne"
        case .investment: "Investissement"
        }
    }

    var icon: String {
        switch self {
        case .checking: "creditcard"
        case .savings: "banknote"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}

enum MatchField: String, Codable, CaseIterable, Identifiable {
    case merchantName = "merchantName"
    case label = "label"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .merchantName: "Nom du marchand"
        case .label: "Libelle"
        }
    }
}
