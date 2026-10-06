//
//  NotificationSchedulingService.swift
//  MyUniDay
//
//  Service abstraction wrapping UNUserNotificationCenter for production execution and testability.
//

import Foundation
import UserNotifications

/// Protocol abstracting system notification scheduling for clean testability.
public protocol NotificationSchedulingServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func registerCategories() async
    func addNotificationRequest(_ request: UNNotificationRequest) async throws
}

/// Live production service interacting directly with `UNUserNotificationCenter`.
public final class LiveNotificationSchedulingService: NotificationSchedulingServiceProtocol {
    public static let shared = LiveNotificationSchedulingService()

    public init() {}

    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func registerCategories() async {
        let category = UNNotificationCategory(
            identifier: AssessmentReminderPayload.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}
