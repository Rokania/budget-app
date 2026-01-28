import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Sparkle

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @Environment(\.modelContext) private var modelContext

    @State private var showingDeleteConfirmation = false
    @State private var csvExportURL: URL?
    @State private var showingExportError: String?

    private let updater: SPUUpdater?

    init(updater: SPUUpdater? = nil) {
        self.updater = updater
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Reglages")
                    .font(AppFont.title())
                    .staggered(index: 0)

                // Appearance
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Apparence")
                        .font(AppFont.heading())

                    Picker("Theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .staggered(index: 1)

                // Categories
                CategoryManagementView()
                    .staggered(index: 2)

                // Bank accounts
                BankAccountsSettingsSection()
                    .staggered(index: 3)

                // Auto-categorization rules
                AutoRulesSettingsSection()
                    .staggered(index: 4)

                // Recurring transactions
                RecurringSettingsSection()
                    .staggered(index: 5)

                // Updates
                if let updater = updater {
                    UpdatesSettingsSection(updater: updater)
                        .staggered(index: 6)
                }

                // Data
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Donnees")
                        .font(AppFont.heading())

                    HStack(spacing: Spacing.md) {
                        Button("Exporter en CSV") {
                            exportCSV()
                        }
                        .buttonStyle(.bordered)

                        Button("Supprimer toutes les donnees") {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    if let error = showingExportError {
                        Text(error)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.negative)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .staggered(index: 7)
            }
            .padding(Spacing.xl)
        }
        .background(Color.bgSecondary)
        .alert("Supprimer toutes les donnees?", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("Cette action est irreversible. Toutes vos transactions, budgets, comptes et categories seront supprimes.")
        }
        .fileExporter(
            isPresented: Binding(
                get: { csvExportURL != nil },
                set: { if !$0 { csvExportURL = nil } }
            ),
            document: csvExportURL.map { CSVDocument(url: $0) },
            contentType: .commaSeparatedText,
            defaultFilename: "budget-export-\(Self.dateStamp).csv"
        ) { result in
            if let url = csvExportURL {
                try? FileManager.default.removeItem(at: url)
            }
            csvExportURL = nil
        }
    }

    private static var dateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func exportCSV() {
        showingExportError = nil
        do {
            let url = try CSVExportService.export(context: modelContext)
            csvExportURL = url
        } catch {
            showingExportError = "Erreur lors de l'export: \(error.localizedDescription)"
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: RecurringTransaction.self)
            try modelContext.delete(model: MonthlyBudget.self)
            try modelContext.delete(model: BudgetAllocation.self)
            try modelContext.delete(model: Revenue.self)
            try modelContext.delete(model: BankAccount.self)
            try modelContext.delete(model: AutoCategoryRule.self)
            try modelContext.delete(model: Category.self)
            try modelContext.save()
        } catch {
            showingExportError = "Erreur lors de la suppression: \(error.localizedDescription)"
        }
    }
}

// MARK: - Updates Settings

