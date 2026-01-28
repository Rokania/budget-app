import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allBudgets: [MonthlyBudget]
    @Query private var allRevenues: [Revenue]
    @Query private var allTransactions: [Transaction]

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showingAddRevenue = false

    // MARK: - Computed

    private var monthLabel: String {
        let components = DateComponents(year: selectedYear, month: selectedMonth)
        guard let date = Calendar.current.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }

    private var currentBudget: MonthlyBudget? {
        allBudgets.first { $0.month == selectedMonth && $0.year == selectedYear }
    }

    private var revenues: [Revenue] {
        allRevenues.filter { $0.month == selectedMonth && $0.year == selectedYear }
    }

    private var totalRevenue: Decimal {
        revenues.reduce(0) { $0 + $1.amount }
    }

    private var monthTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter { t in
            cal.component(.month, from: t.date) == selectedMonth &&
            cal.component(.year, from: t.date) == selectedYear &&
            !(t.category?.excludeFromBudget ?? false)
        }
    }

    private var budgetCategories: [Category] {
        categories
            .filter { !$0.excludeFromBudget }
            .sorted { a, b in
                let budgetA = allocation(for: a)?.budgetedAmount ?? 0
                let budgetB = allocation(for: b)?.budgetedAmount ?? 0
                return budgetA > budgetB
            }
    }

    private func actualSpending(for category: Category) -> Decimal {
        monthTransactions
            .filter { $0.category?.id == category.id }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func allocation(for category: Category) -> BudgetAllocation? {
        currentBudget?.allocations.first { $0.category?.id == category.id }
    }

    private var totalBudgeted: Decimal {
        currentBudget?.totalBudgeted ?? 0
    }

    private var totalActual: Decimal {
        budgetCategories.reduce(Decimal(0)) { $0 + actualSpending(for: $1) }
    }

    private var totalRemaining: Decimal {
        totalBudgeted + totalActual
    }

    private var unbudgeted: Decimal {
        totalRevenue - totalBudgeted
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                monthNavigationHeader.staggered(index: 0)
                summaryCards.staggered(index: 1)
                revenuesSection.staggered(index: 2)
                budgetGrid.staggered(index: 3)
            }
            .padding(Spacing.xxl)
        }
        .background(Color.bgSecondary)
        .sheet(isPresented: $showingAddRevenue) {
            RevenueFormSheet(month: selectedMonth, year: selectedYear)
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationHeader: some View {
        HStack {
            HStack(spacing: Spacing.lg) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Text(monthLabel)
                    .font(AppFont.hero(36))
                    .foregroundStyle(Color.textPrimary)
                    .frame(minWidth: 260)
                    .contentTransition(.numericText())

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Dupliquer le mois précédent") {
                duplicatePreviousMonth()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.lg) {
            HeroCard(
                title: "REVENUS",
                value: totalRevenue.formatted,
                accent: Color.positive,
                subtitle: "\(revenues.count) source\(revenues.count > 1 ? "s" : "")",
                icon: "arrow.up.circle"
            )
            .hoverScale()

            HeroCard(
                title: "BUDGÉTÉ",
                value: totalBudgeted.formatted,
                accent: Color.gold,
                subtitle: totalRevenue > 0
                    ? "\(Int(Double(truncating: (totalBudgeted / totalRevenue * 100) as NSDecimalNumber)))% des revenus"
                    : "–",
                icon: "chart.pie"
            )
            .hoverScale()

            HeroCard(
                title: "DÉPENSÉ",
                value: abs(totalActual).formatted,
                accent: Color.negative,
                subtitle: totalBudgeted > 0
                    ? "\(Int(Double(truncating: (abs(totalActual) / totalBudgeted * 100) as NSDecimalNumber)))% du budget"
                    : "–",
                icon: "arrow.down.circle"
            )
            .hoverScale()

            HeroCard(
                title: "NON BUDGÉTÉ",
                value: unbudgeted.formatted,
                accent: unbudgeted >= 0 ? Color.positive : Color.negative,
                subtitle: "Disponible",
                icon: "banknote"
            )
            .hoverScale()
        }
    }

    // MARK: - Revenues Section

    private var revenuesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Revenus")
                    .font(AppFont.heading())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button(action: { showingAddRevenue = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.gold.opacity(0.12))
                        )
                        .foregroundStyle(Color.gold)
                }
                .buttonStyle(.plain)
            }

            if revenues.isEmpty {
                Text("Aucun revenu configuré pour ce mois.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(revenues) { revenue in
                    HStack {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.positive)
                            Text(revenue.name)
                                .font(AppFont.body())
                                .foregroundStyle(Color.textPrimary)
                        }
                        if revenue.isRecurring {
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Text(revenue.amount.formatted)
                            .font(AppFont.mono())
                            .foregroundStyle(Color.positive)
                        Button(action: { modelContext.delete(revenue) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.xs)
                    .hoverHighlight()
                }

                Divider().opacity(0.15)
                HStack {
                    Text("Total")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(totalRevenue.formatted)
                        .font(AppFont.mono())
                        .foregroundStyle(Color.positive)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Budget Grid

    private var budgetGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Budget")
                .font(AppFont.heading())
                .foregroundStyle(Color.textPrimary)

            // Header
            HStack {
                Text("Catégorie")
                    .font(AppFont.label())
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Budgété")
                    .font(AppFont.label())
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 120, alignment: .trailing)
                Text("Réel")
                    .font(AppFont.label())
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 100, alignment: .trailing)
                Text("Reste")
                    .font(AppFont.label())
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 100, alignment: .trailing)
                Color.clear.frame(width: 120)
            }
            .padding(.horizontal, Spacing.sm)

            Divider().opacity(0.15)

            ForEach(budgetCategories) { category in
                BudgetRowView(
                    category: category,
                    budgeted: allocation(for: category)?.budgetedAmount ?? 0,
                    actual: actualSpending(for: category),
                    onBudgetChanged: { newAmount in
                        updateAllocation(for: category, amount: newAmount)
                    }
                )
            }

            Divider().opacity(0.15)

            // Totals
            HStack {
                Text("Total")
                    .font(AppFont.heading())
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(totalBudgeted.formatted)
                    .font(AppFont.mono())
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 120, alignment: .trailing)
                Text(totalActual.formatted)
                    .font(AppFont.mono())
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 100, alignment: .trailing)
                let remaining = totalRemaining
                Text(remaining.formatted)
                    .font(AppFont.mono())
                    .foregroundStyle(remaining >= 0 ? Color.positive : Color.negative)
                    .frame(width: 100, alignment: .trailing)
                Color.clear.frame(width: 120)
            }
            .padding(.horizontal, Spacing.sm)
        }
        .card()
    }

    // MARK: - Actions

    private func previousMonth() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedMonth == 1 {
                selectedMonth = 12
                selectedYear -= 1
            } else {
                selectedMonth -= 1
            }
        }
    }

    private func nextMonth() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedMonth == 12 {
                selectedMonth = 1
                selectedYear += 1
            } else {
                selectedMonth += 1
            }
        }
    }

    private func ensureBudgetExists() -> MonthlyBudget {
        if let existing = currentBudget {
            return existing
        }
        let budget = MonthlyBudget(month: selectedMonth, year: selectedYear)
        modelContext.insert(budget)
        return budget
    }

    private func updateAllocation(for category: Category, amount: Decimal) {
        let budget = ensureBudgetExists()

        if let existing = budget.allocations.first(where: { $0.category?.id == category.id }) {
            existing.budgetedAmount = amount
        } else {
            let allocation = BudgetAllocation(budgetedAmount: amount, category: category)
            allocation.monthlyBudget = budget
            modelContext.insert(allocation)
        }
    }

    private func duplicatePreviousMonth() {
        var prevMonth = selectedMonth - 1
        var prevYear = selectedYear
        if prevMonth == 0 {
            prevMonth = 12
            prevYear -= 1
        }

        guard let previous = allBudgets.first(where: { $0.month == prevMonth && $0.year == prevYear }) else {
            return
        }

        let budget = ensureBudgetExists()

        for alloc in budget.allocations {
            modelContext.delete(alloc)
        }

        for alloc in previous.allocations {
            let newAlloc = BudgetAllocation(budgetedAmount: alloc.budgetedAmount, category: alloc.category)
            newAlloc.monthlyBudget = budget
            modelContext.insert(newAlloc)
        }

        let prevRevenues = allRevenues.filter { $0.month == prevMonth && $0.year == prevYear && $0.isRecurring }
        let existingRevenueNames = Set(revenues.map(\.name))
        for rev in prevRevenues {
            if !existingRevenueNames.contains(rev.name) {
                let newRev = Revenue(
                    name: rev.name,
                    amount: rev.amount,
                    month: selectedMonth,
                    year: selectedYear,
                    isRecurring: true
                )
                modelContext.insert(newRev)
            }
        }
    }
}

