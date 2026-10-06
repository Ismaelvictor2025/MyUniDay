//
//  GetStudentRemindersUseCase.swift
//  MyUniDay
//
//  Domain Use Case aggregating actionable university reminders across
//  assessments, scheduled classes, and preparation checklists.
//

import Foundation

/// Errors that can occur when aggregating student reminders.
public enum ReminderAggregationError: LocalizedError, Equatable, Sendable {
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .persistenceFailed:
            return "Unable to load student reminders right now. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        "Check that your coursework is up to date or pull down to refresh."
    }
}

/// Aggregates reminders across upcoming assessments, scheduled classes, and tasks into unified student reminder items.
public final class GetStudentRemindersUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol
    private let classSessionRepository: ClassSessionRepositoryProtocol
    private let preparationItemRepository: PreparationItemRepositoryProtocol
    private let subjectRepository: SubjectRepositoryProtocol?

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

    /// Gathers and sorts reminder items relative to a reference date.
    public func execute(relativeTo referenceDate: Date = Date()) async throws -> [StudentReminderItem] {
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
            return items.sorted { lhs, rhs in
                if lhs.isUrgent != rhs.isUrgent {
                    return lhs.isUrgent && !rhs.isUrgent
                }
                let lDate = lhs.dueDate ?? .distantFuture
                let rDate = rhs.dueDate ?? .distantFuture
                return lDate < rDate
            }
        } catch {
            throw ReminderAggregationError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
