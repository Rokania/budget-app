import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showingAdd = false
    @State private var editingCategory: Category?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Categories")
                    .font(AppFont.heading())
                Spacer()
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }

            if categories.isEmpty {
                Text("Aucune categorie.")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(categories) { category in
                        HStack(spacing: Spacing.md) {
                            Image(systemName: category.icon)
                                .foregroundStyle(Color(hex: category.color))
                                .frame(width: 24)

                            Text(category.name)
                                .font(AppFont.body())

                            if category.isDefault {
                                Text("Par defaut")
                                    .font(AppFont.caption())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(.quaternary)
                                    )
                            }

                            if category.excludeFromBudget {
                                Text("Hors budget")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.warning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.warning.opacity(0.10))
                                    )
                            }

                            Spacer()

                            Button(action: { editingCategory = category }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Button(action: { deleteCategory(category) }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.negative)
                        }
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.sm)

                        if category.id != categories.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .sheet(isPresented: $showingAdd) {
            CategoryFormSheet(category: nil)
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormSheet(category: category)
        }
    }

    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
    }
}

// MARK: - Category Form Sheet

struct CategoryFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: Category?

    @State private var name = ""
    @State private var icon = "folder.fill"
    @State private var color = "#0A84FF"
    @State private var excludeFromBudget = false

    private var isEditing: Bool { category != nil }

    private let availableIcons = [
        "cart.fill", "house.fill", "car.fill", "heart.fill",
        "gamecontroller.fill", "bag.fill", "repeat", "fork.knife",
        "banknote.fill", "book.fill", "airplane", "ellipsis.circle.fill",
        "gift.fill", "wifi", "phone.fill", "tv.fill",
        "tshirt.fill", "drop.fill", "bolt.fill", "leaf.fill",
        "pawprint.fill", "figure.walk", "music.note", "film",
    ]

    private let availableColors = [
        "#0A84FF", "#30D158", "#FF9F0A", "#FF453A",
        "#BF5AF2", "#FF375F", "#64D2FF", "#FFD60A",
        "#AC8E68", "#5E5CE6", "#FF6482", "#A2845E",
    ]

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text(isEditing ? "Modifier la categorie" : "Nouvelle categorie")
                .font(AppFont.title())

            // Preview
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(Color(hex: color))
                    .font(.system(size: 20))
                Text(name.isEmpty ? "Nom" : name)
                    .font(AppFont.heading())
                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(.quaternary)
            )

            TextField("Nom de la categorie", text: $name)
                .textFieldStyle(.roundedBorder)

            // Icon picker
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Icone")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: Spacing.sm), count: 8), spacing: Spacing.sm) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Image(systemName: iconName)
                            .font(.system(size: 16))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(icon == iconName ? Color(hex: color).opacity(0.2) : .clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .strokeBorder(icon == iconName ? Color(hex: color) : .clear, lineWidth: 1.5)
                            )
                            .onTapGesture { icon = iconName }
                    }
                }
            }

            Toggle("Exclure du budget", isOn: $excludeFromBudget)
                .font(AppFont.body())

            // Color picker
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Couleur")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
                HStack(spacing: Spacing.sm) {
                    ForEach(availableColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: color == hex ? 2 : 0)
                            )
                            .shadow(color: color == hex ? Color(hex: hex).opacity(0.5) : .clear, radius: 4)
                            .onTapGesture { color = hex }
                    }
                }
            }

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Enregistrer" : "Ajouter") {
                    if let category {
                        category.name = name
                        category.icon = icon
                        category.color = color
                        category.excludeFromBudget = excludeFromBudget
                    } else {
                        let maxOrder = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
                        let newCategory = Category(
                            name: name,
                            icon: icon,
                            color: color,
                            isDefault: false,
                            sortOrder: maxOrder,
                            excludeFromBudget: excludeFromBudget
                        )
                        modelContext.insert(newCategory)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 420)
        .onAppear {
            if let category {
                name = category.name
                icon = category.icon
                color = category.color
                excludeFromBudget = category.excludeFromBudget
            }
        }
    }
}

extension Category: Identifiable {}
