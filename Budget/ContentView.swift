import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case budget = "Budget"
    case accounts = "Comptes"
    case transactions = "Transactions"
    case analysis = "Analyse"
    case settings = "Réglages"

    var id: String { rawValue }

    /// Items shown in the main sidebar list (excludes settings which has its own slot).
    static var mainItems: [SidebarItem] {
        allCases.filter { $0 != .settings }
    }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .budget: "chart.pie"
        case .accounts: "banknote"
        case .transactions: "list.bullet.rectangle"
        case .analysis: "chart.xyaxis.line"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .dashboard
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if !showingSplash {
                NavigationSplitView {
                    SidebarView(selection: $selectedItem)
                } detail: {
                    detailView(for: selectedItem)
                        .id(selectedItem)
                        .transition(.pageTransition)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedItem)
                }
                .frame(minWidth: 900, minHeight: 600)
                .transition(.opacity)
            }

            if showingSplash {
                SplashScreenView {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingSplash = false
                    }
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .budget:
            BudgetView()
        case .accounts:
            AccountsView()
        case .transactions:
            TransactionsView()
        case .analysis:
            AnalysisView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Page Transition

extension AnyTransition {
    static var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 8))
                .combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Category.self, inMemory: true)
}
