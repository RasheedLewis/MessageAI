import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: MessageCategory?

    private let categories: [MessageCategory?] = [nil, .business, .urgent, .fan, .spam]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    button(for: category)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func button(for category: MessageCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            if isSelected {
                selectedCategory = nil
            } else {
                selectedCategory = category
            }
        } label: {
            Text(title(for: category))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
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
}

#Preview {
    CategoryFilterView(selectedCategory: .constant(.business))
        .padding(.vertical)
}

