import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query private var allBudgets: [MonthlyBudget]
    @Query private var allRevenues: [Revenue]
    @Query private var accounts: [BankAccount]

    private let currentMonth = Calendar.current.component(.month, from: Date())
    private let currentYear = Calendar.current.component(.year, from: Date())

    // MARK: - Computed

    private var totalBalance: Decimal {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private var currentBudget: MonthlyBudget? {
        allBudgets.first { $0.month == currentMonth && $0.year == currentYear }
    }

    private var totalBudgeted: Decimal {
        currentBudget?.totalBudgeted ?? 0
    }

    private var monthBudgetTransactions: [Transaction] {
        let cal = Calendar.current
        return allTransactions.filter { t in
            cal.component(.month, from: t.date) == currentMonth &&
            cal.component(.year, from: t.date) == currentYear &&
            !(t.category?.excludeFromBudget ?? false)
        }
    }

    private var monthIncome: Decimal {
        let cal = Calendar.current
        return allTransactions
            .filter { t in
                cal.component(.month, from: t.date) == currentMonth &&
                cal.component(.year, from: t.date) == currentYear &&
                t.amount > 0
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var totalSpent: Decimal {
        // Raw sum: negative for expenses, positive for income
        monthBudgetTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var remainingBudget: Decimal {
        totalBudgeted + totalSpent
    }

    private var previousMonthSpent: Decimal {
        let cal = Calendar.current
        var prevMonth = currentMonth - 1
        var prevYear = currentYear
        if prevMonth == 0 { prevMonth = 12; prevYear -= 1 }
        return allTransactions
            .filter { t in
                cal.component(.month, from: t.date) == prevMonth &&
                cal.component(.year, from: t.date) == prevYear &&
                !(t.category?.excludeFromBudget ?? false)
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
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

    private var recentTransactions: [Transaction] {
        Array(allTransactions
            .sorted { $0.date > $1.date }
            .prefix(8))
    }

    private var budgetProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return Double(truncating: (abs(totalSpent) / totalBudgeted) as NSDecimalNumber)
    }

    private var spendingDelta: Decimal {
        guard previousMonthSpent != 0 else { return 0 }
        // Both are raw sums (negative = net expenses), compare their magnitude
        return abs(totalSpent) - abs(previousMonthSpent)
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header.staggered(index: 0)
                heroCards.staggered(index: 1)
                chartsRow.staggered(index: 2)
                recentTransactionsSection.staggered(index: 3)
            }
            .padding(Spacing.xxl)
        }
        .background(Color.bgSecondary)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: totalSpent)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(monthName)
                .font(AppFont.caption())
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(1.5)
            Text("Dashboard")
                .font(AppFont.hero(36))
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Hero Cards

    private var heroCards: some View {
        HStack(spacing: Spacing.lg) {
            HeroCard(
                title: "SOLDE TOTAL",
                value: totalBalance.formatted,
                accent: Color.gold,
                subtitle: "\(accounts.count) compte\(accounts.count > 1 ? "s" : "")",
                icon: "building.columns"
            )
            .hoverScale()

            HeroCard(
                title: "DÉPENSÉ CE MOIS",
                value: abs(totalSpent).formatted,
                accent: Color.negative,
                subtitle: deltaText,
                icon: "arrow.down.circle"
            )
            .hoverScale()

            HeroCard(
                title: "RESTE À DÉPENSER",
                value: remainingBudget.formatted,
                accent: remainingBudget >= 0 ? Color.positive : Color.negative,
                subtitle: totalBudgeted > 0
                    ? "\(Int(budgetProgress * 100))% du budget"
                    : "Aucun budget",
                icon: "wallet.pass"
            )
            .hoverScale()

            HeroCard(
                title: "REVENUS",
                value: monthIncome.formatted,
                accent: Color.positive,
                subtitle: "Ce mois",
                icon: "arrow.up.circle"
            )
            .hoverScale()
        }
    }

    private var deltaText: String {
        guard previousMonthSpent != 0 else { return "Pas de données" }
        let delta = spendingDelta
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(delta.formatted) vs mois dernier"
    }

    // MARK: - Charts Row

    private var chartsRow: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            // Donut chart
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Dépenses par catégorie")
                    .font(AppFont.heading())
                    .foregroundStyle(Color.textPrimary)

                if spendingByCategory.isEmpty {
                    emptyChartPlaceholder("Aucune dépense ce mois.")
                } else {
                    Chart(spendingByCategory, id: \.category.id) { item in
                        SectorMark(
                            angle: .value("Montant", abs(Double(truncating: item.amount as NSDecimalNumber))),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: item.category.color))
                        .cornerRadius(4)
                    }
                    .chartBackground { proxy in
                        GeometryReader { geo in
                            if let frame = proxy.plotFrame {
                                let center = CGPoint(
                                    x: geo[frame].midX,
                                    y: geo[frame].midY
                                )
                                VStack(spacing: 2) {
                                    Text(abs(totalSpent).formatted)
                                        .font(AppFont.title(18))
                                        .foregroundStyle(Color.textPrimary)
                                    Text("total")
                                        .font(AppFont.caption())
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .position(center)
                            }
                        }
                    }
                    .frame(height: 220)

                    // Legend
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(spendingByCategory.prefix(6), id: \.category.id) { item in
                            HStack(spacing: Spacing.sm) {
                                Circle()
                                    .fill(Color(hex: item.category.color))
                                    .frame(width: 8, height: 8)
                                Text(item.category.name)
                                    .font(AppFont.body(13))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text(item.amount.formatted)
                                    .font(AppFont.mono(12))
                                    .foregroundStyle(item.amount > 0 ? Color.positive : Color.textSecondary)
                            }
                            .hoverHighlight()
                            .padding(.vertical, 2)
                            .padding(.horizontal, Spacing.xs)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            // Budget vs Real
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack {
                    Text("Budget vs Réel")
                        .font(AppFont.heading())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if totalBudgeted > 0 {
                        Text("\(Int(budgetProgress * 100))%")
                            .font(AppFont.mono(14))
                            .foregroundStyle(budgetProgress > 1 ? Color.negative : Color.gold)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill((budgetProgress > 1 ? Color.negative : Color.gold).opacity(0.1))
                            )
                    }
                }

                if budgetVsActual.isEmpty {
                    emptyChartPlaceholder("Aucun budget configuré.")
                } else {
                    // Global progress bar
                    if totalBudgeted > 0 {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text("Global")
                                    .font(AppFont.label())
                                    .foregroundStyle(Color.textSecondary)
                                Spacer()
                                Text("\(abs(totalSpent).formatted) / \(totalBudgeted.formatted)")
                                    .font(AppFont.mono(11))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            GradientProgressBar(
                                progress: budgetProgress,
                                colors: [Color.gold, Color.goldLight],
                                height: 8,
                                showGlow: true
                            )
                        }
                        .padding(.bottom, Spacing.sm)
                    }

                    VStack(spacing: Spacing.sm) {
                        ForEach(budgetVsActual, id: \.category.id) { item in
                            BudgetComparisonRow(
                                name: item.category.name,
                                color: Color(hex: item.category.color),
                                budgeted: item.budgeted,
                                actual: abs(item.actual)
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func emptyChartPlaceholder(_ text: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28))
                .foregroundStyle(Color.textSecondary.opacity(0.4))
            Text(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionHeader(
                title: "Dernières transactions",
                trailing: "\(recentTransactions.count) récentes"
            )

            if recentTransactions.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textSecondary.opacity(0.4))
                    Text("Aucune transaction.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            } else {
                ForEach(recentTransactions) { tx in
                    HStack(spacing: Spacing.md) {
                        // Icon circle
                        ZStack {
                            Circle()
                                .fill(
                                    tx.category != nil
                                        ? Color(hex: tx.category!.color).opacity(0.12)
                                        : Color.white.opacity(0.06)
                                )
                            Image(systemName: tx.category?.icon ?? "questionmark.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    tx.category != nil
                                        ? Color(hex: tx.category!.color)
                                        : Color.textSecondary
                                )
                        }
                        .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.label)
                                .font(AppFont.body())
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                            if let cat = tx.category {
                                Text(cat.name)
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }

                        Spacer()

                        Text(tx.date, format: .dateTime.day().month(.abbreviated))
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)

                        Text(tx.amount.formatted)
                            .font(AppFont.mono(14))
                            .foregroundStyle(tx.amount >= 0 ? Color.positive : Color.textPrimary)
                            .frame(width: 110, alignment: .trailing)
                    }
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.xs)
                    .hoverHighlight()

                    if tx.id != recentTransactions.last?.id {
                        Divider()
                            .opacity(0.15)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Hero Card

struct HeroCard: View {
    let title: String
    let value: String
    let accent: Color
    let subtitle: String
    var icon: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(AppFont.label())
                    .foregroundStyle(Color.textSecondary)
                    .tracking(0.8)
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent.opacity(0.6))
                }
            }

            Text(value)
                .font(AppFont.title(28))
                .foregroundStyle(accent)
                .contentTransition(.numericText())

            Text(subtitle)
                .font(AppFont.caption())
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accentGlowCard(accent)
    }
}

// MARK: - Budget Comparison Row

private struct BudgetComparisonRow: View {
    let name: String
    let color: Color
    let budgeted: Decimal
    let actual: Decimal

    private var progress: Double {
        guard budgeted > 0 else { return actual > 0 ? 1.5 : 0 }
        return Double(truncating: (actual / budgeted) as NSDecimalNumber)
    }

    private var progressColors: [Color] {
        if progress < 0.7 { return [Color.positive, Color(hex: "5BDB7B")] }
        if progress < 1.0 { return [Color.warning, Color(hex: "FFBF3A")] }
        return [Color.negative, Color(hex: "FF6B5A")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                Text("\(actual.formatted) / \(budgeted.formatted)")
                    .font(AppFont.mono(11))
                    .foregroundStyle(Color.textSecondary)
            }
            GradientProgressBar(
                progress: progress,
                colors: progressColors,
                height: 6
            )
        }
        .hoverHighlight()
        .padding(.vertical, 2)
        .padding(.horizontal, Spacing.xs)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [
            Category.self, Transaction.self, MonthlyBudget.self,
            BudgetAllocation.self, Revenue.self, BankAccount.self,
        ], inMemory: true)
}
