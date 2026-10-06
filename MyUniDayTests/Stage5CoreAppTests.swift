//
//  Stage5CoreAppTests.swift
//  MyUniDayTests
//
//  Unit tests verifying Stage 5 multi-screen MVP functionality:
//  - Assessment creation and domain validation
//  - Class session creation and scheduling validation
//  - Subject creation validation
//  - Task completion toggling and progress synchronization
//  - UseCase and ViewModel state handling for Assessments, Classes, and Tasks
//

import Testing
import Foundation
@testable import MyUniDay

@Suite("Stage 5 Core App Functionality Tests")
@MainActor
struct Stage5CoreAppTests {

    // MARK: - Test Helpers

    private func makeTestContainer() -> AppDependencyContainer {
        #if DEBUG
        return DevelopmentDemoData.makeDemoContainer()
        #else
        return AppDependencyContainer(persistenceController: PersistenceController(inMemory: true))
        #endif
    }

    // MARK: - 1. Assessment Creation & Validation Tests

    @Test("CreateAssessmentUseCase successfully validates and persists an assessment")
    func testCreateAssessmentSuccess() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let newAssessment = Assessment(
            title: "Operating Systems Assignment 1",
            dueDate: Date().addingTimeInterval(86400 * 4),
            weighting: 20.0,
            estimatedWorkloadHours: 10.0,
            progress: 0.0,
            isCompleted: false,
            notes: "Build user-level threads library"
        )

        try await container.createAssessmentUseCase.execute(assessment: newAssessment, forSubjectId: subjectId)

        let all = try await container.assessmentRepository.fetchAllAssessments()
        let persisted = all.first { $0.id == newAssessment.id }

