import SwiftUI
import SwiftData
import Sparkle

// MARK: - Check For Updates View (Menu Command)

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Rechercher des mises a jour...", action: checkForUpdatesViewModel.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

@main
struct BudgetApp: App {
    let container: ModelContainer
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        let schema = Schema([
            BankAccount.self,
            Wallet.self,
            Category.self,
            MonthlyBudget.self,
            BudgetAllocation.self,
            Revenue.self,
            Transaction.self,
            RecurringTransaction.self,
            AutoCategoryRule.self,
        ])

        let configuration = ModelConfiguration(
            "Budget",
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        seedDefaultCategories(container: container)
    }

    @AppStorage("appearance") private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Settings {
            SettingsView(updater: updaterController.updater)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
    }

    private func seedDefaultCategories(container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Category>()

        guard let count = try? context.fetchCount(descriptor), count == 0 else {
            return
        }

        let defaults: [(String, String, String, Int)] = [
            ("Alimentation", "cart.fill", "#0A84FF", 0),
            ("Loyer", "house.fill", "#5E5CE6", 1),
            ("Transport", "car.fill", "#FF9F0A", 2),
            ("Sante", "heart.fill", "#FF453A", 3),
            ("Loisirs", "gamecontroller.fill", "#BF5AF2", 4),
            ("Shopping", "bag.fill", "#FF375F", 5),
            ("Abonnements", "repeat", "#64D2FF", 6),
            ("Restaurants", "fork.knife", "#FFD60A", 7),
            ("Epargne", "banknote.fill", "#30D158", 8),
            ("Education", "book.fill", "#AC8E68", 9),
            ("Voyages", "airplane", "#FF6482", 10),
            ("Autres", "ellipsis.circle.fill", "#A2845E", 11),
        ]

        for (name, icon, color, order) in defaults {
            let category = Category(
                name: name,
                icon: icon,
                color: color,
                isDefault: true,
                sortOrder: order
            )
            context.insert(category)
        }

        try? context.save()
    }
}
