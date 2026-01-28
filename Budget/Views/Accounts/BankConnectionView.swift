import SwiftUI
import SwiftData

// MARK: - Enable Banking Setup Sheet

struct BankAPISetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var applicationId = ""
    @State private var privateKey = ""
    @State private var isSaving = false
    @State private var loadFromFile = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Configuration Enable Banking")
                .font(AppFont.title())

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Pour connecter vos comptes bancaires, vous avez besoin d'un compte Enable Banking (gratuit).")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)

                Text("Rendez-vous sur enablebanking.com, creez une application Sandbox et telechargez votre cle privee RSA.")
                    .font(AppFont.caption())
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Application ID")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
                TextField("Ex: abc123-def456...", text: $applicationId)
                    .textFieldStyle(.roundedBorder)

                Text("Cle privee RSA (PEM)")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.sm) {
                    Button("Charger depuis un fichier .pem") {
                        loadFromFile = true
                    }
                    .buttonStyle(.bordered)
                    .fileImporter(isPresented: $loadFromFile, allowedContentTypes: [.data, .text, .plainText]) { result in
                        if case .success(let url) = result {
                            if url.startAccessingSecurityScopedResource() {
                                defer { url.stopAccessingSecurityScopedResource() }
                                if let content = try? String(contentsOf: url, encoding: .utf8) {
                                    privateKey = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                        }
                    }

                    if !privateKey.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.positive)
                        Text("Cle chargee")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.positive)
                    }
                }

                TextEditor(text: $privateKey)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(.quaternary)
                    )
                    .overlay(alignment: .topLeading) {
                        if privateKey.isEmpty {
                            Text("Collez ici le contenu du fichier .pem ou chargez-le...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .allowsHitTesting(false)
                        }
                    }
            }

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Enregistrer") {
                    Task {
                        isSaving = true
                        await EnableBankingClient.shared.configure(
                            applicationId: applicationId.trimmingCharacters(in: .whitespacesAndNewlines),
                            privateKeyPEM: privateKey
                        )
                        isSaving = false
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(applicationId.isEmpty || privateKey.isEmpty || isSaving)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 540)
    }
}

// MARK: - Bank Connection Flow

