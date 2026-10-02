//
//  Stage2UseCasesTests.swift
//  MyUniDayTests
//
//  Unit tests covering Stage 2 Domain Use Cases:
//  - CalculateAssessmentPriorityUseCase
//  - GetPriorityAssessmentsUseCase
//  - GetNextClassUseCase
//  - GetClassPreparationUseCase
//

import Testing
import Foundation
@testable import MyUniDay

// MARK: - Test Doubles / Mocks

final class MockAssessmentRepository: AssessmentRepositoryProtocol, @unchecked Sendable {
    var assessmentsToReturn: [Assessment] = []
    var shouldFail: Bool = false
    var failureError: Error = RepositoryError.underlying(description: "Database connection failed")

    func fetchAssessments(forSubjectId subjectId: UUID) async throws -> [Assessment] {
        if shouldFail { throw failureError }
        return assessmentsToReturn.filter { $0.subjectId == subjectId }
    }

    func fetchAssessment(by id: UUID) async throws -> Assessment? {
        if shouldFail { throw failureError }
        return assessmentsToReturn.first { $0.id == id }
    }

    func fetchIncompleteAssessments(dueBetween startDate: Date, and endDate: Date) async throws -> [Assessment] {
        if shouldFail { throw failureError }
        return assessmentsToReturn.filter {
            !$0.isCompleted && $0.progress < 1.0 && $0.dueDate >= startDate && $0.dueDate <= endDate
        }
    }

    func save(assessment: Assessment, forSubjectId subjectId: UUID) async throws {
        if shouldFail { throw failureError }
        assessmentsToReturn.append(assessment)
    }

    func deleteAssessment(by id: UUID) async throws {
        if shouldFail { throw failureError }
        assessmentsToReturn.removeAll { $0.id == id }
    }
}

final class MockClassSessionRepository: ClassSessionRepositoryProtocol, @unchecked Sendable {
    var sessionsToReturn: [ClassSession] = []
    var shouldFail: Bool = false
    var failureError: Error = RepositoryError.underlying(description: "Class query failure")

    func fetchClassSessions(forSubjectId subjectId: UUID) async throws -> [ClassSession] {
        if shouldFail { throw failureError }
        return sessionsToReturn.filter { $0.subjectId == subjectId }
    }

    func fetchClassSession(by id: UUID) async throws -> ClassSession? {
        if shouldFail { throw failureError }
        return sessionsToReturn.first { $0.id == id }
    }

    func fetchUpcomingClassSessions(from fromDate: Date) async throws -> [ClassSession] {
        if shouldFail { throw failureError }
        return sessionsToReturn.filter { $0.startDate >= fromDate }
    }

    func save(classSession: ClassSession, forSubjectId subjectId: UUID) async throws {
        if shouldFail { throw failureError }
        sessionsToReturn.append(classSession)
    }

    func deleteClassSession(by id: UUID) async throws {
        if shouldFail { throw failureError }
        sessionsToReturn.removeAll { $0.id == id }
    }
}

final class MockPreparationItemRepository: PreparationItemRepositoryProtocol, @unchecked Sendable {
    var itemsToReturn: [PreparationItem] = []
    var shouldFail: Bool = false
    var failureError: Error = RepositoryError.underlying(description: "Preparation item query failure")

    func fetchPreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
        if shouldFail { throw failureError }
        return itemsToReturn.filter { $0.classSessionId == sessionId }
    }

    func fetchIncompletePreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
        if shouldFail { throw failureError }
        return itemsToReturn.filter { $0.classSessionId == sessionId && !$0.isCompleted }
    }

    func save(item: PreparationItem, forSessionId sessionId: UUID) async throws {
        if shouldFail { throw failureError }
        itemsToReturn.append(item)
    }

    func deletePreparationItem(by id: UUID) async throws {
        if shouldFail { throw failureError }
        itemsToReturn.removeAll { $0.id == id }
    }
}

// MARK: - Use Case 1 Tests: CalculateAssessmentPriorityUseCase

