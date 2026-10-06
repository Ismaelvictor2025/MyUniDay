//
//  WidgetIntegrationTests.swift
//  MyUniDayTests
//
//  Unit and integration tests verifying WidgetKit App Group shared data:
//  - WidgetAcademicSnapshot serialization and deserialization
//  - Correct progress and task count derivation without double-counting
//  - Empty state handling
//  - App Group storage read/write round-trips
//  - End-to-end sync through UpdateWidgetSnapshotUseCase
//

import Testing
import Foundation
@testable import MyUniDay

@Suite("WidgetKit App Group Shared Data & Integration Tests")
@MainActor
struct WidgetIntegrationTests {

    private func makeTestContainer() -> AppDependencyContainer {
        #if DEBUG
        return DevelopmentDemoData.makeDemoContainer()
        #else
        return AppDependencyContainer(persistenceController: PersistenceController(inMemory: true))
        #endif
    }

    // MARK: - 1. Encoding and Decoding

    @Test("WidgetAcademicSnapshot encodes and decodes losslessly via JSON")
    func testSnapshotEncodingAndDecoding() throws {
        let referenceDate = Date()
        let dueDate = referenceDate.addingTimeInterval(86400 * 3)
        let startTime = referenceDate.addingTimeInterval(3600 * 2)
        let endTime = referenceDate.addingTimeInterval(3600 * 4)

        let original = WidgetAcademicSnapshot(
            hasAssessment: true,
            priorityAssessmentTitle: "Assignment 2: Polymorphic System",
            subjectCode: "COMP2014",
            subjectName: "Object Oriented Programming",
            priorityLevel: "Critical",
            dueDate: dueDate,
            progress: 0.50,
            remainingTaskCount: 3,
            totalTaskCount: 6,
            hasUpcomingClass: true,
            nextClassSubjectCode: "COMP2014",
            nextClassType: "Workshop",
            nextClassStartTime: startTime,
            nextClassEndTime: endTime,
            nextClassBuilding: "Building EA",
            nextClassRoom: "Room 15",
            lastUpdated: referenceDate
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WidgetAcademicSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.priorityAssessmentTitle == "Assignment 2: Polymorphic System")
        #expect(decoded.subjectCode == "COMP2014")
        #expect(decoded.priorityLevel == "Critical")
        #expect(decoded.progress == 0.50)
        #expect(decoded.remainingTaskCount == 3)
        #expect(decoded.totalTaskCount == 6)
        #expect(decoded.hasUpcomingClass == true)
        #expect(decoded.nextClassBuilding == "Building EA")
        #expect(decoded.nextClassRoom == "Room 15")
    }

    // MARK: - 2. Empty State Handling

    @Test("Empty snapshot provides correct default state and graceful text fallbacks")
    func testEmptyStateSnapshotHandling() {
        let empty = WidgetAcademicSnapshot.empty

        #expect(empty.hasAssessment == false)
        #expect(empty.hasUpcomingClass == false)
        #expect(empty.priorityAssessmentTitle == nil)
        #expect(empty.subjectCode == nil)
        #expect(empty.progress == 0.0)
        #expect(empty.remainingTaskCount == 0)
        #expect(empty.dueDescription == "No due date")
        #expect(empty.tasksRemainingDescription == "All tasks complete")
        #expect(empty.classTimeString == nil)
        #expect(empty.classLocationString == nil)
    }

    // MARK: - 3. Progress and Task Count String Formatting

    @Test("WidgetAcademicSnapshot formats progress and task counts accurately")
    func testProgressAndTaskCountsFormatting() {
        // 50% with 3 tasks remaining
        var snapshot = WidgetAcademicSnapshot(
            hasAssessment: true,
            progress: 0.50,
            remainingTaskCount: 3,
            totalTaskCount: 6
        )
        #expect(snapshot.progressPercentageString == "50% complete")
        #expect(snapshot.tasksRemainingDescription == "3 tasks remaining")

        // 66.7% formatted as 67%
        snapshot.progress = 4.0 / 6.0
        snapshot.remainingTaskCount = 2
        #expect(snapshot.progressPercentageString == "67% complete")
        #expect(snapshot.tasksRemainingDescription == "2 tasks remaining")

        // Singular task remaining
        snapshot.progress = 5.0 / 6.0
        snapshot.remainingTaskCount = 1
        #expect(snapshot.progressPercentageString == "83% complete")
        #expect(snapshot.tasksRemainingDescription == "1 task remaining")

        // 100% complete
        snapshot.progress = 1.0
        snapshot.remainingTaskCount = 0
        #expect(snapshot.progressPercentageString == "100% complete")
        #expect(snapshot.tasksRemainingDescription == "All tasks complete")
    }

