# PRD — Budget App (macOS)

## 1. Vision

Application macOS native de gestion de budget personnel. L'utilisateur budgétise mois par mois ses revenus et dépenses par catégories, connecte ses comptes bancaires pour importer automatiquement ses transactions, et analyse ses finances via un dashboard analytique. Design moderne, épuré, inspiré de Finary.

---

## 2. Utilisateurs cibles

- Usage personnel (1 compte = 1 utilisateur)
- Chaque utilisateur a ses propres comptes bancaires, budgets et données
- Distribution initiale privée, potentiellement open source ou Mac App Store à terme

---

## 3. Stack technique

| Couche | Choix |
|---|---|
| UI | SwiftUI (macOS natif, minimum macOS 14 Sonoma) |
| Architecture | MVVM |
| Stockage local | SwiftData (Core Data moderne) |
| Backend / Sync | CloudKit (sync iCloud natif, gratuit, pas de serveur à gérer) |
| Auth | Sign in with Apple (natif, intégré à CloudKit, zéro friction) |
| Connexion bancaire | Enable Banking (open banking gratuit, API REST + JWT RS256) |
| Graphiques | Swift Charts (framework natif Apple) |
| Réseau | URLSession natif |

> **Note sur l'auth** : Sign in with Apple est trivial à implémenter avec CloudKit. L'utilisateur se connecte avec son Apple ID, CloudKit gère le reste. Pas besoin d'email/mdp.

---

## 4. Architecture des données

### 4.1 Modèles principaux

```
User
├── id: UUID
├── appleUserID: String
└── createdAt: Date

BankAccount
├── id: UUID
├── name: String                    // "Compte courant BNP"
├── institution: String             // "BNP Paribas"
├── type: AccountType               // .checking, .savings, .investment
├── balance: Decimal
├── goCardlessRequisitionID: String? // nil si compte manuel
├── isManual: Bool
└── user → User

Wallet
├── id: UUID
├── name: String                    // "Tickets Restaurant"
├── monthlyAllowance: Decimal       // Rechargement mensuel
├── currentBalance: Decimal
├── allowedCategories: [Category]   // Catégories éligibles
└── user → User

Category
├── id: UUID
├── name: String                    // "Alimentation", "Loyer"
├── icon: String                    // SF Symbol name
├── color: String                   // Hex color
├── isDefault: Bool                 // Catégorie prédéfinie vs custom
├── sortOrder: Int
└── user → User

MonthlyBudget
├── id: UUID
├── month: Int                      // 1-12
├── year: Int
├── user → User
└── allocations: [BudgetAllocation]

BudgetAllocation
├── id: UUID
├── budgetedAmount: Decimal         // Montant alloué
├── category → Category
└── monthlyBudget → MonthlyBudget

Revenue
├── id: UUID
├── name: String                    // "Salaire", "Freelance"
├── amount: Decimal
├── month: Int
├── year: Int
├── isRecurring: Bool
└── user → User

Transaction
├── id: UUID
├── amount: Decimal                 // Négatif = dépense, Positif = revenu
├── label: String                   // Libellé bancaire ou saisi
├── merchantName: String?
├── date: Date
├── category → Category?
├── bankAccount → BankAccount
├── wallet → Wallet?               // Si payé via ticket resto etc.
├── isManual: Bool
├── goCardlessTransactionID: String?
└── user → User

RecurringTransaction
├── id: UUID
├── label: String                   // "Loyer", "Netflix"
├── amount: Decimal
├── category → Category
├── bankAccount → BankAccount
├── dayOfMonth: Int                 // Jour du mois attendu
├── isActive: Bool
└── user → User

AutoCategoryRule
├── id: UUID
├── matchPattern: String            // "carrefour", "netflix"
├── matchField: MatchField          // .merchantName, .label
├── category → Category
└── user → User
```

### 4.2 Enums

```swift
enum AccountType: String, Codable {
    case checking    // Compte courant
    case savings     // Livret / Épargne
    case investment  // PEA, Assurance-vie
}

enum MatchField: String, Codable {
    case merchantName
    case label
}
```