@Suite("CalculateAssessmentPriorityUseCase Tests")
struct CalculateAssessmentPriorityUseCaseTests {
    let useCase = CalculateAssessmentPriorityUseCase()
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000) // Fixed baseline timestamp

    @Test("Assessment due very soon with high workload is critical")
    func testDueVerySoonCritical() {
        let assessment = Assessment(
            title: "Major Project",
            dueDate: referenceDate.addingTimeInterval(86400 * 1), // 1 day away (40 pts)
            weighting: 35.0,                                    // >= 30% (25 pts)
            estimatedWorkloadHours: 20.0,                        // 20h remaining (25 pts)
            progress: 0.0,
            isCompleted: false
        )

        let priority = useCase.execute(for: assessment, relativeTo: referenceDate)
        let score = useCase.calculateCompositeScore(for: assessment, relativeTo: referenceDate)

        #expect(score >= 75)
        #expect(priority == .critical)
    }

    @Test("Assessment due further in the future with low weight is low priority")
    func testDueFarFutureLow() {
        let assessment = Assessment(
            title: "Future Quiz",
            dueDate: referenceDate.addingTimeInterval(86400 * 30), // 30 days away (5 pts)
            weighting: 5.0,                                       // < 15% (5 pts)
            estimatedWorkloadHours: 2.0,                          // < 3h (5 pts)
            progress: 0.0,
            isCompleted: false
        )

        let priority = useCase.execute(for: assessment, relativeTo: referenceDate)
        let score = useCase.calculateCompositeScore(for: assessment, relativeTo: referenceDate)

        #expect(score < 30)
        #expect(priority == .low)
    }

    @Test("Higher weighting elevates priority")
    func testWeightingEffect() {
        // Same due date (5 days away = 25 pts) and workload (5h = 10 pts)
        let lowWeight = Assessment(
            title: "Minor Task",
            dueDate: referenceDate.addingTimeInterval(86400 * 5),
            weighting: 5.0, // 5 pts -> Total: 40 (Medium)
            estimatedWorkloadHours: 5.0,
            progress: 0.0
        )

        let highWeight = Assessment(
            title: "Heavy Task",
            dueDate: referenceDate.addingTimeInterval(86400 * 5),
            weighting: 35.0, // 25 pts -> Total: 60 (High)
            estimatedWorkloadHours: 5.0,
            progress: 0.0
        )

        let lowPriority = useCase.execute(for: lowWeight, relativeTo: referenceDate)
        let highPriority = useCase.execute(for: highWeight, relativeTo: referenceDate)

        #expect(lowPriority == .medium)
        #expect(highPriority == .high)
    }

    @Test("Progress reduces remaining workload and priority")
    func testProgressEffect() {
        // 20 hours workload initially.
        // At 0% progress: 20h remaining (25 pts) -> Total: 25 + 15 + 25 = 65 (High)
        // At 90% progress: 2h remaining (5 pts)   -> Total: 25 + 15 + 5  = 45 (Medium)
        let unstarted = Assessment(
            title: "Assignment",
            dueDate: referenceDate.addingTimeInterval(86400 * 6),
            weighting: 20.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.0
        )

        let mostlyDone = Assessment(
            title: "Assignment",
            dueDate: referenceDate.addingTimeInterval(86400 * 6),
            weighting: 20.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.9
        )

        let unstartedPriority = useCase.execute(for: unstarted, relativeTo: referenceDate)
        let mostlyDonePriority = useCase.execute(for: mostlyDone, relativeTo: referenceDate)

        #expect(unstartedPriority == .high)
        #expect(mostlyDonePriority == .medium)
    }

    @Test("Completed assessment is always low priority")
    func testCompletedAssessmentIsLow() {
        let completed = Assessment(
            title: "Completed Project",
            dueDate: referenceDate.addingTimeInterval(3600), // Due in 1 hour
            weighting: 50.0,
            estimatedWorkloadHours: 40.0,
            progress: 0.5,
            isCompleted: true
        )

        let priority = useCase.execute(for: completed, relativeTo: referenceDate)
        #expect(priority == .low)
    }

    @Test("Assessment at 100% progress is low priority even if isCompleted flag is false")
    func testFullProgressIsLow() {
        let fullProgress = Assessment(
            title: "Finished Project",
            dueDate: referenceDate.addingTimeInterval(3600),
            weighting: 40.0,
            estimatedWorkloadHours: 20.0,
            progress: 1.0,
            isCompleted: false
        )

        let priority = useCase.execute(for: fullProgress, relativeTo: referenceDate)
        #expect(priority == .low)
    }

    @Test("Overdue assessment with remaining work is critical")
    func testOverdueBoundary() {
        let overdue = Assessment(
            title: "Past Due Assignment",
            dueDate: referenceDate.addingTimeInterval(-86400), // 1 day overdue (50 pts)
            weighting: 20.0,                                  // 15 pts
            estimatedWorkloadHours: 10.0,                      // 15 pts -> Total: 80
            progress: 0.0,
            isCompleted: false
        )

        let priority = useCase.execute(for: overdue, relativeTo: referenceDate)
        #expect(priority == .critical)
    }
}

// MARK: - Use Case 2 Tests: GetPriorityAssessmentsUseCase

