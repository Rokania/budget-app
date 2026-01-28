import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - CSV Export Service

struct CSVExportService {

    /// Exports all transactions to a CSV file and returns the temporary file URL.
    static func export(context: ModelContext) throws -> URL {
        let transactions = try context.fetch(
            FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )

        var csv = "Date;Libelle;Marchand;Montant;Categorie;Compte;Type;ID Externe\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for tx in transactions {
            let date = dateFormatter.string(from: tx.date)
            let label = escapeCSV(tx.label)
            let merchant = escapeCSV(tx.merchantName ?? "")
            let amount = "\(tx.amount)"
            let category = escapeCSV(tx.category?.name ?? "")
            let account = escapeCSV(tx.bankAccount?.name ?? "")
            let type = tx.isManual ? "Manuel" : "Import"
            let externalId = escapeCSV(tx.goCardlessTransactionID ?? "")

            csv += "\(date);\(label);\(merchant);\(amount);\(category);\(account);\(type);\(externalId)\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("budget-export.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(";") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

// MARK: - CSV FileDocument for fileExporter

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let data: Data

    init(url: URL) {
        self.data = (try? Data(contentsOf: url)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
