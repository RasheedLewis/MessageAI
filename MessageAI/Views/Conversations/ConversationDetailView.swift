import SwiftUI

struct ConversationDetailView: View {
    let conversationID: String
    let services: ServiceResolver

    var body: some View {
        ChatView(conversationID: conversationID, services: services)
    }
}

#Preview {
    NavigationStack {
        ConversationDetailView(conversationID: "preview", services: ServiceResolver.previewResolver)
    }
}

