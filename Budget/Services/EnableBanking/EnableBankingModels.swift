import Foundation

// MARK: - ASPSPs (Banks)

struct EBInstitutionsResponse: Decodable {
    let aspsps: [EBInstitution]
}

struct EBInstitution: Decodable, Identifiable {
    let name: String
    let country: String
    let logo: String?
    let bic: String?
    let beta: Bool?
    let psu_types: [String]?

    var id: String { name }
}

// MARK: - Authorization

struct EBStartAuthRequest: Encodable {
    let access: EBAccessScope
    let aspsp: EBASPSPSelection
    let state: String
    let redirect_url: String
    let psu_type: String?
}

struct EBAccessScope: Encodable {
    let valid_until: String
    let balances: Bool
    let transactions: Bool
}

struct EBASPSPSelection: Encodable {
    let name: String
    let country: String
}

struct EBStartAuthResponse: Decodable {
    let url: String
}

// MARK: - Sessions

struct EBCreateSessionRequest: Encodable {
    let code: String
}

struct EBSession: Decodable, Identifiable {
    let session_id: String
    let accounts: [EBSessionAccount]?
    let aspsp: EBSessionASPSP?
    let access: EBSessionAccess?

    var id: String { session_id }
}

struct EBSessionAccount: Decodable {
    let uid: String
    let identification_hashes: [String]?
}

struct EBSessionASPSP: Decodable {
    let name: String?
    let country: String?
}

struct EBSessionAccess: Decodable {
    let valid_until: String?
}

// MARK: - Account Details

struct EBAccountDetails: Decodable {
    let account_id: EBAccountId?
    let name: String?
    let currency: String?
    let identification_hash: String?
}

struct EBAccountId: Decodable {
    let iban: String?
    let other: EBAccountOtherId?
}

struct EBAccountOtherId: Decodable {
    let identification: String?
    let scheme_name: String?
}

// MARK: - Balances

struct EBBalancesResponse: Decodable {
    let balances: [EBBalance]
}

struct EBBalance: Decodable {
    let balance_amount: EBAmount
    let balance_type: String?
    let name: String?
    let last_change_date_time: String?
}

struct EBAmount: Decodable {
    let amount: String
    let currency: String
}

// MARK: - Transactions

struct EBTransactionsResponse: Decodable {
    let transactions: [EBTransaction]?
    let continuation_key: String?
}

struct EBTransaction: Decodable, Identifiable {
    let transaction_id: String?
    let entry_reference: String?
    let booking_date: String?
    let value_date: String?
    let transaction_amount: EBAmount
    let creditor: EBParty?
    let debtor: EBParty?
    let creditor_account: EBAccountId?
    let debtor_account: EBAccountId?
    let remittance_information: [String]?
    let status: String? // BOOK, PDNG
    let credit_debit_indicator: String?

    var id: String {
        transaction_id ?? entry_reference ?? UUID().uuidString
    }

    var label: String {
        if let info = remittance_information, let first = info.first, !first.isEmpty {
            return first
        }
        return merchantName ?? "Transaction"
    }

    var merchantName: String? {
        creditor?.name ?? debtor?.name
    }

    var parsedDate: Date? {
        let dateString = booking_date ?? value_date
        guard let dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    var decimalAmount: Decimal? {
        guard let raw = Decimal(string: transaction_amount.amount) else { return nil }
        // If the bank returns a positive amount with DBIT indicator, negate it
        if raw > 0 && credit_debit_indicator?.uppercased() == "DBIT" {
            return -raw
        }
        // If the bank returns a negative amount with CRDT indicator, make it positive
        if raw < 0 && credit_debit_indicator?.uppercased() == "CRDT" {
            return -raw
        }
        return raw
    }
}

struct EBParty: Decodable {
    let name: String?
}
