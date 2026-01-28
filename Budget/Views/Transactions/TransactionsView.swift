import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var accounts: [BankAccount]
    @Query private var autoRules: [AutoCategoryRule]

    @State private var searchText = ""
    @State private var filterCategory: Category?
    @State private var filterAccount: BankAccount?
    @State private var showExpensesOnly = false
    @State private var filterDateFrom: Date?
    @State private var filterDateTo: Date?
    @State private var useDateFilter = false
    @State private var showingAddTransaction = false
    @State private var showingRecurring = false
    @State private var categorizationTarget: Transaction?
    @State private var selectionMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showingBulkCategorize = false

    private var filteredTransactions: [Transaction] {
        transactions.filter { t in
            if !searchText.isEmpty {
                let matchesSearch = t.label.localizedCaseInsensitiveContains(searchText) ||
                    (t.merchantName?.localizedCaseInsensitiveContains(searchText) ?? false)
                if !matchesSearch { return false }
            }
            if let filterCat = filterCategory {
                if t.category?.id != filterCat.id { return false }
            }
            if let filterAcc = filterAccount {
                if t.bankAccount?.id != filterAcc.id { return false }
            }
            if showExpensesOnly && !t.isExpense { return false }
            if useDateFilter {
                if let from = filterDateFrom, t.date < Calendar.current.startOfDay(for: from) { return false }
                if let to = filterDateTo, t.date > Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to)! { return false }
            }
            return true
        }
    }

    private var uncategorizedCount: Int {
        transactions.filter { $0.category == nil }.count
    }

    private var selectedTransactions: [Transaction] {
        filteredTransactions.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("TRANSACTIONS")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .tracking(1.5)
                    HStack(spacing: Spacing.md) {
                        Text("Transactions")
                            .font(AppFont.hero(36))
                            .foregroundStyle(Color.textPrimary)
                        if uncategorizedCount > 0 {
                            HStack(spacing: Spacing.xs) {
                                Circle()
                                    .fill(Color.warning)
                                    .frame(width: 6, height: 6)
                                Text("\(uncategorizedCount) non catégorisée\(uncategorizedCount > 1 ? "s" : "")")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.warning)
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.warning.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.warning.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }

                Spacer()

                HStack(spacing: Spacing.sm) {
                    Button(action: {
                        selectionMode.toggle()
                        if !selectionMode { selectedIDs.removeAll() }
                    }) {
                        Label(selectionMode ? "Terminé" : "Sélectionner", systemImage: selectionMode ? "checkmark.circle" : "checkmark.circle.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showingRecurring = true }) {
                        Label("Récurrentes", systemImage: "repeat")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showingAddTransaction = true }) {
                        Label("Ajouter", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gold)
                }
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.lg)
            .staggered(index: 0)

            // Filters bar
            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.textSecondary)
                        .font(.system(size: 13))
                    TextField("Rechercher...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(AppFont.body())
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 300)

                Picker("Catégorie", selection: $filterCategory) {
                    Text("Toutes les catégories").tag(nil as Category?)
                    ForEach(categories) { cat in
                        Label(cat.name, systemImage: cat.icon).tag(cat as Category?)
                    }
                }
                .frame(maxWidth: 200)

                if !accounts.isEmpty {
                    Picker("Compte", selection: $filterAccount) {
                        Text("Tous les comptes").tag(nil as BankAccount?)
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(acc as BankAccount?)
                        }
                    }
                    .frame(maxWidth: 180)
                }

                Toggle("Dépenses", isOn: $showExpensesOnly)
                    .toggleStyle(.checkbox)

                Divider()
                    .frame(height: 20)

                Toggle("Période", isOn: $useDateFilter)
                    .toggleStyle(.checkbox)

                if useDateFilter {
                    DatePicker("Du", selection: Binding(
                        get: { filterDateFrom ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())! },
                        set: { filterDateFrom = $0 }
                    ), displayedComponents: .date)
                    .frame(maxWidth: 180)

                    DatePicker("Au", selection: Binding(
                        get: { filterDateTo ?? Date() },
                        set: { filterDateTo = $0 }
                    ), displayedComponents: .date)
                    .frame(maxWidth: 180)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.md)
            .staggered(index: 1)

            // Bulk action bar
            if selectionMode {
                HStack(spacing: Spacing.md) {
                    Button(action: toggleSelectAll) {
                        Label(
                            selectedIDs.count == filteredTransactions.count ? "Tout désélectionner" : "Tout sélectionner",
                            systemImage: selectedIDs.count == filteredTransactions.count ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    .buttonStyle(.bordered)

                    if !selectedIDs.isEmpty {
                        Text("\(selectedIDs.count) sélectionnée\(selectedIDs.count > 1 ? "s" : "")")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)

                        Spacer()

                        Button(action: { showingBulkCategorize = true }) {
                            Label("Catégoriser", systemImage: "tag")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive, action: deleteSelected) {
                            Label("Supprimer", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.md)
            }

            Divider().opacity(0.15)
                .staggered(index: 2)

            // List
            if filteredTransactions.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.textSecondary.opacity(0.3))
                    Text("Aucune transaction")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)
                    Text(searchText.isEmpty ? "Ajoutez votre première transaction." : "Aucun résultat pour cette recherche.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredTransactions) { transaction in
                        HStack(spacing: Spacing.sm) {
                            if selectionMode {
                                Button(action: { toggleSelection(transaction.id) }) {
                                    Image(systemName: selectedIDs.contains(transaction.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(selectedIDs.contains(transaction.id) ? Color.gold : Color.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }

                            TransactionRowView(
                                transaction: transaction,
                                onCategorize: { categorizationTarget = transaction }
                            )
                        }
                        .contextMenu {
                            transactionContextMenu(transaction)
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
                .listStyle(.plain)
            }
        }
        .background(Color.bgSecondary)
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionSheet(onSave: applyAutoRules)
        }
        .sheet(isPresented: $showingRecurring) {
            RecurringTransactionsSheet()
        }
        .sheet(item: $categorizationTarget) { transaction in
            CategorizationSheet(transaction: transaction)
        }
        .sheet(isPresented: $showingBulkCategorize) {
            BulkCategorizationSheet(transactions: selectedTransactions) {
                selectedIDs.removeAll()
                selectionMode = false
            }
        }
    }

    @ViewBuilder
    private func transactionContextMenu(_ transaction: Transaction) -> some View {
        Menu("Catégoriser") {
            ForEach(categories) { cat in
                Button(action: {
                    transaction.category = cat
                }) {
                    Label(cat.name, systemImage: cat.icon)
                }
            }
        }

        Divider()

        Button("Supprimer", role: .destructive) {
            modelContext.delete(transaction)
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredTransactions[index])
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        if selectedIDs.count == filteredTransactions.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(filteredTransactions.map(\.id))
        }
    }

    private func deleteSelected() {
        for transaction in selectedTransactions {
            modelContext.delete(transaction)
        }
        selectedIDs.removeAll()
    }

    private func applyAutoRules(transaction: Transaction) {
        if transaction.category == nil {
            if let category = AutoCategorizationService.categorize(
                transaction: transaction,
                rules: autoRules
            ) {
                transaction.category = category
            }
        }
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: Transaction
    var onCategorize: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Category icon
            Button(action: { onCategorize?() }) {
                if let category = transaction.category {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color(hex: category.color).opacity(0.12))
                        Image(systemName: category.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: category.color))
                    }
                    .frame(width: 34, height: 34)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.warning.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .strokeBorder(Color.warning.opacity(0.2), lineWidth: 1)
                            )
                        Image(systemName: "tag")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.warning)
                    }
                    .frame(width: 34, height: 34)
                }
            }
            .buttonStyle(.plain)
            .help(transaction.category != nil ? "Modifier la catégorie" : "Catégoriser cette transaction")

            // Label & details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.label)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    if let merchant = transaction.merchantName, !merchant.isEmpty {
                        Text(merchant)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }
                    if let category = transaction.category {
                        Text(category.name)
                            .font(AppFont.caption())
                            .foregroundStyle(Color(hex: category.color))
                    } else {
                        Text("Non catégorisée")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.warning)
                    }
                    if let account = transaction.bankAccount {
                        Text("·")
                            .foregroundStyle(Color.textSecondary)
                        Text(account.name)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            Spacer()

            // Date
            Text(transaction.date, format: .dateTime.day().month(.abbreviated))
                .font(AppFont.caption())
                .foregroundStyle(Color.textSecondary)

            // Amount
            Text(transaction.amount.formatted)
                .font(AppFont.mono())
                .foregroundStyle(transaction.isExpense ? Color.negative : Color.positive)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var accounts: [BankAccount]

    var onSave: ((Transaction) -> Void)?

    @State private var label = ""
    @State private var merchantName = ""
    @State private var amountText = ""
    @State private var isExpense = true
    @State private var selectedCategory: Category?
    @State private var selectedAccount: BankAccount?
    @State private var date = Date()

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Nouvelle transaction")
                .font(AppFont.title())

            Form {
                TextField("Libellé", text: $label)
                TextField("Nom du marchand (optionnel)", text: $merchantName)
                TextField("Montant", text: $amountText)
                Toggle("Dépense", isOn: $isExpense)
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Picker("Catégorie", selection: $selectedCategory) {
                    Text("Aucune").tag(nil as Category?)
                    ForEach(categories) { cat in
                        Label(cat.name, systemImage: cat.icon).tag(cat as Category?)
                    }
                }

                if !accounts.isEmpty {
                    Picker("Compte", selection: $selectedAccount) {
                        Text("Aucun").tag(nil as BankAccount?)
                        ForEach(accounts) { acc in
                            Text(acc.name).tag(acc as BankAccount?)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Ajouter") {
                    let rawAmount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let amount = isExpense ? -abs(rawAmount) : abs(rawAmount)
                    let transaction = Transaction(
                        amount: amount,
                        label: label,
                        merchantName: merchantName.isEmpty ? nil : merchantName,
                        date: date,
                        category: selectedCategory,
                        bankAccount: selectedAccount
                    )
                    modelContext.insert(transaction)
                    onSave?(transaction)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gold)
                .keyboardShortcut(.defaultAction)
                .disabled(label.isEmpty || amountText.isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 440)
    }
}

// MARK: - Categorization Sheet

struct CategorizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    let transaction: Transaction

    @State private var createRule = false
    @State private var hoveredCategory: UUID?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Catégoriser")
                .font(AppFont.title())

            VStack(spacing: Spacing.sm) {
                Text(transaction.label)
                    .font(AppFont.heading())
                    .foregroundStyle(Color.textPrimary)
                Text(transaction.amount.formatted)
                    .font(AppFont.mono())
                    .foregroundStyle(transaction.isExpense ? Color.negative : Color.positive)
                if let merchant = transaction.merchantName {
                    Text(merchant)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .card()

            // Category grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3), spacing: Spacing.sm) {
                ForEach(categories) { cat in
                    Button(action: { assignCategory(cat) }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: cat.icon)
                                .foregroundStyle(Color(hex: cat.color))
                            Text(cat.name)
                                .font(AppFont.body())
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(Color(hex: cat.color).opacity(
                                    hoveredCategory == cat.id ? 0.15 : 0.06
                                ))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .strokeBorder(
                                    Color(hex: cat.color).opacity(
                                        hoveredCategory == cat.id ? 0.4 : 0.15
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .scaleEffect(hoveredCategory == cat.id ? 1.02 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hoveredCategory)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredCategory = isHovered ? cat.id : nil
                    }
                }
            }

            Toggle("Toujours catégoriser ainsi", isOn: $createRule)
                .font(AppFont.body())

            Button("Annuler") { dismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(Spacing.xl)
        .frame(width: 480)
    }

    private func assignCategory(_ category: Category) {
        transaction.category = category
        if createRule {
            AutoCategorizationService.createRule(
                from: transaction,
                category: category,
                context: modelContext
            )
        }
        dismiss()
    }
}

// MARK: - Bulk Categorization Sheet

struct BulkCategorizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    let transactions: [Transaction]
    var onDone: (() -> Void)?

    @State private var createRule = false
    @State private var hoveredCategory: UUID?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Catégoriser \(transactions.count) transaction\(transactions.count > 1 ? "s" : "")")
                .font(AppFont.title())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3), spacing: Spacing.sm) {
                ForEach(categories) { cat in
                    Button(action: { assignCategory(cat) }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: cat.icon)
                                .foregroundStyle(Color(hex: cat.color))
                            Text(cat.name)
                                .font(AppFont.body())
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(Color(hex: cat.color).opacity(
                                    hoveredCategory == cat.id ? 0.15 : 0.06
                                ))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .strokeBorder(
                                    Color(hex: cat.color).opacity(
                                        hoveredCategory == cat.id ? 0.4 : 0.15
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .scaleEffect(hoveredCategory == cat.id ? 1.02 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hoveredCategory)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredCategory = isHovered ? cat.id : nil
                    }
                }
            }

            Toggle("Créer des règles automatiques", isOn: $createRule)
                .font(AppFont.body())

            Button("Annuler") { dismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(Spacing.xl)
        .frame(width: 480)
    }

    private func assignCategory(_ category: Category) {
        for transaction in transactions {
            transaction.category = category
            if createRule {
                AutoCategorizationService.createRule(
                    from: transaction,
                    category: category,
                    context: modelContext
                )
            }
        }
        dismiss()
        onDone?()
    }
}

extension Transaction: Identifiable {}

#Preview {
    TransactionsView()
        .modelContainer(for: [
            Transaction.self,
            Category.self,
            BankAccount.self,
            AutoCategoryRule.self,
            RecurringTransaction.self,
        ], inMemory: true)
}