### 4.3 Catégories par défaut

| Catégorie | Icône SF Symbol |
|---|---|
| Alimentation | cart.fill |
| Loyer | house.fill |
| Transport | car.fill |
| Santé | heart.fill |
| Loisirs | gamecontroller.fill |
| Shopping | bag.fill |
| Abonnements | repeat |
| Restaurants | fork.knife |
| Épargne | banknote.fill |
| Éducation | book.fill |
| Voyages | airplane |
| Autres | ellipsis.circle.fill |

---

## 5. Fonctionnalités détaillées

### 5.1 Onboarding

1. Sign in with Apple
2. Création du premier compte bancaire (connexion Enable Banking ou manuel)
3. Configuration du budget du premier mois (revenus + allocations par catégorie)
4. Optionnel : configuration d'un wallet Tickets Restaurant

### 5.2 Budget mensuel

**Vue principale : grille budgetisé / réel**

```
┌─────────────────────────────────────────────────────┐
│  Janvier 2026                        ◀  ▶          │
├─────────────────────────────────────────────────────┤
│  REVENUS                                            │
│  Salaire                          3 200,00 €        │
│  Freelance                          500,00 €        │
│  ──────────────────────────────────────────          │
│  Total revenus                    3 700,00 €        │
│                                                     │
│  DÉPENSES            Budgeté    Réel     Reste      │
│  Loyer               900,00    900,00      0,00     │
│  Alimentation        400,00    312,45     87,55     │
│  Transport           150,00    178,30    -28,30  ⚠  │
│  Abonnements          80,00     79,99      0,01     │
│  Loisirs             200,00    145,00     55,00     │
│  ...                                                │
│  ──────────────────────────────────────────          │
│  Total dépenses    2 100,00  1 850,74    249,26     │
│                                                     │
│  SOLDE DISPONIBLE              1 849,26 €           │
│  Non budgété                     700,00 €           │
└─────────────────────────────────────────────────────┘
```

