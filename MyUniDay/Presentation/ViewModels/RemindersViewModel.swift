//
//  RemindersViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel aggregating actionable university reminders from existing data.
//

import Foundation
import Observation

/// ViewModel coordinating the student Reminders screen via Domain Use Cases.
@Observable
@MainActor
public final class RemindersViewModel {
    private let getStudentRemindersUseCase: GetStudentRemindersUseCase
    private let scheduleAssessmentReminderUseCase: ScheduleAssessmentReminderUseCase?

    public private(set) var reminders: [StudentReminderItem] = []
    public var selectedCategory: ReminderCategory = .all
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    public var filteredReminders: [StudentReminderItem] {
        switch selectedCategory {
        case .all:
            return reminders
        case .assessments:
            return reminders.filter { $0.category == .assessments }
        case .classes:
            return reminders.filter { $0.category == .classes }
        case .tasks:
            return reminders.filter { $0.category == .tasks }
        }
    }

    public var urgentCount: Int {
        reminders.filter { $0.isUrgent }.count
    }

    public init(
        getStudentRemindersUseCase: GetStudentRemindersUseCase,
        scheduleAssessmentReminderUseCase: ScheduleAssessmentReminderUseCase? = nil
    ) {
        self.getStudentRemindersUseCase = getStudentRemindersUseCase
        self.scheduleAssessmentReminderUseCase = scheduleAssessmentReminderUseCase
    }

    /// Aggregates reminders across upcoming assessments, classes, preparation items, and tasks.
    public func loadReminders(relativeTo referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            self.reminders = try await getStudentRemindersUseCase.execute(relativeTo: referenceDate)
        } catch {
            self.errorMessage = "Unable to load reminders. Please try again."
        }

        isLoading = false
    }

    /// Requests user authorization for alert, sound, and badge notifications.
    public func requestNotificationAuthorization() async -> Result<Bool, NotificationReminderError> {
        guard let useCase = scheduleAssessmentReminderUseCase else {
            return .failure(.permissionDenied)
        }
        return await useCase.requestAuthorization()
    }

    /// Schedules an urgent assessment reminder notification.
    @discardableResult
    public func scheduleAssessmentReminder(delaySeconds: TimeInterval = 5) async throws -> AssessmentReminderPayload {
        guard let useCase = scheduleAssessmentReminderUseCase else {
            throw NotificationReminderError.schedulingFailed(reason: "Notification service is unavailable.")
        }
        return try await useCase.scheduleReminder(delaySeconds: delaySeconds)
    }
}
