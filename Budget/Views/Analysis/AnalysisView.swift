import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @State private var selectedTab: AnalysisTab = .monthly

    enum AnalysisTab: String, CaseIterable {
        case monthly = "Mensuel"
        case evolution = "Évolution"
        case comparison = "Comparaison"
        case envelopes = "Enveloppes"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("ANALYSE")
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .tracking(1.5)
                        Text("Analyse")
                            .font(AppFont.hero(36))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()

                    // Custom tab bar
                    HStack(spacing: 0) {
                        ForEach(AnalysisTab.allCases, id: \.self) { tab in
                            AnalysisTabButton(
                                title: tab.rawValue,
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
                .staggered(index: 0)

                Group {
                    switch selectedTab {
                    case .monthly:
                        MonthlyAnalysisTab()
                    case .evolution:
                        EvolutionTab()
                    case .comparison:
                        ComparisonTab()
                    case .envelopes:
                        EnvelopesTab()
                    }
                }
                .staggered(index: 1)
            }
            .padding(Spacing.xxl)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
        }
        .background(Color.bgSecondary)
    }
}

// MARK: - Tab Button

private struct AnalysisTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(13))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(
                    isSelected ? Color.gold : (isHovered ? Color.textPrimary : Color.textSecondary)
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.gold.opacity(0.10))
                        : nil
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Monthly Analysis Tab