// MARK: - Budget Row

struct BudgetRowView: View {
    let category: Category
    let budgeted: Decimal
    let actual: Decimal
    let onBudgetChanged: (Decimal) -> Void

    @State private var isEditing = false
    @State private var editText = ""

    private var remaining: Decimal { budgeted + actual }

    private var progress: Double {
        guard budgeted > 0 else { return 0 }
        return min(Double(truncating: (abs(actual) / budgeted) as NSDecimalNumber), 1.5)
    }

    private var progressColors: [Color] {
        if progress < 0.7 { return [Color.positive, Color(hex: "5BDB7B")] }
        if progress < 1.0 { return [Color.warning, Color(hex: "FFBF3A")] }
        return [Color.negative, Color(hex: "FF6B5A")]
    }

    var body: some View {
        HStack {
            // Category
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: category.color).opacity(0.12))
                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: category.color))
                }
                .frame(width: 26, height: 26)

                Text(category.name)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Budgeted (editable)
            if isEditing {
                TextField("0", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.mono())
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        let value = Decimal(string: editText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        onBudgetChanged(value)
                        isEditing = false
                    }
            } else {
                Text(budgeted.formatted)
                    .font(AppFont.mono())
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 120, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editText = budgeted == 0 ? "" : "\(budgeted)"
                        isEditing = true
                    }
            }

            // Actual
            Text(actual.formatted)
                .font(AppFont.mono())
                .foregroundStyle(actual > 0 ? Color.positive : Color.textPrimary)
                .frame(width: 100, alignment: .trailing)

            // Remaining
            Text(remaining.formatted)
                .font(AppFont.mono())
                .foregroundStyle(remaining >= 0 ? Color.positive : Color.negative)
                .frame(width: 100, alignment: .trailing)

            // Progress bar
            GradientProgressBar(
                progress: progress,
                colors: progressColors,
                height: 6
            )
            .frame(width: 120)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .hoverHighlight()
    }
}

// MARK: - Progress Bar (legacy, kept for compatibility)

struct ProgressBarView: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(progress, 1.0)))
                    .animation(.easeOut(duration: 0.5), value: progress)
            }
        }
    }
}

// MARK: - Revenue Form Sheet

struct RevenueFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let month: Int
    let year: Int

    @State private var name = ""
    @State private var amountText = ""
    @State private var isRecurring = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Nouveau revenu")
                .font(AppFont.title())

            Form {
                TextField("Nom (ex: Salaire)", text: $name)
                TextField("Montant", text: $amountText)
                Toggle("Récurrent chaque mois", isOn: $isRecurring)
            }
            .formStyle(.grouped)

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Ajouter") {
                    let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let revenue = Revenue(
                        name: name,
                        amount: amount,
                        month: month,
                        year: year,
                        isRecurring: isRecurring
                    )
                    modelContext.insert(revenue)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gold)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || amountText.isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }
}

#Preview {
    BudgetView()
        .modelContainer(for: [
            Category.self,
            MonthlyBudget.self,
            BudgetAllocation.self,
            Revenue.self,
            Transaction.self,
        ], inMemory: true)
}
