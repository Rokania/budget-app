import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Environment(\.colorScheme) private var colorScheme

    @State private var brandingAppeared = false
    @State private var itemsAppeared = false
    @State private var settingsAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            // App branding
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.gold, Color.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.gold.opacity(0.3), radius: 8, y: 2)

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                }

                Text("Budget")
                    .font(AppFont.title(20))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
            .opacity(brandingAppeared ? 1 : 0)
            .offset(y: brandingAppeared ? 0 : -10)
            .scaleEffect(brandingAppeared ? 1 : 0.9, anchor: .leading)

            // Nav items
            VStack(spacing: Spacing.xs) {
                ForEach(Array(SidebarItem.mainItems.enumerated()), id: \.element.id) { index, item in
                    SidebarRow(
                        item: item,
                        isSelected: selection == item
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = item
                        }
                    }
                    .opacity(itemsAppeared ? 1 : 0)
                    .offset(x: itemsAppeared ? 0 : -20)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.75)
                            .delay(Double(index) * 0.06),
                        value: itemsAppeared
                    )
                }
            }
            .padding(.horizontal, Spacing.sm)

            Spacer()

            // Settings button
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.15)
                    .padding(.horizontal, Spacing.lg)

                SidebarSettingsRow(isSelected: selection == .settings)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = .settings
                        }
                    }
                    .padding(.vertical, Spacing.sm)
            }
            .opacity(settingsAppeared ? 1 : 0)
            .offset(y: settingsAppeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                brandingAppeared = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.1)) {
                itemsAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                settingsAppeared = true
            }
        }
        .background(
            ZStack {
                Color.bgSidebar
                // Subtle gradient overlay at top
                LinearGradient(
                    colors: [
                        Color.gold.opacity(colorScheme == .dark ? 0.03 : 0.02),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        )
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Active indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.gold : .clear)
                .frame(width: 3, height: 18)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

            Image(systemName: item.icon)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? Color.gold
                        : isHovered ? Color.textPrimary : Color.textSecondary
                )
                .frame(width: 20)

            Text(item.rawValue)
                .font(AppFont.body(isSelected ? 14 : 13.5))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(
                    isSelected
                        ? Color.gold
                        : isHovered ? Color.textPrimary : Color.textSecondary
                )

            Spacer()
        }
        .padding(.trailing, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color.gold.opacity(colorScheme == .dark ? 0.10 : 0.08))
                    .transition(.opacity)
            } else if isHovered {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.03))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Row

private struct SidebarSettingsRow: View {
    var isSelected = false
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.gold : .clear)
                .frame(width: 3, height: 18)

            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? Color.gold
                        : isHovered ? Color.textPrimary : Color.textSecondary
                )
                .frame(width: 20)
            Text("Réglages")
                .font(AppFont.body(isSelected ? 14 : 13.5))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(
                    isSelected
                        ? Color.gold
                        : isHovered ? Color.textPrimary : Color.textSecondary
                )

            Spacer()
        }
        .padding(.trailing, Spacing.md)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color.gold.opacity(colorScheme == .dark ? 0.10 : 0.08))
                    .transition(.opacity)
            } else if isHovered {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.03))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
}
