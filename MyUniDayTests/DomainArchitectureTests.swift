//
//  DomainArchitectureTests.swift
//  MyUniDayTests
//
//  Comprehensive unit tests covering Domain Architecture remediation:
//  - CreateTaskUseCase (creation, progress sync, validation errors)
//  - UpdateAssessmentProgressUseCase (manual update, boundaries, child task rule)
//  - GetAllClassesUseCase & GetSubjectsUseCase
//  - Group Work Use Cases (Get, Save, Delete, ToggleTask, ManageDeliverables)
//  - GetStudentRemindersUseCase & GetStudentTasksUseCase
//  - Typed Domain Error translations & student-friendly descriptions
//

import Testing
import Foundation
@testable import MyUniDay

@Suite("Domain Architecture Remediation Tests")
@MainActor
struct DomainArchitectureTests {

    private func makeTestContainer() -> AppDependencyContainer {
        #if DEBUG
        return DevelopmentDemoData.makeDemoContainer()
        #else
        return AppDependencyContainer(persistenceController: PersistenceController(inMemory: true))
        #endif
    }

    // MARK: - 1. CreateTaskUseCase Tests

    @Test("CreateTaskUseCase successfully adds assessment task and synchronizes progress")
    func testCreateAssessmentTaskAndProgressSync() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        // Create standalone assessment
        let assessment = Assessment(
            id: UUID(),
            subjectId: subjectId,
            title: "Task Sync Test Assessment",
            dueDate: Date().addingTimeInterval(86400 * 5),
            weighting: 15.0,
            estimatedWorkloadHours: 6.0,
            progress: 0.0,
            isCompleted: false
        )
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        // Add 2 tasks
        try await container.createTaskUseCase.addAssessmentTask(
            title: "Step 1: Background reading",
            dueDate: nil,
            toAssessmentId: assessment.id
        )
        let task2 = try await container.createTaskUseCase.addAssessmentTask(
            title: "Step 2: Draft report",
            dueDate: nil,
            toAssessmentId: assessment.id
        )

        // Complete step 1
        var fetched = try #require(try await container.assessmentRepository.fetchAssessment(by: assessment.id))
        #expect(fetched.tasks.count == 2)
        #expect(fetched.progress == 0.0)

        // Toggle task
        try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(taskId: task2.id, inAssessmentId: assessment.id)