private struct MonthlyAnalysisTab: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query private var allBudgets: [MonthlyBudget]

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var monthBudgetTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter { t in
            cal.component(.month, from: t.date) == selectedMonth &&
            cal.component(.year, from: t.date) == selectedYear &&
            !(t.category?.excludeFromBudget ?? false)
        }
    }

    private var totalSpent: Decimal {
        monthBudgetTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var currentBudget: MonthlyBudget? {
        allBudgets.first { $0.month == selectedMonth && $0.year == selectedYear }
    }

    private var spendingByCategory: [(category: Category, amount: Decimal)] {
        categories.filter { !$0.excludeFromBudget }.compactMap { cat in
            let amount = monthBudgetTransactions
                .filter { $0.category?.id == cat.id }
                .reduce(Decimal(0)) { $0 + $1.amount }
            guard amount != 0 else { return nil }
            return (category: cat, amount: amount)
        }
        .sorted { $0.amount < $1.amount }
    }

    private var budgetVsActual: [(category: Category, budgeted: Decimal, actual: Decimal)] {
        categories.filter { !$0.excludeFromBudget }.compactMap { cat in
            let budgeted = currentBudget?.allocations
                .first { $0.category?.id == cat.id }?.budgetedAmount ?? 0
            let actual = monthBudgetTransactions
                .filter { $0.category?.id == cat.id }
                .reduce(Decimal(0)) { $0 + $1.amount }
            guard budgeted > 0 || actual != 0 else { return nil }
            return (category: cat, budgeted: budgeted, actual: actual)
        }
    }

    private var topExpenses: [Transaction] {
        Array(monthBudgetTransactions
            .filter { $0.amount < 0 }
            .sorted { $0.amount < $1.amount }
            .prefix(5))
    }

    private var budgetRespectPercent: Double {
        let total = currentBudget?.totalBudgeted ?? 0
        guard total > 0 else { return 0 }
        return Double(truncating: (abs(totalSpent) / total) as NSDecimalNumber)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        var comps = DateComponents()
        comps.month = selectedMonth
        comps.year = selectedYear
        let date = Calendar.current.date(from: comps) ?? Date()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Month navigation
            HStack(spacing: Spacing.md) {
                Button(action: { navigateMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Text(monthLabel)
                    .font(AppFont.heading())
                    .frame(width: 180)
                    .contentTransition(.numericText())

                Button(action: { navigateMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: Spacing.lg) {
                // Donut chart
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Dépenses par catégorie")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)

                    if spendingByCategory.isEmpty {
                        Text("Aucune dépense ce mois.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        Chart(spendingByCategory, id: \.category.id) { item in
                            SectorMark(
                                angle: .value("Montant", abs(Double(truncating: item.amount as NSDecimalNumber))),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(Color(hex: item.category.color))
                            .cornerRadius(4)
                        }
                        .frame(height: 220)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(spendingByCategory, id: \.category.id) { item in
                                HStack(spacing: Spacing.sm) {
                                    Circle()
                                        .fill(Color(hex: item.category.color))
                                        .frame(width: 8, height: 8)
                                    Text(item.category.name)
                                        .font(AppFont.body(13))
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    let absTotalSpent = abs(totalSpent)
                                    let pct = absTotalSpent > 0
                                        ? abs(Double(truncating: (item.amount / absTotalSpent * 100) as NSDecimalNumber))
                                        : 0
                                    Text("\(Int(pct))%")
                                        .font(AppFont.mono(11))
                                        .foregroundStyle(Color.textSecondary)
                                    Text(item.amount.formatted)
                                        .font(AppFont.mono(12))
                                        .foregroundStyle(item.amount > 0 ? Color.positive : Color.textSecondary)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, Spacing.xs)
                                .hoverHighlight()
                            }
                        }
                    }

                    Divider().opacity(0.15)
                    HStack {
                        Text("Total dépensé")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(abs(totalSpent).formatted)
                            .font(AppFont.mono())
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                // Budget utilization + top expenses
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Utilisation du budget")
                            .font(AppFont.heading())
                            .foregroundStyle(Color.textPrimary)

                        if budgetVsActual.isEmpty {
                            Text("Aucun budget configuré.")
                                .font(AppFont.body())
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            Chart(budgetVsActual, id: \.category.id) { item in
                                BarMark(
                                    x: .value("Catégorie", item.category.name),
                                    y: .value("Budget", Double(truncating: item.budgeted as NSDecimalNumber))
                                )
                                .foregroundStyle(.quaternary)
                                .cornerRadius(4)

                                BarMark(
                                    x: .value("Catégorie", item.category.name),
                                    y: .value("Dépense", abs(Double(truncating: item.actual as NSDecimalNumber)))
                                )
                                .foregroundStyle(Color(hex: item.category.color))
                                .cornerRadius(4)
                            }
                            .frame(height: 180)
                        }

                        if currentBudget != nil {
                            HStack {
                                Text("Respect du budget")
                                    .font(AppFont.body())
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                let pct = Int(budgetRespectPercent * 100)
                                Text("\(pct)% utilisé")
                                    .font(AppFont.mono())
                                    .foregroundStyle(
                                        budgetRespectPercent < 0.7 ? Color.positive :
                                        budgetRespectPercent < 1.0 ? Color.warning :
                                        Color.negative
                                    )
                            }
                        }
                    }
                    .card()

                    // Top 5 expenses
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Top 5 dépenses")
                            .font(AppFont.heading())
                            .foregroundStyle(Color.textPrimary)

                        if topExpenses.isEmpty {
                            Text("Aucune dépense.")
                                .font(AppFont.body())
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            ForEach(Array(topExpenses.enumerated()), id: \.element.id) { idx, tx in
                                HStack(spacing: Spacing.sm) {
                                    Text("\(idx + 1)")
                                        .font(AppFont.mono(11))
                                        .foregroundStyle(Color.textSecondary)
                                        .frame(width: 18, height: 18)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.06))
                                        )
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tx.label)
                                            .font(AppFont.body())
                                            .foregroundStyle(Color.textPrimary)
                                            .lineLimit(1)
                                        if let cat = tx.category {
                                            Text(cat.name)
                                                .font(AppFont.caption())
                                                .foregroundStyle(Color(hex: cat.color))
                                        }
                                    }
                                    Spacer()
                                    Text(tx.amount.formatted)
                                        .font(AppFont.mono())
                                        .foregroundStyle(Color.negative)
                                }
                                .padding(.vertical, 2)
                                .hoverHighlight()
                                if idx < topExpenses.count - 1 {
                                    Divider().opacity(0.15)
                                }
                            }
                        }
                    }
                    .card()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func navigateMonth(_ delta: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            var m = selectedMonth + delta
            var y = selectedYear
            if m > 12 { m = 1; y += 1 }
            if m < 1 { m = 12; y -= 1 }
            selectedMonth = m
            selectedYear = y
        }
    }
}

// MARK: - Evolution Tab

