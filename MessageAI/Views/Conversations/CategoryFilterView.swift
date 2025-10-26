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
            Text(title(for: category))
                .font(.theme.bodyMedium)
                .foregroundStyle(isSelected ? Color.theme.textOnPrimary : Color.theme.textOnSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.theme.secondary : Color.theme.surface.opacity(0.8))
                )
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        countBadge(count, isSelected: isSelected)
                            .offset(x: 10, y: -8)
                    }
                }
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

    private func countBadge(_ count: Int, isSelected: Bool) -> some View {
        Text("\(count)")
            .font(.theme.captionMedium)
            .foregroundStyle(isSelected ? Color.theme.textOnPrimary : Color.theme.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isSelected ? Color.theme.secondary.opacity(0.9) : Color.theme.surface)
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
}

#Preview {
    CategoryFilterView(
        selectedCategory: .constant(.business),
        counts: [.business: 3, nil: 10],
        uncategorizedCount: 2
    )
        .padding(.vertical)
}