        let afterToggle = try #require(try await container.assessmentRepository.fetchAssessment(by: assessment.id))
        #expect(afterToggle.progress == 0.5)
        #expect(afterToggle.isCompleted == false)
    }

    @Test("CreateTaskUseCase validates empty title and throws TaskManagementError.emptyTitle")
    func testCreateAssessmentTaskEmptyTitleThrows() async throws {
        let container = makeTestContainer()
        let fakeId = UUID()

        await #expect(throws: TaskManagementError.emptyTitle) {
            try await container.createTaskUseCase.addAssessmentTask(
                title: "   ",
                dueDate: nil,
                toAssessmentId: fakeId
            )
        }
    }

    @Test("CreateTaskUseCase throws assessmentNotFound for non-existent assessment")
    func testCreateAssessmentTaskMissingParentThrows() async throws {
        let container = makeTestContainer()
        let nonExistentId = UUID()

        await #expect(throws: TaskManagementError.assessmentNotFound) {
            try await container.createTaskUseCase.addAssessmentTask(
                title: "Valid Step",
                dueDate: nil,
                toAssessmentId: nonExistentId
            )
        }
    }

    @Test("CreateTaskUseCase adds preparation item for class session")
    func testCreatePreparationItemSuccess() async throws {
        let container = makeTestContainer()
        let classes = try await container.getAllClassesUseCase.execute()
        let session = try #require(classes.first)

        try await container.createTaskUseCase.addPreparationItem(
            title: "Review lecture slides 4-6",
            notes: "Focus on ACID properties",
            toSessionId: session.id
        )

        let items = try await container.getClassPreparationUseCase.execute(forSessionId: session.id)
        #expect(items.contains { $0.title == "Review lecture slides 4-6" })
    }

    // MARK: - 2. UpdateAssessmentProgressUseCase Tests

    @Test("UpdateAssessmentProgressUseCase updates standalone assessment progress and completion")
    func testUpdateStandaloneAssessmentProgress() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let assessment = Assessment(
            id: UUID(),
            subjectId: subjectId,
            title: "Standalone Essay",
            dueDate: Date().addingTimeInterval(86400 * 3),
            weighting: 10.0,
            estimatedWorkloadHours: 4.0,
            progress: 0.2,
            isCompleted: false,
            notes: nil,
            tasks: []
        )
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        // Update progress to 100%
        try await container.updateAssessmentProgressUseCase.execute(assessmentId: assessment.id, progress: 1.0)

        let updated = try await container.assessmentRepository.fetchAssessment(by: assessment.id)
        let fetched = try #require(updated)
        #expect(fetched.progress == 1.0)
        #expect(fetched.isCompleted == true)
    }

    @Test("UpdateAssessmentProgressUseCase rejects progress outside 0.0 to 1.0 range")
    func testUpdateAssessmentProgressInvalidRangeThrows() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let assessment = Assessment(
            id: UUID(),
            subjectId: subjectId,
            title: "Boundary Assessment",
            dueDate: Date().addingTimeInterval(86400 * 4),
            weighting: 10.0,
            estimatedWorkloadHours: 4.0,
            progress: 0.0,
            isCompleted: false,
            notes: nil,
            tasks: []
        )
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        await #expect(throws: AssessmentProgressUpdateError.invalidProgressRange(progress: -0.1)) {
            try await container.updateAssessmentProgressUseCase.execute(assessmentId: assessment.id, progress: -0.1)
        }

        await #expect(throws: AssessmentProgressUpdateError.invalidProgressRange(progress: 1.2)) {
            try await container.updateAssessmentProgressUseCase.execute(assessmentId: assessment.id, progress: 1.2)
        }
    }

    @Test("UpdateAssessmentProgressUseCase prohibits manual override when assessment has child tasks")
    func testUpdateAssessmentProgressWithChildTasksForbidden() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let assessment = Assessment(
            id: UUID(),
            subjectId: subjectId,
            title: "Project with Tasks",
            dueDate: Date().addingTimeInterval(86400 * 7),
            weighting: 25.0,
            estimatedWorkloadHours: 12.0,
            progress: 0.0,
            isCompleted: false
        )
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        try await container.createTaskUseCase.addAssessmentTask(
            title: "Task 1",
            dueDate: nil,
            toAssessmentId: assessment.id
        )

        await #expect(throws: AssessmentProgressUpdateError.self) {
            try await container.updateAssessmentProgressUseCase.execute(assessmentId: assessment.id, progress: 0.8)
        }
    }

    // MARK: - 3. GetAllClassesUseCase & GetSubjectsUseCase Tests

    @Test("GetAllClassesUseCase returns chronologically sorted sessions")
    func testGetAllClassesUseCase() async throws {
        let container = makeTestContainer()
        let classes = try await container.getAllClassesUseCase.execute()
        #expect(!classes.isEmpty)

        for i in 0..<(classes.count - 1) {
            #expect(classes[i].startDate <= classes[i + 1].startDate)
        }
    }

    @Test("GetSubjectsUseCase retrieves all subjects with valid codes")
    func testGetSubjectsUseCase() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        #expect(!subjects.isEmpty)
        #expect(subjects.allSatisfy { !$0.code.isEmpty && !$0.name.isEmpty })
    }

    // MARK: - 4. Group Work Use Cases Tests

    @Test("SaveGroupProjectUseCase validates blank title and throws GroupProjectError.emptyName")
    func testSaveGroupProjectBlankTitleThrows() async throws {
        let container = makeTestContainer()
        let invalidProject = GroupProject(
            name: "   ",
            dueDate: Date().addingTimeInterval(86400 * 10),
            myRole: "Team Lead"
        )

        await #expect(throws: GroupProjectError.emptyName) {
            try await container.saveGroupProjectUseCase.execute(project: invalidProject)
        }
    }

    @Test("Group Work CRUD: save, get, toggle task, and delete")
    func testGroupWorkLifecycle() async throws {
        let container = makeTestContainer()

        let taskId = UUID()
        let task = GroupTask(id: taskId, title: "System Architecture Diagram", dueDate: Date().addingTimeInterval(86400 * 2), orderIndex: 0)
        let member = GroupMember(name: "Alex Smith", role: "Frontend Dev")
        let project = GroupProject(
            name: "Capstone Capstone Project",
            dueDate: Date().addingTimeInterval(86400 * 14),
            myRole: "Project Manager",
            members: [member],
            tasks: [task]
        )

        // Save
        try await container.saveGroupProjectUseCase.execute(project: project)

        // Get
        let allProjects = try await container.getGroupProjectsUseCase.execute()
        let savedProject = try #require(allProjects.first { $0.id == project.id })
        #expect(savedProject.name == "Capstone Capstone Project")
        #expect(savedProject.progress == 0.0)

        // Toggle task
        let updatedProject = try await container.toggleGroupTaskUseCase.execute(taskId: taskId, inProjectId: project.id)
        #expect(updatedProject.progress == 1.0)
        #expect(updatedProject.tasks.first?.isCompleted == true)

        // Manage deliverables
        let withDeliverable = try await container.manageGroupDeliverablesUseCase.addTask(title: "Final PDF Report", toProjectId: project.id)
        #expect(withDeliverable.tasks.contains { $0.title == "Final PDF Report" })

        // Delete
        try await container.deleteGroupProjectUseCase.execute(byId: project.id)
        let afterDelete = try await container.getGroupProjectsUseCase.execute()
        #expect(!afterDelete.contains { $0.id == project.id })
    }

    // MARK: - 5. Reminders & Tasks Use Cases Tests

    @Test("GetStudentRemindersUseCase aggregates items across categories")
    func testGetStudentRemindersUseCase() async throws {
        let container = makeTestContainer()
        let reminders = try await container.getStudentRemindersUseCase.execute()

        #expect(!reminders.isEmpty)
        let hasAssessments = reminders.contains { $0.category == .assessments }
        let hasClasses = reminders.contains { $0.category == .classes }
        #expect(hasAssessments || hasClasses)
    }

    @Test("GetStudentTasksUseCase aggregates student task overview")
    func testGetStudentTasksUseCase() async throws {
        let container = makeTestContainer()
        let overview = try await container.getStudentTasksUseCase.execute()

        #expect(!overview.assessments.isEmpty)
        #expect(!overview.sessions.isEmpty)
        #expect(!overview.subjectsById.isEmpty)
    }

    // MARK: - 6. Typed Domain Error Translation Tests

    @Test("GetPriorityAssessmentsUseCase translates repository failure into PriorityAssessmentError")
    func testPriorityAssessmentsErrorTranslation() async throws {
        let mockRepo = MockAssessmentRepository()
        mockRepo.shouldFail = true
        mockRepo.failureError = NSError(domain: "NSCocoaErrorDomain", code: 256, userInfo: nil)

        let useCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: mockRepo,
            calculatePriorityUseCase: CalculateAssessmentPriorityUseCase()
        )

        await #expect(throws: PriorityAssessmentError.self) {
            try await useCase.execute()
        }
    }

    @Test("GetNextClassUseCase translates repository failure into NextClassError")
    func testNextClassErrorTranslation() async throws {
        let mockRepo = MockClassSessionRepository()
        mockRepo.shouldFail = true
        mockRepo.failureError = NSError(domain: "NSSQLiteErrorDomain", code: 1, userInfo: nil)

        let useCase = GetNextClassUseCase(classSessionRepository: mockRepo)

        await #expect(throws: NextClassError.self) {
            try await useCase.execute()
        }
    }

    @Test("GetClassPreparationUseCase translates repository failure into ClassPreparationError")
    func testClassPreparationErrorTranslation() async throws {
        let mockRepo = MockPreparationItemRepository()
        mockRepo.shouldFail = true
        mockRepo.failureError = NSError(domain: "NSCocoaErrorDomain", code: 512, userInfo: nil)

        let useCase = GetClassPreparationUseCase(preparationItemRepository: mockRepo)

        await #expect(throws: ClassPreparationError.self) {
            try await useCase.execute(forSessionId: UUID())
        }
    }

    @Test("Domain error LocalizedError descriptions provide student-friendly guidance")
    func testStudentFriendlyErrorDescriptions() {
        let assessErr = AssessmentCreationError.invalidWeighting
        #expect(assessErr.errorDescription == "Assessment weighting must be between 0% and 100%.")
        #expect(assessErr.recoverySuggestion == "Enter a grade weighting percentage from 0 to 100.")

        let classErr = ClassSessionCreationError.invalidTimeRange
        #expect(classErr.errorDescription == "Class end time cannot be earlier than its start time.")

        let groupErr = GroupProjectError.emptyName
        #expect(groupErr.errorDescription == "Please enter a group project name.")

        let overrideErr = AssessmentProgressUpdateError.manualOverrideForbidden(taskCount: 2)
        #expect(overrideErr.errorDescription == "Cannot manually set progress because this assessment has 2 milestone tasks. Complete the tasks to advance progress.")
    }
}
