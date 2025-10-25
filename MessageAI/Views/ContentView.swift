import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("MessageAI Home")
                    .font(.theme.display)

                Text("The core messaging experience will appear here.")
                    .multilineTextAlignment(.center)
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.textOnSurface.opacity(0.7))

                NavigationLink("Open Conversations") {
                    Text("Conversation list placeholder")
                        .font(.theme.subhead)
                        .padding()
                }
                .buttonStyle(.primaryThemed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color.theme.primary)
        }
    }
}

#Preview {
    ContentView()
}