    // MARK: - 4. Snapshot Store Read and Write Round-Trip

    @Test("WidgetSnapshotStore saves and loads snapshot reliably")
    func testSnapshotStoreSaveAndLoad() {
        let store = WidgetSnapshotStore(appGroupIdentifier: "test.group.myuniday")
        store.clear()

        #expect(store.load() == .empty)

        let sample = WidgetAcademicSnapshot.previewSample
        store.save(snapshot: sample)

        let loaded = store.load()
        #expect(loaded.hasAssessment == true)
        #expect(loaded.priorityAssessmentTitle == sample.priorityAssessmentTitle)
        #expect(loaded.subjectCode == sample.subjectCode)
        #expect(loaded.progress == sample.progress)
        #expect(loaded.remainingTaskCount == sample.remainingTaskCount)

        store.clear()
        #expect(store.load() == .empty)
    }

    // MARK: - 5. End-to-End Use Case Data Synchronization

    @Test("UpdateWidgetSnapshotUseCase populates snapshot with top assessment and next class")
    func testUpdateWidgetSnapshotUseCaseIntegration() async throws {
        let container = makeTestContainer()

        let snapshot = try await container.updateWidgetSnapshotUseCase.execute()

        // With standard demo data, Assignment 2 (COMP2014) is CRITICAL, 50% complete
        #expect(snapshot.hasAssessment == true)
        #expect(snapshot.priorityAssessmentTitle == "Assignment 2: Polymorphic System")
        #expect(snapshot.subjectCode == "COMP2014")
        #expect(snapshot.priorityLevel == "Critical")
        #expect(snapshot.progress == 0.50)
        #expect(snapshot.remainingTaskCount == 3)
        #expect(snapshot.totalTaskCount == 6)

        // And next class is populated
        #expect(snapshot.hasUpcomingClass == true)
        #expect(snapshot.nextClassSubjectCode != nil)
        #expect(snapshot.nextClassStartTime != nil)
    }

    @Test("Widget snapshot reacts to task completion changes in the main application")
    func testWidgetSnapshotReactsToTaskCompletion() async throws {
        let container = makeTestContainer()

        // 1. Initial State: 3 of 6 tasks = 50%
        let initialSnapshot = try await container.updateWidgetSnapshotUseCase.execute()
        #expect(initialSnapshot.progress == 0.50)
        #expect(initialSnapshot.remainingTaskCount == 3)

        // 2. Fetch Assignment 2 and complete task #4
        let allAssessments = try await container.assessmentRepository.fetchAllAssessments()
        let assignment2 = try #require(allAssessments.first { $0.title.contains("Polymorphic") })
        let task4 = try #require(assignment2.tasks.first { !$0.isCompleted })

        _ = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(
            taskId: task4.id,
            inAssessmentId: assignment2.id
        )

        // Sync widget
        let updatedSnapshot = try await container.updateWidgetSnapshotUseCase.execute()
        #expect(abs(updatedSnapshot.progress - (4.0 / 6.0)) < 0.001)
        #expect(updatedSnapshot.progressPercentageString == "67% complete")
        #expect(updatedSnapshot.remainingTaskCount == 2)

        // 3. Uncheck task #4 -> reverts back to 50%
        _ = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(
            taskId: task4.id,
            inAssessmentId: assignment2.id
        )

        let revertedSnapshot = try await container.updateWidgetSnapshotUseCase.execute()
        #expect(abs(revertedSnapshot.progress - 0.50) < 0.001)
        #expect(revertedSnapshot.progressPercentageString == "50% complete")
        #expect(revertedSnapshot.remainingTaskCount == 3)
    }

    // MARK: - 6. Assessment and Class Session Isolation