struct BankConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var institutions: [EBInstitution] = []
    @State private var searchText = ""
    @State private var selectedCountry = "FR"
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedInstitution: EBInstitution?
    @State private var authURL: URL?
    @State private var authCode = ""
    @State private var step: ConnectionStep = .selectBank

    private let countries = [
        ("FR", "France"), ("DE", "Allemagne"), ("ES", "Espagne"),
        ("IT", "Italie"), ("BE", "Belgique"), ("NL", "Pays-Bas"),
        ("FI", "Finlande"), ("PT", "Portugal"), ("AT", "Autriche"),
    ]

    enum ConnectionStep {
        case selectBank
        case authenticate
        case enterCode
        case importing
        case done
    }

    private var filteredInstitutions: [EBInstitution] {
        if searchText.isEmpty { return institutions }
        return institutions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Text(stepTitle)
                    .font(AppFont.title())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            switch step {
            case .selectBank:
                bankSelectionView
            case .authenticate:
                authenticationView
            case .enterCode:
                enterCodeView
            case .importing:
                importingView
            case .done:
                doneView
            }
        }
        .padding(Spacing.xl)
        .frame(width: 520)
        .frame(minHeight: 450)
        .task {
            await loadInstitutions()
        }
    }

    private var stepTitle: String {
        switch step {
        case .selectBank: "Choisir votre banque"
        case .authenticate: "Authentification"
        case .enterCode: "Code d'autorisation"
        case .importing: "Import en cours"
        case .done: "Connexion reussie"
        }
    }

    // MARK: - Step 1: Bank Selection

    @ViewBuilder
    private var bankSelectionView: some View {
        if isLoading {
            ProgressView("Chargement des banques...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            VStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.negative)
                Text(error)
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Reessayer") {
                    Task { await loadInstitutions() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Picker("Pays", selection: $selectedCountry) {
                        ForEach(countries, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .frame(width: 140)
                    .onChange(of: selectedCountry) {
                        Task { await loadInstitutions() }
                    }

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Rechercher une banque...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(.quaternary)
                    )
                }

                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(filteredInstitutions) { institution in
                            Button(action: { selectInstitution(institution) }) {
                                HStack(spacing: Spacing.md) {
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .fill(.quaternary)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if let logo = institution.logo,
                                               let url = URL(string: logo) {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().scaledToFit()
                                                        .frame(width: 28, height: 28)
                                                } placeholder: {
                                                    Image(systemName: "building.columns")
                                                        .foregroundStyle(.secondary)
                                                }
                                            } else {
                                                Image(systemName: "building.columns")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(institution.name)
                                            .font(AppFont.body())
                                            .foregroundStyle(.primary)
                                        if let bic = institution.bic {
                                            Text(bic)
                                                .font(AppFont.caption())
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if institution.beta == true {
                                        Text("Beta")
                                            .font(AppFont.caption())
                                            .foregroundStyle(Color.warning)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.warning.opacity(0.12))
                                            )
                                    }

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .fill(.background)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Authentication

    private var authenticationView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            if isLoading {
                ProgressView("Preparation de la connexion...")
            } else if let authURL {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)

                    Text("Cliquez pour vous authentifier aupres de \(selectedInstitution?.name ?? "votre banque")")
                        .font(AppFont.body())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Link(destination: authURL) {
                        Text("Ouvrir la page d'authentification")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Apres l'authentification, vous serez redirige avec un code. Copiez-le et collez-le a l'etape suivante.")
                        .font(AppFont.caption())
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }

                Button("J'ai termine, saisir le code") {
                    step = .enterCode
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    // MARK: - Step 3: Enter Code

    private var enterCodeView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.md) {
                Image(systemName: "key")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)

                Text("Copiez l'URL complete de la barre d'adresse apres la redirection (ou juste le code).")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("URL ou code d'autorisation", text: $authCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)
                    .onChange(of: authCode) {
                        authCode = extractCode(from: authCode)
                    }

                if !authCode.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.positive)
                        Text("Code: \(authCode)")
                            .font(AppFont.caption())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Connecter") {
                Task { await completeConnection() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authCode.isEmpty)

            Spacer()
        }
    }

    /// Extracts the `code` query parameter if the user pastes a full URL.
    private func extractCode(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("code="),
              let components = URLComponents(string: trimmed),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            return trimmed
        }
        return code
    }

    // MARK: - Step 4: Importing

    private var importingView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView("Import des comptes et transactions...")
            Text("Cela peut prendre quelques instants.")
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Step 5: Done

    private var doneView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.positive)

            Text("Comptes connectes avec succes")
                .font(AppFont.heading())

            Button("Fermer") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            Spacer()
        }
    }

    // MARK: - Actions

    private func loadInstitutions() async {
        isLoading = true
        error = nil
        do {
            institutions = try await EnableBankingClient.shared.listInstitutions(country: selectedCountry)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func selectInstitution(_ institution: EBInstitution) {
        selectedInstitution = institution
        step = .authenticate
        isLoading = true

        Task {
            do {
                let response = try await EnableBankingClient.shared.startAuthorization(
                    institutionName: institution.name,
                    country: institution.country
                )
                authURL = URL(string: response.url)
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                step = .selectBank
                isLoading = false
            }
        }
    }

    private func completeConnection() async {
        step = .importing

        do {
            let session = try await EnableBankingClient.shared.createSession(code: authCode)
            guard let sessionAccounts = session.accounts, !sessionAccounts.isEmpty else {
                error = "Aucun compte trouve."
                step = .selectBank
                return
            }

            let institutionName = selectedInstitution?.name ?? ""

            for sessionAccount in sessionAccounts {
                let details = try? await EnableBankingClient.shared.getAccountDetails(
                    accountUID: sessionAccount.uid
                )

                let accountName = details?.name ?? details?.account_id?.iban ?? "Compte"

                let bankAccount = BankAccount(
                    name: accountName,
                    institution: institutionName,
                    type: .checking,
                    goCardlessRequisitionID: session.session_id,
                    isManual: false
                )
                bankAccount.enableBankingAccountUID = sessionAccount.uid

                if let balanceResp = try? await EnableBankingClient.shared.getAccountBalances(
                    accountUID: sessionAccount.uid
                ),
                   let balance = balanceResp.balances.first,
                   let amount = Decimal(string: balance.balance_amount.amount) {
                    bankAccount.balance = amount
                }

                modelContext.insert(bankAccount)
            }

            try modelContext.save()

            let syncService = BankSyncService()
            await syncService.syncAllAccounts(context: modelContext)

            step = .done
        } catch {
            self.error = error.localizedDescription
            step = .selectBank
        }
    }
}

#Preview {
    BankConnectionSheet()
        .modelContainer(for: BankAccount.self, inMemory: true)
}