- Chaque mois repart à zéro (pas de report d'enveloppes)
- Barre de progression visuelle par catégorie (vert → orange → rouge)
- Indicateur visuel quand le réel dépasse le budgété
- Possibilité de dupliquer le budget du mois précédent
- Édition inline des montants budgétés

### 5.3 Comptes bancaires

- Liste des comptes avec solde actuel
- Connexion via Enable Banking API
- Ajout manuel de comptes
- Rafraîchissement automatique des transactions (toutes les 6h)
- Rafraîchissement manuel à la demande
- Vue consolidée (tous comptes) + vue par compte

### 5.4 Wallet (Tickets Restaurant)

- Solde dédié rechargé automatiquement chaque mois (montant configurable)
- Ne peut être affecté qu'à des catégories définies (ex: Alimentation, Restaurants)
- Lors de la catégorisation d'une transaction éligible, possibilité de "payer" via le wallet
- Le solde du wallet se déduit séparément du budget principal
- Historique d'utilisation visible dans l'analyse

### 5.5 Transactions

- Liste chronologique avec recherche et filtres (catégorie, compte, date, montant)
- Catégorisation manuelle par drag & drop ou sélection
- Auto-catégorisation via règles (AutoCategoryRule)
  - Quand l'utilisateur catégorise une transaction, proposition : "Toujours catégoriser [marchand] en [catégorie] ?"
  - Gestion des règles dans les paramètres
- Saisie manuelle de transactions
- Transactions récurrentes :
  - Définition (label, montant, catégorie, jour du mois)
  - Pré-création automatique en début de mois (marquées "attendue")
  - Matching automatique avec les transactions importées
  - Alerte si une récurrente n'est pas détectée après J+3

### 5.6 Dashboard (vue d'accueil)

Le dashboard est l'écran affiché à l'ouverture de l'app.

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  Solde total            Budget du mois    Reste à        │
│  4 523,80 €             2 100 / 3 700 €   dépenser       │
│  ↗ +234 vs mois dernier ████████░░░ 57%   1 600,00 €    │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────────────────┐  │
│  │ Dépenses du mois │  │ Budget vs Réel (barres)      │  │
│  │ par catégorie     │  │                              │  │
│  │ [donut chart]     │  │ Loyer      ████████████ 100% │  │
│  │                   │  │ Alim.      ██████░░░░░  62%  │  │
│  │                   │  │ Transport  █████████████ 119% │  │
│  │                   │  │ ...                          │  │
│  └──────────────────┘  └──────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ Dernières transactions                               │ │
│  │ Aujourd'hui                                          │ │
│  │   Carrefour Market     Alimentation     -45,30 €     │ │
│  │   SNCF                 Transport        -23,00 €     │ │
│  │ Hier                                                 │ │
│  │   Spotify              Abonnements      -10,99 €     │ │
│  └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### 5.7 Analyse

**Vues analytiques disponibles :**

#### a) Vue mensuelle détaillée
- Répartition des dépenses par catégorie (donut chart)
- Budget vs Réel par catégorie (bar chart horizontal, barres juxtaposées)
- Top 5 des plus grosses dépenses du mois
- Taux de respect du budget par catégorie (% utilisé)

#### b) Évolution temporelle
- Courbe d'évolution des dépenses totales sur 6/12 mois
- Courbe d'évolution par catégorie sur 6/12 mois
- Évolution du solde global (tous comptes)
- Évolution des revenus vs dépenses (bar chart empilé mois par mois)

#### c) Comparaison
- Comparer deux mois côte à côte (toutes catégories)
- Moyenne mensuelle par catégorie sur la période sélectionnée
- Écart par rapport à la moyenne (quels mois ont été plus/moins dépensiers)

#### d) Enveloppes cumulées (vue informative)
- Même si chaque mois repart à zéro, cette vue affiche le cumul des excédents/dépassements par catégorie sur N mois
- Permet de voir si sur la durée on dépense plus ou moins que prévu
- Ex: "Alimentation : budgété 2 400 € sur 6 mois, dépensé 2 180 € → excédent cumulé de 220 €"

#### e) Wallet / Tickets Restaurant
- Utilisation mensuelle du wallet
- Solde restant en fin de mois
- Répartition par catégorie (Alimentation vs Restaurants)

### 5.8 Paramètres

- Gestion des catégories (ajout, édition, suppression, réordonnement)
- Gestion des comptes bancaires (ajout, suppression, reconnexion Enable Banking)
- Gestion des wallets
- Gestion des règles d'auto-catégorisation
- Gestion des transactions récurrentes
- Apparence (dark/light, dark par défaut)
- Données : export CSV, suppression du compte

---

## 6. Navigation (layout)

```
┌─────────────────────────────────────────────────┐
│ ┌───────────┐ ┌───────────────────────────────┐ │
│ │           │ │                               │ │
│ │  SIDEBAR  │ │       CONTENU PRINCIPAL       │ │
│ │           │ │                               │ │
│ │  Dashboard│ │                               │ │
│ │  Budget   │ │                               │ │
│ │  Comptes  │ │                               │ │
│ │  Trans.   │ │                               │ │
│ │  Analyse  │ │                               │ │
│ │           │ │                               │ │
│ │           │ │                               │ │
│ │  ─────    │ │                               │ │
│ │  Réglages │ │                               │ │
│ └───────────┘ └───────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

- Sidebar à gauche, fond sombre, icônes + labels
- Zone de contenu principale, fond clair (ou sombre selon le mode)
- Navigation par section, pas de tabs imbriqués
- Toolbar contextuelle en haut du contenu principal (mois picker, filtres, actions)

---

## 7. Design

### Principes
- Pas d'emoji, jamais
- Pas de gradients
- Couleurs solides, palette restreinte
- Typographie système (SF Pro) avec hiérarchie claire
- Espacement généreux, contenu aéré
- Cartes avec coins arrondis et ombres subtiles (light mode) ou bordures fines (dark mode)
- Icônes : SF Symbols exclusivement
- Animations subtiles (transitions entre mois, apparition des données)

### Palette de couleurs

| Rôle | Light mode | Dark mode |
|---|---|---|
| Background principal | #FFFFFF | #1C1C1E |
| Background secondaire | #F2F2F7 | #2C2C2E |
| Sidebar | #F7F7F7 | #161618 |
| Texte principal | #1C1C1E | #FFFFFF |
| Texte secondaire | #8E8E93 | #8E8E93 |
| Accent / Primaire | #0A84FF | #0A84FF |
| Positif (revenus, excédent) | #30D158 | #30D158 |
| Négatif (dépassement) | #FF453A | #FF453A |
| Avertissement | #FF9F0A | #FF9F0A |

### Couleurs des catégories
Chaque catégorie a une couleur attribuée, utilisée dans les graphiques et les badges. Palette de 12 couleurs distinctes, non dégradées, inspirée du système Apple :

`#0A84FF` `#30D158` `#FF9F0A` `#FF453A` `#BF5AF2` `#FF375F` `#64D2FF` `#FFD60A` `#AC8E68` `#5E5CE6` `#FF6482` `#A2845E`

---

## 8. Intégration Enable Banking

### Flux de connexion
1. L'utilisateur configure son Application ID et sa clé privée RSA (obtenue sur enablebanking.com, gratuit)
2. L'utilisateur clique "Connecter un compte bancaire"
3. Sélection de la banque dans la liste des institutions disponibles (filtrées par pays FR)
4. L'app démarre une autorisation via l'API Enable Banking → génère une URL d'authentification
5. L'utilisateur s'authentifie sur le site de sa banque (ouverture dans le navigateur)
6. L'utilisateur copie le code d'autorisation reçu et le saisit dans l'app
7. L'app crée une session Enable Banking et importe les comptes disponibles

### Sync des transactions
- Import des transactions via l'API Enable Banking (par compte)
- Refresh manuel possible
- Les transactions importées sont dédupliquées via leur ID Enable Banking
- Les transactions récurrentes sont matchées automatiquement par montant + période

### Authentification API
- JWT RS256 généré côté client avec la clé privée RSA de l'utilisateur
- Application ID et clé privée stockés dans le Keychain macOS
- Pas besoin de serveur intermédiaire (authentification directe depuis l'app)
- Compte Enable Banking gratuit (inscription sur enablebanking.com)

---

## 9. Sync CloudKit

### Stratégie
- Chaque modèle est un record CloudKit dans la zone privée de l'utilisateur
- Sync automatique via SwiftData + CloudKit (NSPersistentCloudKitContainer)
- Résolution de conflits : last-write-wins (suffisant pour un usage mono-utilisateur)
- Les données restent disponibles hors ligne (stockage local SwiftData)
- Sync transparente quand la connexion revient

### Avantages
- Aucun serveur à gérer
- Gratuit (dans les limites Apple, largement suffisant)
- Backup automatique des données via iCloud
- Fonctionne sur plusieurs Mac avec le même Apple ID

---

## 10. Phases de développement

### Phase 1 — Fondations
- Setup projet SwiftUI + SwiftData
- Modèles de données
- Navigation (sidebar + layout)
- Système de thème (dark/light)
- Sign in with Apple + CloudKit

### Phase 2 — Budget core
- Gestion des catégories (CRUD + défauts)
- Gestion des revenus mensuels
- Création et édition du budget mensuel
- Vue budget : grille budgetisé / réel
- Duplication de budget mois précédent

### Phase 3 — Transactions
- Saisie manuelle de transactions
- Liste de transactions avec filtres et recherche
- Catégorisation manuelle
- Auto-catégorisation (règles)
- Transactions récurrentes (définition + pré-création)

### Phase 4 — Connexion bancaire
- Intégration Enable Banking (auth + import)
- Sync automatique des transactions
- Matching transactions importées / récurrentes
- Gestion reconnexion

### Phase 5 — Dashboard & Analyse
- Dashboard (vue d'accueil)
- Vues analytiques (mensuelle, évolution, comparaison, enveloppes)
- Swift Charts pour tous les graphiques

### Phase 6 — Wallets & Polish
- Système de wallets (Tickets Restaurant)
- Paramètres complets
- Export CSV
- Animations et polish UI
- Tests et stabilisation
