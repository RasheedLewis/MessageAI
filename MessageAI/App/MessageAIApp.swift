//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Rasheed Lewis on 10/21/25.
//

import FirebaseCore
import FirebaseMessaging
import SwiftUI
import UserNotifications
import UIKit

@main
struct MessageAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services: ServiceResolver

    init() {
        FirebaseApp.configure()
        let localDataManager = try! LocalDataManager()
        let conversationRepository = ConversationRepository()
        let messageRepository = MessageRepository()
        let listener = MessageListenerService(localDataManager: localDataManager)
        let userDirectoryService = UserDirectoryService()
        let messageService = MessageService(
            localDataManager: localDataManager,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            userDirectoryService: userDirectoryService
        )
        let currentUserID = AuthenticationService.shared.currentUser?.uid ?? "demo"
        _services = StateObject(wrappedValue: ServiceResolver(
            localDataManager: localDataManager,
            listenerService: listener,
            messageService: messageService,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            userSearchService: UserSearchService(),
            userDirectoryService: userDirectoryService,
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

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let notificationCenter = UNUserNotificationCenter.current()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        notificationCenter.delegate = self
        Messaging.messaging().delegate = self
        requestNotificationAuthorization()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Notifications] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[Notifications] Authorization request failed: \(error.localizedDescription)")
            }

            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("[Notifications] FCM registration token: \(token)")
        Task {
            do {
                try await UserRepository.shared.updateFCMToken(token)
            } catch {
                print("[Notifications] Failed to save FCM token: \(error.localizedDescription)")
            }
        }
    }
}