@Suite("GetPriorityAssessmentsUseCase Tests")
struct GetPriorityAssessmentsUseCaseTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Incomplete assessments are correctly ordered by priority and tie-breaker")
    func testCorrectOrderingAndTieBreaking() async throws {
        let repository = MockAssessmentRepository()
        let useCase = GetPriorityAssessmentsUseCase(assessmentRepository: repository)

        let criticalAssessment = Assessment(
            title: "Urgent Lab",
            dueDate: referenceDate.addingTimeInterval(86400 * 1), // Critical
            weighting: 35.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.0,
            isCompleted: false
        )

        // Two medium assessments with different due dates for tie-breaker testing
        let mediumEarlier = Assessment(
            title: "Medium Earlier",
            dueDate: referenceDate.addingTimeInterval(86400 * 4), // Due earlier
            weighting: 5.0,
            estimatedWorkloadHours: 4.0,
            progress: 0.0,
            isCompleted: false
        )

        let mediumLater = Assessment(
            title: "Medium Later",
            dueDate: referenceDate.addingTimeInterval(86400 * 6), // Due later
            weighting: 5.0,
            estimatedWorkloadHours: 4.0,
            progress: 0.0,
            isCompleted: false
        )

        let lowAssessment = Assessment(
            title: "Far Away Quiz",
            dueDate: referenceDate.addingTimeInterval(86400 * 30),
            weighting: 5.0,
            estimatedWorkloadHours: 2.0,
            progress: 0.0,
            isCompleted: false
        )

        // Feed repository in unordered fashion
        repository.assessmentsToReturn = [mediumLater, lowAssessment, criticalAssessment, mediumEarlier]

        let result = try await useCase.execute(relativeTo: referenceDate)

        #expect(result.count == 4)
        #expect(result[0].title == "Urgent Lab")        // Critical
        #expect(result[1].title == "Medium Earlier")    // Medium (due in 4 days)
        #expect(result[2].title == "Medium Later")      // Medium (due in 6 days)
        #expect(result[3].title == "Far Away Quiz")     // Low
    }

    @Test("Completed assessments and 100% progress assessments are excluded")
    func testCompletedAssessmentsExcluded() async throws {
        let repository = MockAssessmentRepository()
        let useCase = GetPriorityAssessmentsUseCase(assessmentRepository: repository)

        let activeAssessment = Assessment(
            title: "Active Task",
            dueDate: referenceDate.addingTimeInterval(86400 * 3),
            weighting: 10.0,
            estimatedWorkloadHours: 5.0,
            progress: 0.2,
            isCompleted: false
        )

        let completedAssessment = Assessment(
            title: "Completed Task",
            dueDate: referenceDate.addingTimeInterval(86400 * 1),
            weighting: 40.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.5,
            isCompleted: true
        )

        let fullyProgressed = Assessment(
            title: "100% Progress Task",
            dueDate: referenceDate.addingTimeInterval(86400 * 2),
            weighting: 25.0,
            estimatedWorkloadHours: 10.0,
            progress: 1.0,
            isCompleted: false
        )

        repository.assessmentsToReturn = [activeAssessment, completedAssessment, fullyProgressed]

        let result = try await useCase.execute(relativeTo: referenceDate)

        #expect(result.count == 1)
        #expect(result.first?.title == "Active Task")
    }

    @Test("Empty repository returns empty result")
    func testEmptyRepository() async throws {
        let repository = MockAssessmentRepository()
        let useCase = GetPriorityAssessmentsUseCase(assessmentRepository: repository)

        repository.assessmentsToReturn = []

        let result = try await useCase.execute(relativeTo: referenceDate)
        #expect(result.isEmpty)
    }

    @Test("Repository failure propagates error")
    func testRepositoryFailure() async {
        let repository = MockAssessmentRepository()
        repository.shouldFail = true
        let useCase = GetPriorityAssessmentsUseCase(assessmentRepository: repository)

        await #expect(throws: Error.self) {
            _ = try await useCase.execute(relativeTo: referenceDate)
        }
    }
}

// MARK: - Use Case 3 Tests: GetNextClassUseCase

