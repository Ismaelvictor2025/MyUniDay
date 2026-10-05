//
//  RemindersViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel aggregating actionable university reminders from existing data.
//

import Foundation
import Observation

/// Categorisation of university reminders.
public enum ReminderCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case assessments = "Assessments"
    case classes = "Classes & Prep"
    case tasks = "Tasks"

    public var id: String { rawValue }
}

/// An individual reminder summarizing an upcoming academic commitment.
public struct StudentReminderItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let detail: String
    public let dueDate: Date?
    public let category: ReminderCategory
    public let isUrgent: Bool
    public let iconName: String

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        detail: String,
        dueDate: Date? = nil,
        category: ReminderCategory,
        isUrgent: Bool,
        iconName: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.dueDate = dueDate
        self.category = category
        self.isUrgent = isUrgent
        self.iconName = iconName
    }
}

/// ViewModel coordinating the student Reminders screen.
@Observable
@MainActor
public final class RemindersViewModel {
    private let assessmentRepository: AssessmentRepositoryProtocol
    private let classSessionRepository: ClassSessionRepositoryProtocol
    private let preparationItemRepository: PreparationItemRepositoryProtocol
    private let subjectRepository: SubjectRepositoryProtocol?

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
        assessmentRepository: AssessmentRepositoryProtocol,
        classSessionRepository: ClassSessionRepositoryProtocol,
        preparationItemRepository: PreparationItemRepositoryProtocol,
        subjectRepository: SubjectRepositoryProtocol? = nil
    ) {
        self.assessmentRepository = assessmentRepository
        self.classSessionRepository = classSessionRepository
        self.preparationItemRepository = preparationItemRepository
        self.subjectRepository = subjectRepository
    }

    /// Aggregates reminders across upcoming assessments, classes, preparation items, and tasks.
    public func loadReminders(relativeTo referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            async let assessmentsTask = assessmentRepository.fetchAllAssessments()
            async let sessionsTask = classSessionRepository.fetchUpcomingClassSessions(from: referenceDate)
            async let subjectsTask = subjectRepository?.fetchSubjects() ?? []

            let (assessments, sessions, subjects) = try await (assessmentsTask, sessionsTask, subjectsTask)

            var subjectMap: [UUID: UniversitySubject] = [:]
            for s in subjects { subjectMap[s.id] = s }

            var items: [StudentReminderItem] = []

            // 1. Assessment Deadlines
            let activeAssessments = assessments.filter { !$0.isCompleted && $0.progress < 0.999 }
            for a in activeAssessments {
                let interval = a.dueDate.timeIntervalSince(referenceDate)
                let days = Int(ceil(interval / 86400))
                let isUrgent = interval <= (86400 * 3) // Within 3 days
                let code = a.subjectId.flatMap { subjectMap[$0]?.code } ?? "Coursework"

                let dueText: String
                if interval <= 0 {
                    dueText = "Due today!"
                } else if days == 1 {
                    dueText = "Due tomorrow"
                } else {
                    dueText = "Due in \(days) days"
                }

                items.append(
                    StudentReminderItem(
                        id: a.id,
                        title: a.title,
                        subtitle: "\(code) • \(dueText)",
                        detail: "\(Int(a.weighting))% weighting • \(Int(a.progress * 100))% complete",
                        dueDate: a.dueDate,
                        category: .assessments,
                        isUrgent: isUrgent,
                        iconName: isUrgent ? "exclamationmark.triangle.fill" : "doc.text.fill"
                    )
                )

                // Subtasks for urgent assessments
                for task in a.tasks where !task.isCompleted {
                    items.append(
                        StudentReminderItem(
                            id: task.id,
                            title: task.title,
                            subtitle: "Milestone for \(a.title)",
                            detail: code,
                            dueDate: task.dueDate ?? a.dueDate,
                            category: .tasks,
                            isUrgent: isUrgent,
                            iconName: "checklist"
                        )
                    )
                }
            }

            // 2. Upcoming Classes & Incomplete Preparation
            for session in sessions.prefix(3) {
                let code = session.subjectId.flatMap { subjectMap[$0]?.code } ?? "Class"
                let pendingPrep = session.preparationItems.filter { !$0.isCompleted }

                if !pendingPrep.isEmpty {
                    items.append(
                        StudentReminderItem(
                            id: session.id,
                            title: "Prepare for \(code) \(session.classType.rawValue)",
                            subtitle: "\(session.building) \(session.room)",
                            detail: "\(pendingPrep.count) item\(pendingPrep.count == 1 ? "" : "s") pending: " + pendingPrep.map { $0.title }.joined(separator: ", "),
                            dueDate: session.startDate,
                            category: .classes,
                            isUrgent: session.startDate.timeIntervalSince(referenceDate) <= 86400,
                            iconName: "backpack.fill"
                        )
                    )
                }
            }

            // Sort: urgent first, then by due date
            self.reminders = items.sorted { lhs, rhs in
                if lhs.isUrgent != rhs.isUrgent {
                    return lhs.isUrgent && !rhs.isUrgent
                }
                let lDate = lhs.dueDate ?? .distantFuture
                let rDate = rhs.dueDate ?? .distantFuture
                return lDate < rDate
            }
        } catch {
            self.errorMessage = "Unable to load reminders. Please try again."
        }

        isLoading = false
    }
}
