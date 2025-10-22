import SwiftUI

struct ConversationDetailView: View {
    let conversationID: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Conversation detail coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Conversation ID: \(conversationID)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Conversation")
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(conversationID: "preview")
    }
}

