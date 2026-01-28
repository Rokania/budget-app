import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var accounts: [BankAccount]

    @State private var showingAddAccount = false
    @State private var showingConnectBank = false
    @State private var showingAPISetup = false
    @StateObject private var syncService = BankSyncService()

    private var totalBalance: Decimal {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private var manualAccounts: [BankAccount] {
        accounts.filter(\.isManual)
    }

    private var connectedAccounts: [BankAccount] {
        accounts.filter { !$0.isManual }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("PATRIMOINE")
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .tracking(1.5)
                        Text("Comptes")
                            .font(AppFont.hero(36))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer()

                    HStack(spacing: Spacing.sm) {
                        if syncService.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else if !connectedAccounts.isEmpty {
                            Button(action: {
                                Task { await syncService.syncAllAccounts(context: modelContext) }
                            }) {
                                Label("Synchroniser", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.bordered)
                        }

                        Menu {
                            Button(action: { showingAddAccount = true }) {
                                Label("Compte manuel", systemImage: "pencil")
                            }
                            Button(action: { startBankConnection() }) {
                                Label("Connecter une banque", systemImage: "link")
                            }
                            Divider()
                            Button(action: { showingAPISetup = true }) {
                                Label("Configurer Enable Banking", systemImage: "key")
                            }
                        } label: {
                            Label("Ajouter", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gold)
                    }
                }
                .staggered(index: 0)

                // Total balance hero
                HStack(spacing: Spacing.lg) {

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("SOLDE TOTAL")
                            .font(AppFont.label())
                            .foregroundStyle(Color.textSecondary)
                            .tracking(1.0)
                        Text(totalBalance.formatted)
                            .font(AppFont.hero())
                            .foregroundStyle(Color.gold)
                            .contentTransition(.numericText())
                        Text("\(accounts.count) compte\(accounts.count > 1 ? "s" : "")")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let lastSync = syncService.lastSyncDate {
                        VStack(alignment: .trailing, spacing: Spacing.sm) {
                            Text("Dernière sync")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textSecondary)
                            Text(lastSync, format: .dateTime.hour().minute())
                                .font(AppFont.body())
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .accentGlowCard(Color.gold)
                .staggered(index: 1)

                // Error banner
                if let error = syncService.lastError {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.negative)
                        Text(error)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.negative)
                        Spacer()
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.negative.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .strokeBorder(Color.negative.opacity(0.12), lineWidth: 1)
                            )
                    )
                }

                // Connected accounts
                if !connectedAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(Color.positive)
                                .frame(width: 6, height: 6)
                            Text("Comptes connectés")
                                .font(AppFont.heading())
                                .foregroundStyle(Color.textPrimary)
                        }

                        ForEach(connectedAccounts) { account in
                            AccountRowView(account: account, onDelete: { deleteAccount(account) })
                                .hoverScale(1.01)
                        }
                    }
                }

                // Manual accounts
                if !manualAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Comptes manuels")
                            .font(AppFont.heading())
                            .foregroundStyle(Color.textPrimary)

                        ForEach(manualAccounts) { account in
                            AccountRowView(account: account, onDelete: { deleteAccount(account) })
                                .hoverScale(1.01)
                        }
                    }
                }

                // Empty state
                if accounts.isEmpty {
                    VStack(spacing: Spacing.lg) {
                        ZStack {
                            Circle()
                                .fill(Color.gold.opacity(0.08))
                                .frame(width: 72, height: 72)
                            Image(systemName: "banknote")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.gold.opacity(0.6))
                        }

                        Text("Aucun compte")
                            .font(AppFont.heading())
                            .foregroundStyle(Color.textPrimary)
                        Text("Connectez une banque ou ajoutez un compte manuellement.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: Spacing.md) {
                            Button("Connecter une banque") {
                                startBankConnection()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.gold)

                            Button("Compte manuel") {
                                showingAddAccount = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxxl)
                    .card()
                }
            }
            .padding(Spacing.xxl)
        }
        .background(Color.bgSecondary)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountSheet()
        }
        .sheet(isPresented: $showingAPISetup) {
            BankAPISetupSheet()
        }
        .sheet(isPresented: $showingConnectBank) {
            BankConnectionSheet()
        }
    }

    private func startBankConnection() {
        Task {
            let configured = await EnableBankingClient.shared.isConfigured
            if configured {
                showingConnectBank = true
            } else {
                showingAPISetup = true
            }
        }
    }

    private func deleteAccount(_ account: BankAccount) {
        modelContext.delete(account)
    }
}

// MARK: - Account Row

struct AccountRowView: View {
    let account: BankAccount
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.gold.opacity(0.15), Color.gold.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: account.type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.gold)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: Spacing.xs) {
                    if !account.institution.isEmpty {
                        Text(account.institution)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }
                    if !account.isManual {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.positive)
                                .frame(width: 5, height: 5)
                            Text("Connecté")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.positive)
                        }
                    }
                }
            }

            Spacer()

            Text(account.balance.formatted)
                .font(AppFont.mono(16))
                .foregroundStyle(account.balance >= 0 ? Color.textPrimary : Color.negative)
        }
        .padding(Spacing.md)
        .card()
        .contextMenu {
            if let onDelete {
                Button("Supprimer", role: .destructive, action: onDelete)
            }
        }
    }
}

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var institution = ""
    @State private var type: AccountType = .checking
    @State private var balanceText = ""

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Nouveau compte")
                .font(AppFont.title())

            Form {
                TextField("Nom du compte", text: $name)
                TextField("Établissement", text: $institution)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                TextField("Solde initial", text: $balanceText)
            }
            .formStyle(.grouped)

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Ajouter") {
                    let balance = Decimal(string: balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let account = BankAccount(
                        name: name,
                        institution: institution,
                        type: type,
                        balance: balance
                    )
                    modelContext.insert(account)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gold)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 420)
    }
}

#Preview {
    AccountsView()
        .modelContainer(for: BankAccount.self, inMemory: true)
}
