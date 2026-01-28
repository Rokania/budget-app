import SwiftUI
import SwiftData

struct RecurringTransactionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.label) private var recurrings: [RecurringTransaction]

    @State private var showingAdd = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Text("Transactions recurrentes")
                    .font(AppFont.title())
                Spacer()
                Button(action: { showingAdd = true }) {
                    Label("Ajouter", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if recurrings.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "repeat")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Aucune transaction recurrente")
                        .font(AppFont.heading())
                    Text("Ajoutez vos depenses fixes (loyer, abonnements...) pour les pre-creer chaque mois.")
                        .font(AppFont.body())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
            } else {
                List {
                    ForEach(recurrings) { recurring in
                        RecurringRowView(recurring: recurring)
                    }
                    .onDelete(perform: deleteRecurrings)
                }
                .listStyle(.plain)
                .frame(minHeight: 300)
            }

            HStack {
                Button("Generer pour ce mois") {
                    let cal = Calendar.current
                    let now = Date()
                    RecurringTransactionService.generateForMonth(
                        month: cal.component(.month, from: now),
                        year: cal.component(.year, from: now),
                        context: modelContext
                    )
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Fermer") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 560)
        .frame(minHeight: 400)
        .sheet(isPresented: $showingAdd) {
            AddRecurringSheet()
        }
    }

    private func deleteRecurrings(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(recurrings[index])
        }
    }
}

// MARK: - Recurring Row

struct RecurringRowView: View {
    @Bindable var recurring: RecurringTransaction

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let category = recurring.category {
                Image(systemName: category.icon)
                    .foregroundStyle(Color(hex: category.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: category.color).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            } else {
                Image(systemName: "repeat")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
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
                    if let acc = recurring.bankAccount {
                        Text("· \(acc.name)")
                            .font(AppFont.caption())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(recurring.amount.formatted)
                .font(AppFont.mono())
                .foregroundStyle(recurring.amount < 0 ? Color.negative : Color.positive)

            Toggle("", isOn: $recurring.isActive)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .opacity(recurring.isActive ? 1 : 0.5)
    }
}

// MARK: - Add Recurring Sheet

struct AddRecurringSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var accounts: [BankAccount]

    @State private var label = ""
    @State private var amountText = ""
    @State private var isExpense = true
    @State private var dayOfMonth = 1
    @State private var selectedCategory: Category?
    @State private var selectedAccount: BankAccount?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Nouvelle recurrence")
                .font(AppFont.title())

            Form {
                TextField("Libelle (ex: Loyer, Netflix)", text: $label)
                TextField("Montant", text: $amountText)
                Toggle("Depense", isOn: $isExpense)

                Stepper("Jour du mois : \(dayOfMonth)", value: $dayOfMonth, in: 1...31)

                Picker("Categorie", selection: $selectedCategory) {
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
                    let recurring = RecurringTransaction(
                        label: label,
                        amount: amount,
                        dayOfMonth: dayOfMonth,
                        category: selectedCategory,
                        bankAccount: selectedAccount
                    )
                    modelContext.insert(recurring)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(label.isEmpty || amountText.isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 440)
    }
}

#Preview {
    RecurringTransactionsSheet()
        .modelContainer(for: [
            RecurringTransaction.self,
            Category.self,
            BankAccount.self,
            Transaction.self,
        ], inMemory: true)
}