    @Test("Absence of next class does not erase or degrade priority assessment data")
    func testNoNextClassDoesNotRemoveAssessmentData() async throws {
        // Container with assessments but NO class sessions
        let subject = UniversitySubject(id: UUID(), code: "COMP2014", name: "Object Oriented Programming")
        var assessment = Assessment(
            id: UUID(),
            subjectId: subject.id,
            title: "Assignment 2: Polymorphic System",
            dueDate: Date().addingTimeInterval(86400 * 2),
            weighting: 35.0,
            estimatedWorkloadHours: 15.0,
            progress: 0.50,
            isCompleted: false,
            tasks: [
                AssessmentTask(id: UUID(), assessmentId: UUID(), title: "Task 1", isCompleted: true, orderIndex: 0),
                AssessmentTask(id: UUID(), assessmentId: UUID(), title: "Task 2", isCompleted: false, orderIndex: 1)
            ]
        )
        AssessmentProgressCalculator.synchronize(&assessment)

        let container = AppDependencyContainer(
            subjectRepository: DevelopmentDemoData.DemoSubjectRepository(subjects: [subject]),
            assessmentRepository: DevelopmentDemoData.DemoAssessmentRepository(assessments: [assessment]),
            classSessionRepository: DevelopmentDemoData.DemoClassSessionRepository(sessions: []),
            preparationItemRepository: DevelopmentDemoData.DemoPreparationItemRepository(items: [:])
        )

        let snapshot = try await container.updateWidgetSnapshotUseCase.execute()

        // Assessment data must be 100% intact
        #expect(snapshot.hasAssessment == true)
        #expect(snapshot.priorityAssessmentTitle == "Assignment 2: Polymorphic System")
        #expect(snapshot.subjectCode == "COMP2014")
        #expect(snapshot.progress == 0.50)
        #expect(snapshot.remainingTaskCount == 1)
        #expect(snapshot.totalTaskCount == 2)

        // Class data must be gracefully absent
        #expect(snapshot.hasUpcomingClass == false)
        #expect(snapshot.nextClassSubjectCode == nil)
        #expect(snapshot.nextClassStartTime == nil)
    }

    @Test("Absence of incomplete assessments does not prevent upcoming class display")
    func testNextClassExistsWithoutAssessment() async throws {
        let subject = UniversitySubject(id: UUID(), code: "COMP2014", name: "Object Oriented Programming")
        let session = ClassSession(
            id: UUID(),
            subjectId: subject.id,
            classType: .workshop,
            startDate: Date().addingTimeInterval(3600 * 2),
            endDate: Date().addingTimeInterval(3600 * 4),
            campus: "Parkville",
            building: "Building EA",
            room: "Room 15"
        )

        let container = AppDependencyContainer(
            subjectRepository: DevelopmentDemoData.DemoSubjectRepository(subjects: [subject]),
            assessmentRepository: DevelopmentDemoData.DemoAssessmentRepository(assessments: []),
            classSessionRepository: DevelopmentDemoData.DemoClassSessionRepository(sessions: [session]),
            preparationItemRepository: DevelopmentDemoData.DemoPreparationItemRepository(items: [:])
        )

        let snapshot = try await container.updateWidgetSnapshotUseCase.execute()

        // Assessment is absent -> empty assessment state
        #expect(snapshot.hasAssessment == false)
        #expect(snapshot.priorityAssessmentTitle == nil)

        // Class is populated
        #expect(snapshot.hasUpcomingClass == true)
        #expect(snapshot.nextClassSubjectCode == "COMP2014")
        #expect(snapshot.nextClassType == "Workshop")
        #expect(snapshot.nextClassBuilding == "Building EA")
        #expect(snapshot.nextClassRoom == "Room 15")
    }

    @Test("Empty state only occurs when there are truly no incomplete assessments")
    func testEmptyStateOnlyOccursWhenTrulyNoIncompleteAssessments() async throws {
        let container = AppDependencyContainer(
            subjectRepository: DevelopmentDemoData.DemoSubjectRepository(subjects: []),
            assessmentRepository: DevelopmentDemoData.DemoAssessmentRepository(assessments: []),
            classSessionRepository: DevelopmentDemoData.DemoClassSessionRepository(sessions: []),
            preparationItemRepository: DevelopmentDemoData.DemoPreparationItemRepository(items: [:])
        )

        let snapshot = try await container.updateWidgetSnapshotUseCase.execute()

        #expect(snapshot.hasAssessment == false)
        #expect(snapshot.hasUpcomingClass == false)
        #expect(snapshot.priorityAssessmentTitle == nil)
    }

    @Test("Current demo state generates exactly the expected priority assessment values")
    func testDemoModeStateGeneratesCurrentExpectedWidgetValues() async throws {
        #if DEBUG
        let container = DevelopmentDemoData.makeDemoContainer()
        let snapshot = try await container.updateWidgetSnapshotUseCase.execute()

        // Verify the 3 assessments in demo mode yield Assignment 2 as top priority
        #expect(snapshot.hasAssessment == true)
        #expect(snapshot.priorityAssessmentTitle == "Assignment 2: Polymorphic System")
        #expect(snapshot.subjectCode == "COMP2014")
        #expect(snapshot.priorityLevel?.lowercased() == "critical")
        #expect(snapshot.progress == 0.50)
        #expect(snapshot.remainingTaskCount == 3)
        #expect(snapshot.totalTaskCount == 6)

        // Verify next class is selected
        #expect(snapshot.hasUpcomingClass == true)
        #expect(snapshot.nextClassSubjectCode == "COMP2014")
        #expect(snapshot.nextClassType?.lowercased() == "workshop")
        #endif
    }
}
