# Budget App — Progression

## Phase 1 — Fondations
- [x] Setup projet SwiftUI + SwiftData + XcodeGen
- [x] Modeles de donnees (SwiftData)
- [x] Navigation (sidebar + layout principal)
- [x] Systeme de theme (dark/light)
- [x] App entry point avec container SwiftData (local, CloudKit differe)
- [ ] ~~Sign in with Apple~~ (necessite Apple Developer Program — differe)

## Phase 2 — Budget core
- [x] Gestion des categories (CRUD + defauts)
- [x] Gestion des revenus mensuels
- [x] Creation et edition du budget mensuel
- [x] Vue budget : grille budgetise / reel
- [x] Duplication de budget mois precedent

## Phase 3 — Transactions
- [x] Saisie manuelle de transactions
- [x] Liste de transactions avec filtres et recherche
- [x] Categorisation manuelle
- [x] Auto-categorisation (regles)
- [x] Transactions recurrentes (definition + pre-creation)

## Phase 4 — Connexion bancaire
- [x] Integration Enable Banking (auth + import) *(migration depuis GoCardless)*
- [x] Sync automatique des transactions
- [x] Matching transactions importees / recurrentes
- [x] Gestion reconnexion
- [x] Configuration API (Application ID + cle RSA via Keychain)

## Phase 5 — Dashboard & Analyse
- [x] Dashboard (vue d'accueil)
- [x] Analyse mensuelle detaillee
- [x] Evolution temporelle
- [x] Comparaison entre mois
- [x] Vue enveloppes cumulees

## Phase 6 — Polish
- [x] Parametres complets
- [x] Export CSV
- [x] Animations et polish UI
- [ ] Tests et stabilisation