private struct EvolutionTab: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query private var allRevenues: [Revenue]

    @State private var periodMonths = 6
    @State private var selectedCategoryId: UUID?

    private var monthlyData: [(label: String, month: Int, year: Int, spent: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<periodMonths).reversed().map { offset in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else {
                return (label: "", month: 0, year: 0, spent: 0)
            }
            let m = cal.component(.month, from: date)
            let y = cal.component(.year, from: date)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMM yy"

            let spent = allTransactions
                .filter { t in
                    cal.component(.month, from: t.date) == m &&
                    cal.component(.year, from: t.date) == y &&
                    !(t.category?.excludeFromBudget ?? false)
                }
                .reduce(0.0) { $0 + Double(truncating: $1.amount as NSDecimalNumber) }

            return (label: formatter.string(from: date), month: m, year: y, spent: abs(spent))
        }
    }

    private var categoryMonthlyData: [(label: String, amount: Double)] {
        guard let catId = selectedCategoryId else { return [] }
        let cal = Calendar.current
        let now = Date()
        return (0..<periodMonths).reversed().map { offset in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else {
                return (label: "", amount: 0)
            }
            let m = cal.component(.month, from: date)
            let y = cal.component(.year, from: date)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMM yy"

            let spent = allTransactions
                .filter { t in
                    cal.component(.month, from: t.date) == m &&
                    cal.component(.year, from: t.date) == y &&
                    t.category?.id == catId &&
                    !(t.category?.excludeFromBudget ?? false)
                }
                .reduce(0.0) { $0 + Double(truncating: $1.amount as NSDecimalNumber) }

            return (label: formatter.string(from: date), amount: abs(spent))
        }
    }

    private var revenueVsExpenses: [(label: String, revenue: Double, expenses: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<periodMonths).reversed().map { offset in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else {
                return (label: "", revenue: 0, expenses: 0)
            }
            let m = cal.component(.month, from: date)
            let y = cal.component(.year, from: date)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "MMM yy"

            let expenses = allTransactions
                .filter { t in
                    cal.component(.month, from: t.date) == m &&
                    cal.component(.year, from: t.date) == y &&
                    !(t.category?.excludeFromBudget ?? false)
                }
                .reduce(0.0) { $0 + Double(truncating: $1.amount as NSDecimalNumber) }

            let revenue = allRevenues
                .filter { $0.month == m && $0.year == y }
                .reduce(0.0) { $0 + Double(truncating: $1.amount as NSDecimalNumber) }

            return (label: formatter.string(from: date), revenue: revenue, expenses: abs(expenses))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Picker("Période", selection: $periodMonths) {
                    Text("6 mois").tag(6)
                    Text("12 mois").tag(12)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack(alignment: .top, spacing: Spacing.lg) {
                // Total spending evolution
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Évolution des dépenses")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)

                    if monthlyData.isEmpty {
                        Text("Pas de données.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        Chart(monthlyData, id: \.label) { item in
                            LineMark(
                                x: .value("Mois", item.label),
                                y: .value("Dépenses", item.spent)
                            )
                            .foregroundStyle(Color.gold)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            AreaMark(
                                x: .value("Mois", item.label),
                                y: .value("Dépenses", item.spent)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [Color.gold.opacity(0.25), Color.gold.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Mois", item.label),
                                y: .value("Dépenses", item.spent)
                            )
                            .foregroundStyle(Color.gold)
                            .symbolSize(30)
                        }
                        .frame(height: 220)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                // Revenue vs Expenses
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Revenus vs Dépenses")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)

                    if revenueVsExpenses.isEmpty {
                        Text("Pas de données.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        Chart(revenueVsExpenses, id: \.label) { item in
                            BarMark(
                                x: .value("Mois", item.label),
                                y: .value("Montant", item.revenue)
                            )
                            .foregroundStyle(Color.positive)
                            .position(by: .value("Type", "Revenus"))
                            .cornerRadius(4)

                            BarMark(
                                x: .value("Mois", item.label),
                                y: .value("Montant", item.expenses)
                            )
                            .foregroundStyle(Color.negative)
                            .position(by: .value("Type", "Dépenses"))
                            .cornerRadius(4)
                        }
                        .chartForegroundStyleScale([
                            "Revenus": Color.positive,
                            "Dépenses": Color.negative,
                        ])
                        .frame(height: 220)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }

            // Per-category evolution
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Évolution par catégorie")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("Catégorie", selection: $selectedCategoryId) {
                        Text("Choisir...").tag(nil as UUID?)
                        ForEach(categories.filter { !$0.excludeFromBudget }) { cat in
                            Text(cat.name).tag(cat.id as UUID?)
                        }
                    }
                    .frame(width: 200)
                }

                if let catId = selectedCategoryId,
                   let cat = categories.first(where: { $0.id == catId }),
                   !categoryMonthlyData.isEmpty {
                    Chart(categoryMonthlyData, id: \.label) { item in
                        BarMark(
                            x: .value("Mois", item.label),
                            y: .value("Dépenses", item.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: cat.color), Color(hex: cat.color).opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                } else {
                    Text("Sélectionnez une catégorie pour voir son évolution.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}

// MARK: - Comparison Tab

private struct ComparisonTab: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allTransactions: [Transaction]

    @State private var monthA: Int = {
        let m = Calendar.current.component(.month, from: Date()) - 1
        return m < 1 ? 12 : m
    }()
    @State private var yearA: Int = {
        let m = Calendar.current.component(.month, from: Date()) - 1
        return m < 1 ? Calendar.current.component(.year, from: Date()) - 1 : Calendar.current.component(.year, from: Date())
    }()
    @State private var monthB: Int = Calendar.current.component(.month, from: Date())
    @State private var yearB: Int = Calendar.current.component(.year, from: Date())

    private func budgetTransactions(month: Int, year: Int) -> [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter { t in
            cal.component(.month, from: t.date) == month &&
            cal.component(.year, from: t.date) == year &&
            !(t.category?.excludeFromBudget ?? false)
        }
    }

    private func totalSpent(month: Int, year: Int) -> Decimal {
        abs(budgetTransactions(month: month, year: year).reduce(Decimal(0)) { $0 + $1.amount })
    }

    private func categorySpending(month: Int, year: Int) -> [UUID: Decimal] {
        var result: [UUID: Decimal] = [:]
        for tx in budgetTransactions(month: month, year: year) {
            if let catId = tx.category?.id {
                result[catId, default: 0] += abs(tx.amount)
            }
        }
        return result
    }

    private var comparisonData: [(category: Category, amountA: Decimal, amountB: Decimal)] {
        let spendA = categorySpending(month: monthA, year: yearA)
        let spendB = categorySpending(month: monthB, year: yearB)
        let allCatIds = Set(spendA.keys).union(spendB.keys)

        return categories
            .filter { allCatIds.contains($0.id) && !$0.excludeFromBudget }
            .map { cat in
                (category: cat, amountA: spendA[cat.id] ?? 0, amountB: spendB[cat.id] ?? 0)
            }
    }

    private func monthLabel(_ month: Int, _ year: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMM yyyy"
        var comps = DateComponents()
        comps.month = month
        comps.year = year
        return formatter.string(from: Calendar.current.date(from: comps) ?? Date()).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Month pickers
            HStack(spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Mois A")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .tracking(0.5)
                    HStack(spacing: Spacing.sm) {
                        Picker("Mois", selection: $monthA) {
                            ForEach(1...12, id: \.self) { m in
                                Text(monthName(m)).tag(m)
                            }
                        }
                        .frame(width: 120)
                        Picker("Année", selection: $yearA) {
                            ForEach((yearB - 2)...(yearB + 1), id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .frame(width: 80)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Mois B")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .tracking(0.5)
                    HStack(spacing: Spacing.sm) {
                        Picker("Mois", selection: $monthB) {
                            ForEach(1...12, id: \.self) { m in
                                Text(monthName(m)).tag(m)
                            }
                        }
                        .frame(width: 120)
                        Picker("Année", selection: $yearB) {
                            ForEach((yearA - 1)...(yearA + 2), id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .frame(width: 80)
                    }
                }

                Spacer()

                // Summary
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    let totalA = totalSpent(month: monthA, year: yearA)
                    let totalB = totalSpent(month: monthB, year: yearB)
                    let diff = totalB - totalA
                    Text("Différence totale")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                    Text(diff.formatted)
                        .font(AppFont.title(24))
                        .foregroundStyle(diff <= 0 ? Color.positive : Color.negative)
                }
            }

            HStack(alignment: .top, spacing: Spacing.lg) {
                // Bar chart comparison
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Comparaison par catégorie")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)

                    if comparisonData.isEmpty {
                        Text("Pas de données pour ces mois.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        let chartData = comparisonData.flatMap { item -> [(cat: String, type: String, amount: Double)] in
                            [
                                (cat: item.category.name, type: monthLabel(monthA, yearA), amount: Double(truncating: item.amountA as NSDecimalNumber)),
                                (cat: item.category.name, type: monthLabel(monthB, yearB), amount: Double(truncating: item.amountB as NSDecimalNumber)),
                            ]
                        }

                        Chart(chartData, id: \.cat) { item in
                            BarMark(
                                x: .value("Catégorie", item.cat),
                                y: .value("Montant", item.amount)
                            )
                            .foregroundStyle(by: .value("Mois", item.type))
                            .cornerRadius(4)
                            .position(by: .value("Mois", item.type))
                        }
                        .frame(height: 250)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                // Detail table
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Détail")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)

                    HStack {
                        Text("Catégorie")
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(monthLabel(monthA, yearA))
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 90, alignment: .trailing)
                        Text(monthLabel(monthB, yearB))
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 90, alignment: .trailing)
                        Text("Diff.")
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    Divider().opacity(0.15)

                    if comparisonData.isEmpty {
                        Text("Aucune donnée.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        ForEach(comparisonData, id: \.category.id) { item in
                            HStack {
                                HStack(spacing: Spacing.sm) {
                                    Circle()
                                        .fill(Color(hex: item.category.color))
                                        .frame(width: 8, height: 8)
                                    Text(item.category.name)
                                        .font(AppFont.body())
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text(item.amountA.formatted)
                                    .font(AppFont.mono(12))
                                    .foregroundStyle(Color.textSecondary)
                                    .frame(width: 90, alignment: .trailing)

                                Text(item.amountB.formatted)
                                    .font(AppFont.mono(12))
                                    .foregroundStyle(Color.textSecondary)
                                    .frame(width: 90, alignment: .trailing)

                                let diff = item.amountB - item.amountA
                                Text(diff.formatted)
                                    .font(AppFont.mono(12))
                                    .foregroundStyle(diff <= 0 ? Color.positive : Color.negative)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                            .hoverHighlight()
                        }

                        Divider().opacity(0.15)
                        let totalA = totalSpent(month: monthA, year: yearA)
                        let totalB = totalSpent(month: monthB, year: yearB)
                        let totalDiff = totalB - totalA
                        HStack {
                            Text("Total")
                                .font(AppFont.heading())
                                .foregroundStyle(Color.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(totalA.formatted)
                                .font(AppFont.mono(12))
                                .bold()
                                .frame(width: 90, alignment: .trailing)
                            Text(totalB.formatted)
                                .font(AppFont.mono(12))
                                .bold()
                                .frame(width: 90, alignment: .trailing)
                            Text(totalDiff.formatted)
                                .font(AppFont.mono(12))
                                .bold()
                                .foregroundStyle(totalDiff <= 0 ? Color.positive : Color.negative)
                                .frame(width: 90, alignment: .trailing)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
        }
    }

    private func monthName(_ m: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.monthSymbols[m - 1].capitalized
    }
}

// MARK: - Envelopes Tab

private struct EnvelopesTab: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query private var allBudgets: [MonthlyBudget]

    @State private var periodMonths = 6

    private struct EnvelopeData: Identifiable {
        let category: Category
        let totalBudgeted: Decimal
        let totalSpent: Decimal
        var surplus: Decimal { totalBudgeted - totalSpent }
        var id: UUID { category.id }
    }

    private var envelopes: [EnvelopeData] {
        let cal = Calendar.current
        let now = Date()

        return categories.filter { !$0.excludeFromBudget }.compactMap { cat in
            var totalBudgeted: Decimal = 0
            var totalSpent: Decimal = 0

            for offset in 0..<periodMonths {
                guard let date = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
                let m = cal.component(.month, from: date)
                let y = cal.component(.year, from: date)

                let budget = allBudgets
                    .first { $0.month == m && $0.year == y }
                let budgeted = budget?.allocations
                    .first { $0.category?.id == cat.id }?.budgetedAmount ?? 0
                totalBudgeted += budgeted

                let spent = abs(allTransactions
                    .filter { t in
                        cal.component(.month, from: t.date) == m &&
                        cal.component(.year, from: t.date) == y &&
                        t.category?.id == cat.id
                    }
                    .reduce(Decimal(0)) { $0 + $1.amount })
                totalSpent += spent
            }

            guard totalBudgeted > 0 || totalSpent > 0 else { return nil }
            return EnvelopeData(category: cat, totalBudgeted: totalBudgeted, totalSpent: totalSpent)
        }
    }

    private var grandTotalBudgeted: Decimal {
        envelopes.reduce(0) { $0 + $1.totalBudgeted }
    }

    private var grandTotalSpent: Decimal {
        envelopes.reduce(0) { $0 + $1.totalSpent }
    }

    private var grandSurplus: Decimal {
        grandTotalBudgeted - grandTotalSpent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Picker("Période", selection: $periodMonths) {
                    Text("3 mois").tag(3)
                    Text("6 mois").tag(6)
                    Text("12 mois").tag(12)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            // Summary cards
            HStack(spacing: Spacing.lg) {
                HeroCard(
                    title: "BUDGET CUMULÉ",
                    value: grandTotalBudgeted.formatted,
                    accent: Color.gold,
                    subtitle: "\(periodMonths) mois",
                    icon: "chart.pie"
                )
                .hoverScale()

                HeroCard(
                    title: "DÉPENSES CUMULÉES",
                    value: grandTotalSpent.formatted,
                    accent: Color.negative,
                    subtitle: "\(periodMonths) mois",
                    icon: "arrow.down.circle"
                )
                .hoverScale()

                HeroCard(
                    title: grandSurplus >= 0 ? "EXCÉDENT CUMULÉ" : "DÉFICIT CUMULÉ",
                    value: grandSurplus.formatted,
                    accent: grandSurplus >= 0 ? Color.positive : Color.negative,
                    subtitle: grandSurplus >= 0 ? "Économisé" : "Dépassement",
                    icon: grandSurplus >= 0 ? "arrow.up.circle" : "exclamationmark.triangle"
                )
                .hoverScale()
            }

            // Envelope table
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Détail par catégorie (\(periodMonths) mois)")
                    .font(AppFont.heading())
                    .foregroundStyle(Color.textPrimary)

                // Header
                HStack {
                    Text("Catégorie")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Budget")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 100, alignment: .trailing)
                    Text("Dépensé")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 100, alignment: .trailing)
                    Text("Solde")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 100, alignment: .trailing)
                    Text("Utilisation")
                        .font(AppFont.label())
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 150, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.sm)
                Divider().opacity(0.15)

                if envelopes.isEmpty {
                    Text("Aucune donnée sur cette période.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                        .padding(.vertical, Spacing.lg)
                } else {
                    ForEach(envelopes) { env in
                        HStack {
                            HStack(spacing: Spacing.sm) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color(hex: env.category.color).opacity(0.12))
                                    Image(systemName: env.category.icon)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(hex: env.category.color))
                                }
                                .frame(width: 22, height: 22)
                                Text(env.category.name)
                                    .font(AppFont.body())
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(env.totalBudgeted.formatted)
                                .font(AppFont.mono(12))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 100, alignment: .trailing)

                            Text(env.totalSpent.formatted)
                                .font(AppFont.mono(12))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 100, alignment: .trailing)

                            Text(env.surplus.formatted)
                                .font(AppFont.mono(12))
                                .foregroundStyle(env.surplus >= 0 ? Color.positive : Color.negative)
                                .frame(width: 100, alignment: .trailing)

                            // Progress
                            let progress = env.totalBudgeted > 0
                                ? Double(truncating: (env.totalSpent / env.totalBudgeted) as NSDecimalNumber)
                                : (env.totalSpent > 0 ? 1.5 : 0)
                            let progressColors: [Color] = progress < 0.7
                                ? [Color.positive, Color(hex: "5BDB7B")]
                                : progress < 1.0
                                    ? [Color.warning, Color(hex: "FFBF3A")]
                                    : [Color.negative, Color(hex: "FF6B5A")]

                            HStack(spacing: Spacing.xs) {
                                GradientProgressBar(
                                    progress: progress,
                                    colors: progressColors,
                                    height: 6
                                )

                                Text("\(Int(progress * 100))%")
                                    .font(AppFont.mono(10))
                                    .foregroundStyle(Color.textSecondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .frame(width: 150)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, Spacing.sm)
                        .hoverHighlight()
                    }

                    Divider().opacity(0.15)
                    HStack {
                        Text("Total")
                            .font(AppFont.heading())
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(grandTotalBudgeted.formatted)
                            .font(AppFont.mono(12))
                            .bold()
                            .frame(width: 100, alignment: .trailing)
                        Text(grandTotalSpent.formatted)
                            .font(AppFont.mono(12))
                            .bold()
                            .frame(width: 100, alignment: .trailing)
                        Text(grandSurplus.formatted)
                            .font(AppFont.mono(12))
                            .bold()
                            .foregroundStyle(grandSurplus >= 0 ? Color.positive : Color.negative)
                            .frame(width: 100, alignment: .trailing)
                        Spacer()
                            .frame(width: 150)
                    }
                    .padding(.horizontal, Spacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: [
            Category.self, Transaction.self, MonthlyBudget.self,
            BudgetAllocation.self, Revenue.self,
        ], inMemory: true)
}
