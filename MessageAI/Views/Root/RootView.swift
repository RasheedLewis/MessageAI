import SwiftUI

struct RootView<MainAppView: View>: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    private let mainAppBuilder: () -> MainAppView

    init(mainAppBuilder: @escaping () -> MainAppView) {
        self.mainAppBuilder = mainAppBuilder
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoginView(viewModel: viewModel)
            case .needsProfileSetup:
                ProfileSetupView(viewModel: viewModel)
            case .authenticated:
                mainAppBuilder()
            }
        }
        .animation(.easeInOut, value: viewModel.state)
    }
}

extension RootView where MainAppView == ContentView {
    static var `default`: RootView {
        RootView(mainAppBuilder: { ContentView() })
    }
}

#Preview {
    RootView.default
}

