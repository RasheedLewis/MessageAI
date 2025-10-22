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
        let conversationRepository = ConversationRepository()
        let messageRepository = MessageRepository()
        let listener = MessageListenerService(localDataManager: localDataManager)
        let messageService = MessageService(
            localDataManager: localDataManager,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
        let currentUserID = AuthenticationService.shared.currentUser?.uid ?? "demo"
        _services = StateObject(wrappedValue: ServiceResolver(
            localDataManager: localDataManager,
            listenerService: listener,
            messageService: messageService,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            userSearchService: UserSearchService(),
            groupAvatarService: GroupAvatarService(),
            currentUserID: currentUserID
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(mainAppBuilder: { MainTabView(services: services) })
        }
    }
}
