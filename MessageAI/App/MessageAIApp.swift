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
    @StateObject private var services: ServiceResolver

    init() {
        FirebaseApp.configure()
        let localDataManager = try! LocalDataManager(inMemory: true)
        let listener = MessageListenerService(localDataManager: localDataManager)
        let messageService = MessageService(
            localDataManager: localDataManager,
            conversationRepository: ConversationRepository(),
            messageRepository: MessageRepository()
        )
        let currentUserID = AuthenticationService.shared.currentUser?.uid ?? "demo"
        _services = StateObject(wrappedValue: ServiceResolver(
            localDataManager: localDataManager,
            listenerService: listener,
            messageService: messageService,
            currentUserID: currentUserID
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(mainAppBuilder: { MainTabView(services: services) })
        }
    }
}