        #expect(persisted != nil)
        #expect(persisted?.title == "Operating Systems Assignment 1")
        #expect(persisted?.weighting == 20.0)
        #expect(persisted?.subjectId == subjectId)
    }

    @Test("CreateAssessmentUseCase rejects empty title and invalid weighting")
    func testCreateAssessmentValidation() async throws {
        let container = makeTestContainer()
        let subjectId = UUID()

        // 1. Empty title validation
        let emptyTitleAssessment = Assessment(
            title: "   ",
            dueDate: Date(),
            weighting: 20.0,
            estimatedWorkloadHours: 5.0
        )
        await #expect(throws: AssessmentCreationError.self) {
            try await container.createAssessmentUseCase.execute(assessment: emptyTitleAssessment, forSubjectId: subjectId)
        }

        // 2. Negative weighting validation
        let negativeWeightAssessment = Assessment(
            title: "Test",
            dueDate: Date(),
            weighting: -5.0,
            estimatedWorkloadHours: 5.0
        )
        await #expect(throws: AssessmentCreationError.self) {
            try await container.createAssessmentUseCase.execute(assessment: negativeWeightAssessment, forSubjectId: subjectId)
        }

        // 3. Weighting over 100 validation
        let excessiveWeightAssessment = Assessment(
            title: "Test",
            dueDate: Date(),
            weighting: 105.0,
            estimatedWorkloadHours: 5.0
        )
        await #expect(throws: AssessmentCreationError.self) {
            try await container.createAssessmentUseCase.execute(assessment: excessiveWeightAssessment, forSubjectId: subjectId)
        }
    }

    // MARK: - 2. Class Session Creation & Validation Tests

    @Test("CreateClassSessionUseCase successfully validates and persists a class session")
    func testCreateClassSessionSuccess() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let start = Date().addingTimeInterval(3600 * 5)
        let end = Date().addingTimeInterval(3600 * 7)

        let newSession = ClassSession(
            subjectId: subjectId,
            classType: .lab,
            startDate: start,
            endDate: end,
            campus: "Parkville",
            building: "Alice Hoy",
            room: "Room 105"
        )

        try await container.createClassSessionUseCase.execute(classSession: newSession, forSubjectId: subjectId)

        let upcoming = try await container.classSessionRepository.fetchAllClassSessions()
        let persisted = upcoming.first { $0.id == newSession.id }

        #expect(persisted != nil)
        #expect(persisted?.classType == .lab)
        #expect(persisted?.building == "Alice Hoy")
        #expect(persisted?.room == "Room 105")
    }

    @Test("CreateClassSessionUseCase validates required location and chronological times")
    func testCreateClassSessionValidation() async throws {
        let container = makeTestContainer()
        let subjectId = UUID()
        let now = Date()

        // 1. Missing building
        let missingBuilding = ClassSession(
            classType: .lecture,
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            campus: "City",
            building: "   ",
            room: "Room 1"
        )
        await #expect(throws: ClassSessionCreationError.self) {
            try await container.createClassSessionUseCase.execute(classSession: missingBuilding, forSubjectId: subjectId)
        }

        // 2. End time before start time
        let invalidTimes = ClassSession(
            classType: .lecture,
            startDate: now,
            endDate: now.addingTimeInterval(-3600),
            campus: "City",
            building: "Building EA",
            room: "Room 1"
        )
        await #expect(throws: ClassSessionCreationError.self) {
            try await container.createClassSessionUseCase.execute(classSession: invalidTimes, forSubjectId: subjectId)
        }
    }

    // MARK: - 3. Subject Creation Validation Tests

    @Test("CreateSubjectUseCase validates code and name")
    func testCreateSubjectValidationAndPersistence() async throws {
        let container = makeTestContainer()

        // 1. Valid subject
        let validSubject = UniversitySubject(code: "SWEN90004", name: "Software Design Research")
        try await container.createSubjectUseCase.execute(subject: validSubject)

        let subjects = try await container.getSubjectsUseCase.execute()
        #expect(subjects.contains { $0.code == "SWEN90004" })

        // 2. Blank code
        let blankCode = UniversitySubject(code: "", name: "Test")
        await #expect(throws: SubjectCreationError.self) {
            try await container.createSubjectUseCase.execute(subject: blankCode)
        }
    }

    // MARK: - 4. Task Toggling and Progress Synchronization Tests

    @Test("ToggleTaskCompletionUseCase synchronizes assessment progress when tasks are toggled")
    func testToggleAssessmentTaskAndProgressSync() async throws {
        let container = makeTestContainer()
        let allAssessments = try await container.assessmentRepository.fetchAllAssessments()
        // Find assessment with tasks (e.g. Assignment 2)
        let targetAssessment = try #require(allAssessments.first { !$0.tasks.isEmpty })
        let targetTask = try #require(targetAssessment.tasks.first)

        let initialCompletion = targetTask.isCompleted

        // Toggle task
        let updatedAssessment = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(
            taskId: targetTask.id,
            inAssessmentId: targetAssessment.id
        )

        let updatedTask = try #require(updatedAssessment.tasks.first { $0.id == targetTask.id })
        #expect(updatedTask.isCompleted == !initialCompletion)

        // Progress recalculated to completed / total
        let completed = updatedAssessment.tasks.filter { $0.isCompleted }.count
        let expectedProgress = Double(completed) / Double(updatedAssessment.tasks.count)
        #expect(abs(updatedAssessment.progress - expectedProgress) < 0.001)
    }

    @Test("ToggleTaskCompletionUseCase toggles preparation item completion")
    func testTogglePreparationItem() async throws {
        let container = makeTestContainer()
        let allSessions = try await container.classSessionRepository.fetchAllClassSessions()
        let targetSession = try #require(allSessions.first { !$0.preparationItems.isEmpty })
        let targetItem = try #require(targetSession.preparationItems.first)

        let initial = targetItem.isCompleted
        let updated = try await container.toggleTaskCompletionUseCase.togglePreparationItem(
            item: targetItem,
            inSessionId: targetSession.id
        )

        #expect(updated.isCompleted == !initial)
    }

    // MARK: - 5. ViewModel Integration Tests

    @Test("AssessmentsViewModel correctly filters by priority")
    func testAssessmentsViewModelPriorityFiltering() async {
        let container = makeTestContainer()
        let viewModel = container.makeAssessmentsViewModel()

        await viewModel.loadAssessments()

        #expect(!viewModel.items.isEmpty)

        // Filter: Critical
        viewModel.selectedPriorityFilter = .critical
        #expect(viewModel.filteredItems.allSatisfy { $0.priority == .critical })

        // Filter: High
        viewModel.selectedPriorityFilter = .high
        #expect(viewModel.filteredItems.allSatisfy { $0.priority == .high })

        // Filter: Nil (All)
        viewModel.selectedPriorityFilter = nil
        #expect(viewModel.filteredItems.count == viewModel.items.count)
    }

    @Test("ClassesViewModel groups scheduled sessions by day")
    func testClassesViewModelGrouping() async {
        let container = makeTestContainer()
        let viewModel = container.makeClassesViewModel()

        await viewModel.loadClasses(from: .distantPast)

        #expect(!viewModel.classes.isEmpty)
        #expect(!viewModel.groupedClasses.isEmpty)

        // Verify each group has sessions
        for group in viewModel.groupedClasses {
            #expect(!group.sessions.isEmpty)
            #expect(!group.dayTitle.isEmpty)
        }
    }

    @Test("TasksViewModel unifies subtasks and supports pending/completed filters")
    func testTasksViewModelUnificationAndFiltering() async {
        let container = makeTestContainer()
        let viewModel = container.makeTasksViewModel()

        await viewModel.loadTasks()

        #expect(!viewModel.allTasks.isEmpty)

        // Verify pending filter
        viewModel.activeFilter = .pending
        #expect(viewModel.filteredTasks.allSatisfy { !$0.isCompleted })

        // Verify completed filter
        viewModel.activeFilter = .completed
        #expect(viewModel.filteredTasks.allSatisfy { $0.isCompleted })

        // Verify counts
        #expect(viewModel.pendingCount + viewModel.completedCount == viewModel.allTasks.count)
    }

    @Test("TasksViewModel toggle updates task completion state")
    func testTasksViewModelToggle() async throws {
        let container = makeTestContainer()
        let viewModel = container.makeTasksViewModel()

        await viewModel.loadTasks()

        let taskToToggle = try #require(viewModel.allTasks.first)
        let initialCompleted = taskToToggle.isCompleted

        await viewModel.toggleTask(item: taskToToggle)

        let toggled = try #require(viewModel.allTasks.first { $0.id == taskToToggle.id })
        #expect(toggled.isCompleted == !initialCompleted)
    }
}
