//
//  TasksViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel managing actionable student tasks across assessments and classes.
//

import Foundation
import Observation

/// Filter options for viewing tasks.
public enum TaskFilter: String, CaseIterable, Identifiable, Sendable {
    case pending = "Pending"
    case completed = "Completed"
    case all = "All"

    public var id: String { rawValue }
}

/// ViewModel coordinating actionable university subtasks and class preparation checklists via Domain Use Cases.
@Observable
@MainActor
public final class TasksViewModel {
    // MARK: - Dependencies
    private let getStudentTasksUseCase: GetStudentTasksUseCase
    private let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase
    private let createTaskUseCase: CreateTaskUseCase

    // MARK: - Presentation State
    /// All actionable task items from both assessments and class sessions.
    public private(set) var allTasks: [UnifiedTaskItem] = []

    /// Assessments available to associate tasks with.
    public private(set) var availableAssessments: [Assessment] = []

    /// Class sessions available to associate preparation items with.
    public private(set) var availableSessions: [ClassSession] = []

    /// Subjects keyed by ID for context display.
    public private(set) var subjectsById: [UUID: UniversitySubject] = [:]

    /// Active filter tab (defaults to `.pending`).
    public var activeFilter: TaskFilter = .pending

    /// Filtered list of tasks matching the current filter.
    public var filteredTasks: [UnifiedTaskItem] {
        switch activeFilter {
        case .pending:
            return allTasks.filter { !$0.isCompleted }
        case .completed:
            return allTasks.filter { $0.isCompleted }
        case .all:
            return allTasks
        }
    }

    /// Count of pending incomplete tasks.
    public var pendingCount: Int {
        allTasks.filter { !$0.isCompleted }.count
    }

    /// Count of completed tasks.
    public var completedCount: Int {
        allTasks.filter { $0.isCompleted }.count
    }

    /// Indicates whether tasks are actively being fetched.
    public private(set) var isLoading: Bool = false

    /// User-friendly error message if loading fails.
    public private(set) var errorMessage: String?

    // MARK: - Initialization
    public init(
        getStudentTasksUseCase: GetStudentTasksUseCase,
        toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase,
        createTaskUseCase: CreateTaskUseCase
    ) {
        self.getStudentTasksUseCase = getStudentTasksUseCase
        self.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase
        self.createTaskUseCase = createTaskUseCase

        self.dataObserver = NotificationCenter.default.addObserver(
            forName: .academicDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.loadTasks()
            }
        }
    }

    deinit {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private nonisolated(unsafe) var dataObserver: (any NSObjectProtocol)?

    // MARK: - Actions
    /// Loads all tasks from assessments and class sessions.
    public func loadTasks() async {
        isLoading = true
        errorMessage = nil

        do {
            let overview = try await getStudentTasksUseCase.execute()

            self.subjectsById = overview.subjectsById
            self.availableAssessments = overview.assessments
            self.availableSessions = overview.sessions

            var unified: [UnifiedTaskItem] = []

            // 1. Process Assessment Tasks
            for assessment in overview.assessments {
                let subjectCode = assessment.subjectId.flatMap { overview.subjectsById[$0]?.code }
                for task in assessment.tasks {
                    unified.append(
                        UnifiedTaskItem(
                            id: task.id,
                            title: task.title,
                            isCompleted: task.isCompleted,
                            dueDate: task.dueDate ?? assessment.dueDate,
                            source: .assessment(
                                assessmentId: assessment.id,
                                assessmentTitle: assessment.title,
                                subjectCode: subjectCode
                            ),
                            originalAssessmentTask: task
                        )
                    )
                }
            }

            // 2. Process Class Preparation Items
            for session in overview.sessions {
                let classTitle = "\(session.classType.rawValue) (\(session.building) \(session.room))"
                for prep in session.preparationItems {
                    unified.append(
                        UnifiedTaskItem(
                            id: prep.id,
                            title: prep.title,
                            notes: prep.notes,
                            isCompleted: prep.isCompleted,
                            dueDate: session.startDate,
                            source: .classSession(
                                sessionId: session.id,
                                classTitle: classTitle,
                                classDate: session.startDate
                            ),
                            originalPreparationItem: prep
                        )
                    )
                }
            }

            // Sort: pending first, then by due date
            self.allTasks = unified.sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted && rhs.isCompleted
                }
                let lhsDate = lhs.dueDate ?? .distantFuture
                let rhsDate = rhs.dueDate ?? .distantFuture
                return lhsDate < rhsDate
            }
        } catch {
            self.errorMessage = "Unable to load tasks. Please try again."
        }

        isLoading = false
    }

    /// Toggles the completion status of a task and persists the change.
    public func toggleTask(item: UnifiedTaskItem) async {
        do {
            switch item.source {
            case .assessment(let assessmentId, _, _):
                _ = try await toggleTaskCompletionUseCase.toggleAssessmentTask(
                    taskId: item.id,
                    inAssessmentId: assessmentId
                )
            case .classSession(let sessionId, _, _):
                if let prep = item.originalPreparationItem {
                    _ = try await toggleTaskCompletionUseCase.togglePreparationItem(
                        item: prep,
                        inSessionId: sessionId
                    )
                }
            }
            await loadTasks()
        } catch {
            self.errorMessage = "Failed to update task completion."
        }
    }

    /// Adds a new assessment task.
    public func createAssessmentTask(title: String, dueDate: Date? = nil, assessmentId: UUID) async throws {
        _ = try await createTaskUseCase.addAssessmentTask(
            title: title,
            dueDate: dueDate,
            toAssessmentId: assessmentId
        )
        await loadTasks()
    }

    /// Adds a new class preparation item.
    public func createPreparationItem(title: String, notes: String? = nil, sessionId: UUID) async throws {
        _ = try await createTaskUseCase.addPreparationItem(
            title: title,
            notes: notes,
            toSessionId: sessionId
        )
        await loadTasks()
    }
}
