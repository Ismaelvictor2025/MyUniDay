//
//  ScheduleAssessmentReminderUseCase.swift
//  MyUniDay
//
//  Domain use case coordinating the creation, serialization, and scheduling of
//  urgent assessment reminders with the MYUNIDAY_ASSESSMENT_REMINDER category.
//

import Foundation
import UserNotifications

/// User-facing errors for notification reminder scheduling with student-friendly descriptions.
public enum NotificationReminderError: LocalizedError, Equatable {
    case permissionDenied
    case noIncompleteAssessments
    case schedulingFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notifications are turned off. Enable them in Settings if you'd like MyUniDay to remind you about upcoming assessments."
        case .noIncompleteAssessments:
            return "No incomplete assessments found to schedule a reminder for."
        case .schedulingFailed(let reason):
            return "Unable to schedule reminder: \(reason)"
        }
    }
}

/// Gathers the highest-priority incomplete coursework and schedules a rich local notification.
public final class ScheduleAssessmentReminderUseCase: Sendable {
    private let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    private let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase
    private let subjectRepository: SubjectRepositoryProtocol
    private let notificationService: NotificationSchedulingServiceProtocol

    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase,
        subjectRepository: SubjectRepositoryProtocol,
        notificationService: NotificationSchedulingServiceProtocol = LiveNotificationSchedulingService.shared
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
        self.subjectRepository = subjectRepository
        self.notificationService = notificationService
    }

    /// Requests user authorization for alert, sound, and badge notifications.
    public func requestAuthorization() async -> Result<Bool, NotificationReminderError> {
        do {
            let granted = try await notificationService.requestAuthorization()
            if granted {
                await notificationService.registerCategories()
                return .success(true)
            } else {
                return .failure(.permissionDenied)
            }
        } catch {
            return .failure(.permissionDenied)
        }
    }

    /// Registers the custom UNNotificationCategory with the system notification center.
    public func registerCategory() async {
        await notificationService.registerCategories()
    }

    /// Constructs the payload for the target or top incomplete assessment and schedules the local notification.
    @discardableResult
    public func scheduleReminder(
        for targetAssessment: Assessment? = nil,
        delaySeconds: TimeInterval = 5,
        relativeTo referenceDate: Date = Date()
    ) async throws -> AssessmentReminderPayload {
        // 1. Resolve candidate assessment
        let assessment: Assessment
        if let target = targetAssessment {
            guard !target.isCompleted else {
                throw NotificationReminderError.noIncompleteAssessments
            }
            assessment = target
        } else {
            let priorityList = try await getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)
            guard let top = priorityList.first(where: { !$0.isCompleted && $0.progress < 1.0 }) else {
                throw NotificationReminderError.noIncompleteAssessments
            }
            assessment = top
        }

        // 2. Resolve subject
        let subjects = (try? await subjectRepository.fetchSubjects()) ?? []
        let subject = subjects.first { $0.id == assessment.subjectId }
        let subjectCode = subject?.code ?? "MYUNIDAY"
        let subjectName = subject?.name

        // 3. Priority & Deadlines
        let priority = calculatePriorityUseCase.execute(for: assessment, relativeTo: referenceDate)
        let formattedDue = formatDueDate(assessment.dueDate, relativeTo: referenceDate)

        let incompleteTasks = assessment.tasks.filter { !$0.isCompleted }

        // 4. Build payload
        let payload = AssessmentReminderPayload(
            assessmentId: assessment.id,
            assessmentTitle: assessment.title,
            subjectCode: subjectCode,
            subjectName: subjectName,
            priority: priority.rawValue,
            dueDate: assessment.dueDate,
            formattedDueDate: formattedDue,
            progress: assessment.progress,
            remainingTaskCount: incompleteTasks.count,
            totalTaskCount: assessment.tasks.count
        )

        // 5. Construct UNNotificationContent
        let content = UNMutableNotificationContent()
        content.title = "ASSESSMENT DUE SOON"
        content.subtitle = "\(payload.subjectCode) • \(payload.priority.uppercased()) PRIORITY"
        content.body = "\(payload.assessmentTitle) — \(payload.formattedDueDate) (\(payload.formattedProgress))"
        content.categoryIdentifier = AssessmentReminderPayload.categoryIdentifier
        content.userInfo = payload.toUserInfo()
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "assessment_reminder_\(assessment.id.uuidString)_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationService.addNotificationRequest(request)
        } catch {
            throw NotificationReminderError.schedulingFailed(reason: error.localizedDescription)
        }

        return payload
    }

    private func formatDueDate(_ dueDate: Date, relativeTo referenceDate: Date) -> String {
        let calendar = Calendar.current
        if dueDate < referenceDate {
            return "Overdue"
        } else if calendar.isDate(dueDate, inSameDayAs: referenceDate) {
            return "Due today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate),
                  calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            return "Due tomorrow"
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: referenceDate), to: calendar.startOfDay(for: dueDate)).day ?? 0
            if days > 1 {
                return "Due in \(days) days"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return "Due " + formatter.string(from: dueDate)
            }
        }
    }
}
