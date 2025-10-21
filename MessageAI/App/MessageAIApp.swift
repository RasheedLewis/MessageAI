//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Rasheed Lewis on 10/21/25.
//

import FirebaseCore
import SwiftUI

@main
struct MessageAIApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(mainAppBuilder: { MainTabView() })
        }
    }
}
