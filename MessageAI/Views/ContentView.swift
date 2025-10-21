import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("MessageAI Home")
                    .font(.largeTitle.bold())

                Text("The core messaging experience will appear here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                NavigationLink("Open Conversations") {
                    Text("Conversation list placeholder")
                        .font(.headline)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    ContentView()
}