@Suite("GetNextClassUseCase Tests")
struct GetNextClassUseCaseTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Next future class is selected chronologically")
    func testNextFutureClassSelected() async throws {
        let repository = MockClassSessionRepository()
        let useCase = GetNextClassUseCase(classSessionRepository: repository)

        let classLaterToday = ClassSession(
            classType: .lecture,
            startDate: referenceDate.addingTimeInterval(3600 * 2), // 2 hours from now
            endDate: referenceDate.addingTimeInterval(3600 * 3),
            campus: "Parkville",
            building: "Peter Hall",
            room: "JH"
        )

        let classTomorrow = ClassSession(
            classType: .workshop,
            startDate: referenceDate.addingTimeInterval(86400),
            endDate: referenceDate.addingTimeInterval(86400 + 7200),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "Lab 2"
        )

        repository.sessionsToReturn = [classTomorrow, classLaterToday]

        let nextClass = try await useCase.execute(relativeTo: referenceDate)

        #expect(nextClass?.classType == .lecture)
        #expect(nextClass?.room == "JH")
    }

    @Test("Past classes are ignored")
    func testPastClassesIgnored() async throws {
        let repository = MockClassSessionRepository()
        let useCase = GetNextClassUseCase(classSessionRepository: repository)

        let pastClass = ClassSession(
            classType: .tutorial,
            startDate: referenceDate.addingTimeInterval(-7200), // 2 hours ago
            endDate: referenceDate.addingTimeInterval(-3600),
            campus: "Parkville",
            building: "Old Geology",
            room: "101"
        )

        let upcomingClass = ClassSession(
            classType: .lab,
            startDate: referenceDate.addingTimeInterval(3600), // 1 hour from now
            endDate: referenceDate.addingTimeInterval(7200),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "3.01"
        )

        repository.sessionsToReturn = [pastClass, upcomingClass]

        let nextClass = try await useCase.execute(relativeTo: referenceDate)

        #expect(nextClass?.classType == .lab)
        #expect(nextClass?.room == "3.01")
    }

    @Test("Returns nil when there are no future classes")
    func testNoFutureClassesReturnsNil() async throws {
        let repository = MockClassSessionRepository()
        let useCase = GetNextClassUseCase(classSessionRepository: repository)

        let pastClass = ClassSession(
            classType: .lecture,
            startDate: referenceDate.addingTimeInterval(-3600),
            endDate: referenceDate.addingTimeInterval(-1800),
            campus: "Parkville",
            building: "Peter Hall",
            room: "JH"
        )

        repository.sessionsToReturn = [pastClass]

        let nextClass = try await useCase.execute(relativeTo: referenceDate)
        #expect(nextClass == nil)
    }

    @Test("Repository failure propagates error")
    func testRepositoryFailure() async {
        let repository = MockClassSessionRepository()
        repository.shouldFail = true
        let useCase = GetNextClassUseCase(classSessionRepository: repository)

        await #expect(throws: Error.self) {
            _ = try await useCase.execute(relativeTo: referenceDate)
        }
    }
}

// MARK: - Use Case 4 Tests: GetClassPreparationUseCase

@Suite("GetClassPreparationUseCase Tests")
struct GetClassPreparationUseCaseTests {
    let sessionId = UUID()

    @Test("Preparation items returned correctly in predictable order")
    func testPredictableOrdering() async throws {
        let repository = MockPreparationItemRepository()
        let useCase = GetClassPreparationUseCase(preparationItemRepository: repository)

        let item3 = PreparationItem(
            classSessionId: sessionId,
            title: "Download Slides",
            orderIndex: 2
        )
        let item1 = PreparationItem(
            classSessionId: sessionId,
            title: "Charged Laptop",
            orderIndex: 0
        )
        let item2 = PreparationItem(
            classSessionId: sessionId,
            title: "Complete Pre-Reading",
            orderIndex: 1
        )

        repository.itemsToReturn = [item3, item1, item2]

        let result = try await useCase.execute(forSessionId: sessionId)

        #expect(result.count == 3)
        #expect(result[0].title == "Charged Laptop")
        #expect(result[1].title == "Complete Pre-Reading")
        #expect(result[2].title == "Download Slides")
    }

    @Test("Completed and incomplete items are both preserved")
    func testCompletedAndIncompletePreserved() async throws {
        let repository = MockPreparationItemRepository()
        let useCase = GetClassPreparationUseCase(preparationItemRepository: repository)

        let completed = PreparationItem(
            classSessionId: sessionId,
            title: "Read Chapter 1",
            isCompleted: true,
            orderIndex: 0
        )
        let pending = PreparationItem(
            classSessionId: sessionId,
            title: "Bring Lab Coat",
            isCompleted: false,
            orderIndex: 1
        )

        repository.itemsToReturn = [completed, pending]

        let result = try await useCase.execute(forSessionId: sessionId)

        #expect(result.count == 2)
        #expect(result[0].isCompleted == true)
        #expect(result[1].isCompleted == false)
    }

    @Test("Empty result returned when session has no preparation items")
    func testEmptyResult() async throws {
        let repository = MockPreparationItemRepository()
        let useCase = GetClassPreparationUseCase(preparationItemRepository: repository)

        repository.itemsToReturn = []

        let result = try await useCase.execute(forSessionId: sessionId)
        #expect(result.isEmpty)
    }

    @Test("Repository failure propagates error")
    func testRepositoryFailure() async {
        let repository = MockPreparationItemRepository()
        repository.shouldFail = true
        let useCase = GetClassPreparationUseCase(preparationItemRepository: repository)

        await #expect(throws: Error.self) {
            _ = try await useCase.execute(forSessionId: sessionId)
        }
    }
}
