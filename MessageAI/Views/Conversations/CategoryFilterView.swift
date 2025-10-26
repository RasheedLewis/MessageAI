import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: MessageCategory?
    let counts: [MessageCategory?: Int]
    let uncategorizedCount: Int

    private let categories: [MessageCategory?] = [nil, .business, .urgent, .fan, .spam]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    button(for: category)
                }
                if uncategorizedCount > 0 {
                    uncategorizedBadge
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func button(for category: MessageCategory?) -> some View {
        let isSelected = selectedCategory == category
        let count = counts[category] ?? 0
        return Button {
            if isSelected {
                selectedCategory = nil
            } else {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 8) {
                if let category {
                    Image(systemName: icon(for: category))
                        .font(.system(size: 15, weight: .medium))
                }

                Text(title(for: category))
                    .font(Font.custom("Inter-Medium", size: 15))
            }
            .foregroundStyle(isSelected ? Color.white : AppColors.filterInactiveText)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? selectionColor(for: category) : AppColors.filterInactiveBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? selectionColor(for: category) : AppColors.filterInactiveBorder, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    countBadge(count, isSelected: isSelected, tint: selectionColor(for: category))
                        .offset(x: 10, y: -8)
                }
            }
            .opacity(isSelected ? 1.0 : 0.9)
        }
        .buttonStyle(.plain)
    }

    private func title(for category: MessageCategory?) -> String {
        switch category {
        case nil:
            return "All"
        case .fan:
            return "Fan"
        case .business:
            return "Business"
        case .spam:
            return "Spam"
        case .urgent:
            return "Urgent"
        case .general:
            return "General"
        }
    }

    private func countBadge(_ count: Int, isSelected: Bool, tint: Color) -> some View {
        Text("\(count)")
            .font(.theme.captionMedium)
            .foregroundStyle(isSelected ? Color.white : tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(0.9) : AppColors.filterInactiveBackground)
            )
    }

    private var uncategorizedBadge: some View {
        HStack(spacing: 6) {
            Text("Categorizing...")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnSurface.opacity(0.7))
            Text("\(uncategorizedCount)")
                .font(.theme.captionMedium)
                .foregroundStyle(Color.theme.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.theme.surface.opacity(0.8))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .stroke(Color.theme.surface.opacity(0.5))
        )
    }

    private func selectionColor(for category: MessageCategory?) -> Color {
        guard let category else {
            return Color.theme.secondary
        }

        switch category {
        case .fan:
            return Color(red: 0.28, green: 0.78, blue: 0.46)
        case .business:
            return Color(red: 0.29, green: 0.54, blue: 0.96)
        case .spam:
            return Color(red: 0.58, green: 0.63, blue: 0.70)
        case .urgent:
            return Color(red: 0.95, green: 0.33, blue: 0.31)
        case .general:
            return Color.theme.primary
        }
    }

    private func icon(for category: MessageCategory) -> String {
        switch category {
        case .fan:
            return "heart.fill"
        case .business:
            return "briefcase.fill"
        case .spam:
            return "exclamationmark.triangle.fill"
        case .urgent:
            return "bolt.fill"
        case .general:
            return "bubble.left.fill"
        }
    }
}

#Preview {
    CategoryFilterView(
        selectedCategory: .constant(.business),
        counts: [.business: 3, nil: 10],
        uncategorizedCount: 2
    )
        .padding(.vertical)
}