private struct UpdatesSettingsSection: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Mises a jour")
                .font(AppFont.heading())

            HStack(spacing: Spacing.md) {
                Button("Rechercher des mises a jour") {
                    checkForUpdatesViewModel.checkForUpdates()
                }
                .buttonStyle(.bordered)
                .disabled(!checkForUpdatesViewModel.canCheckForUpdates)

                Toggle("Verifier automatiquement", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
            }

            if let lastUpdate = updater.lastUpdateCheckDate {
                Text("Derniere verification: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Bank Accounts Settings

private struct BankAccountsSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [BankAccount]

    @State private var showingAPISetup = false
    @State private var showingConnection = false
    @State private var accountToDelete: BankAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Comptes bancaires")
                    .font(AppFont.heading())
                Spacer()
                Menu {
                    Button("Configurer Enable Banking") {
                        showingAPISetup = true
                    }
                    Button("Connecter une banque") {
                        showingConnection = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            if accounts.isEmpty {
                Text("Aucun compte configure.")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(accounts) { account in
                        HStack(spacing: Spacing.md) {
                            Image(systemName: account.type.icon)
                                .foregroundStyle(account.isManual ? .secondary : Color.accentColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .font(AppFont.body())
                                HStack(spacing: Spacing.xs) {
                                    if !account.institution.isEmpty {
                                        Text(account.institution)
                                            .font(AppFont.caption())
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(account.isManual ? "Manuel" : "Connecte")
                                        .font(AppFont.caption())
                                        .foregroundStyle(account.isManual ? .secondary : Color.positive)
                                }
                            }

                            Spacer()

                            Text(account.balance.formatted)
                                .font(AppFont.mono())

                            Button(action: { accountToDelete = account }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.negative)
                        }
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.sm)

                        if account.id != accounts.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .sheet(isPresented: $showingAPISetup) {
            BankAPISetupSheet()
        }
        .sheet(isPresented: $showingConnection) {
            BankConnectionSheet()
        }
        .alert("Supprimer ce compte?", isPresented: Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button("Annuler", role: .cancel) { accountToDelete = nil }
            Button("Supprimer", role: .destructive) {
                if let account = accountToDelete {
                    modelContext.delete(account)
                }
                accountToDelete = nil
            }
        } message: {
            Text("Les transactions liees a ce compte seront egalement supprimees.")
        }
    }
}

// MARK: - Auto-Categorization Rules Settings

private struct AutoRulesSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AutoCategoryRule.createdAt) private var rules: [AutoCategoryRule]

    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Regles de categorisation")
                    .font(AppFont.heading())
                Spacer()

                Button(action: {
                    AutoCategorizationService.applyRules(context: modelContext)
                }) {
                    Label("Appliquer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Appliquer les regles aux transactions non categorisees")

                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }

            if rules.isEmpty {
                Text("Aucune regle. Les regles sont creees automatiquement quand vous categorisez une transaction.")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(rules) { rule in
                        HStack(spacing: Spacing.md) {
                            if let cat = rule.category {
                                Image(systemName: cat.icon)
                                    .foregroundStyle(Color(hex: cat.color))
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.matchPattern)
                                    .font(AppFont.mono(13))
                                HStack(spacing: Spacing.xs) {
                                    Text(rule.matchField.displayName)
                                        .font(AppFont.caption())
                                        .foregroundStyle(.secondary)
                                    if let cat = rule.category {
                                        Text("→ \(cat.name)")
                                            .font(AppFont.caption())
                                            .foregroundStyle(Color(hex: cat.color))
                                    }
                                }
                            }

                            Spacer()

                            Button(action: { modelContext.delete(rule) }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.negative)
                        }
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.sm)

                        if rule.id != rules.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .sheet(isPresented: $showingAdd) {
            AddRuleSheet()
        }
    }
}

// MARK: - Add Rule Sheet

private struct AddRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var pattern = ""
    @State private var matchField: MatchField = .label
    @State private var selectedCategory: Category?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Nouvelle regle")
                .font(AppFont.title())

            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("Texte a rechercher (ex: carrefour)", text: $pattern)
                    .textFieldStyle(.roundedBorder)

                Picker("Champ", selection: $matchField) {
                    ForEach(MatchField.allCases) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .frame(maxWidth: 300)

                Picker("Categorie", selection: $selectedCategory) {
                    Text("Aucune").tag(nil as Category?)
                    ForEach(categories) { cat in
                        Label(cat.name, systemImage: cat.icon).tag(cat as Category?)
                    }
                }
                .frame(maxWidth: 300)
            }

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Ajouter") {
                    let rule = AutoCategoryRule(
                        matchPattern: pattern.lowercased(),
                        matchField: matchField,
                        category: selectedCategory
                    )
                    modelContext.insert(rule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(pattern.isEmpty || selectedCategory == nil)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 420)
    }
}

// MARK: - Recurring Transactions Settings

private struct RecurringSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.label) private var recurrings: [RecurringTransaction]

    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Transactions recurrentes")
                    .font(AppFont.heading())
                Spacer()
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }

            if recurrings.isEmpty {
                Text("Aucune transaction recurrente configuree.")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(recurrings) { recurring in
                        HStack(spacing: Spacing.md) {
                            if let cat = recurring.category {
                                Image(systemName: cat.icon)
                                    .foregroundStyle(Color(hex: cat.color))
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "repeat")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(recurring.label)
                                    .font(AppFont.body())
                                HStack(spacing: Spacing.xs) {
                                    Text("Jour \(recurring.dayOfMonth)")
                                        .font(AppFont.caption())
                                        .foregroundStyle(.secondary)
                                    if let cat = recurring.category {
                                        Text(cat.name)
                                            .font(AppFont.caption())
                                            .foregroundStyle(Color(hex: cat.color))
                                    }
                                }
                            }

                            Spacer()

                            Text(recurring.amount.formatted)
                                .font(AppFont.mono())
                                .foregroundStyle(recurring.amount < 0 ? Color.negative : Color.positive)

                            Toggle("", isOn: Binding(
                                get: { recurring.isActive },
                                set: { recurring.isActive = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()

                            Button(action: { modelContext.delete(recurring) }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.negative)
                        }
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.sm)
                        .opacity(recurring.isActive ? 1 : 0.5)

                        if recurring.id != recurrings.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .sheet(isPresented: $showingAdd) {
            AddRecurringSheet()
        }
    }
}

// MARK: - Appearance Enum

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Systeme"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [
            Category.self, Transaction.self, BankAccount.self,
            AutoCategoryRule.self, RecurringTransaction.self,
            MonthlyBudget.self, BudgetAllocation.self, Revenue.self,
        ], inMemory: true)
}
