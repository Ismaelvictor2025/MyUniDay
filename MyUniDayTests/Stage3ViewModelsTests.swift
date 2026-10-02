//
//  Stage3ViewModelsTests.swift
//  MyUniDayTests
//
//  Unit tests covering Stage 3 Presentation ViewModels:
//  - DashboardViewModel
//  - AssessmentsViewModel
//  - NextClassViewModel
//  - ClassPreparationViewModel
//

import Testing
import Foundation
@testable import MyUniDay

// MARK: - 1. DashboardViewModel Tests

@Suite("DashboardViewModel Tests")
@MainActor
struct DashboardViewModelTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeViewModel(
        assessmentRepo: MockAssessmentRepository = MockAssessmentRepository(),
        classSessionRepo: MockClassSessionRepository = MockClassSessionRepository(),
        prepRepo: MockPreparationItemRepository = MockPreparationItemRepository()
    ) -> (DashboardViewModel, MockAssessmentRepository, MockClassSessionRepository, MockPreparationItemRepository) {
        let priorityUseCase = CalculateAssessmentPriorityUseCase()
        let getPriorityUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: assessmentRepo,
            calculatePriorityUseCase: priorityUseCase
        )
        let getNextClassUseCase = GetNextClassUseCase(classSessionRepository: classSessionRepo)
        let getClassPrepUseCase = GetClassPreparationUseCase(preparationItemRepository: prepRepo)

        let viewModel = DashboardViewModel(
            getPriorityAssessmentsUseCase: getPriorityUseCase,
            getNextClassUseCase: getNextClassUseCase,
            getClassPreparationUseCase: getClassPrepUseCase
        )

        return (viewModel, assessmentRepo, classSessionRepo, prepRepo)
    }

    @Test("Successful load exposes priority assessments, next class, and class preparation")
    func testSuccessfulLoadWithNextClassAndPreparation() async {
        let (viewModel, assessmentRepo, classSessionRepo, prepRepo) = makeViewModel()

        let assessment = Assessment(
            title: "Major Project",
            dueDate: referenceDate.addingTimeInterval(86400 * 2),
            weighting: 35.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.1,
            isCompleted: false
        )
        assessmentRepo.assessmentsToReturn = [assessment]

        let session = ClassSession(
            classType: .workshop,
            startDate: referenceDate.addingTimeInterval(3600 * 2),
            endDate: referenceDate.addingTimeInterval(3600 * 4),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "3.02"
        )
        classSessionRepo.sessionsToReturn = [session]

        let prepItem = PreparationItem(
            classSessionId: session.id,
            title: "Bring Laptop",
            isCompleted: false
        )
        prepRepo.itemsToReturn = [prepItem]

        await viewModel.loadDashboard(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.priorityAssessments.count == 1)
        #expect(viewModel.priorityAssessments.first?.title == "Major Project")
        #expect(viewModel.nextClass?.room == "3.02")
        #expect(viewModel.nextClassPreparationItems.count == 1)
        #expect(viewModel.nextClassPreparationItems.first?.title == "Bring Laptop")
    }

    @Test("Behavior when there is no upcoming class clears next-class preparation")
    func testLoadWhenNoUpcomingClass() async {
        let (viewModel, assessmentRepo, classSessionRepo, prepRepo) = makeViewModel()

        let assessment = Assessment(
            title: "Weekly Quiz",
            dueDate: referenceDate.addingTimeInterval(86400 * 5),
            weighting: 5.0,
            estimatedWorkloadHours: 2.0,
            isCompleted: false
        )
        assessmentRepo.assessmentsToReturn = [assessment]
        classSessionRepo.sessionsToReturn = [] // No upcoming classes
        prepRepo.itemsToReturn = [PreparationItem(title: "Unused Item")]

        await viewModel.loadDashboard(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.priorityAssessments.count == 1)
        #expect(viewModel.nextClass == nil)
        #expect(viewModel.nextClassPreparationItems.isEmpty)
    }

    @Test("Dependency failure produces an appropriate user-facing error state")
    func testDependencyFailureProducesError() async {
        let (viewModel, assessmentRepo, _, _) = makeViewModel()
        assessmentRepo.shouldFail = true

        await viewModel.loadDashboard(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage == "Unable to load dashboard data. Please try again.")
    }

    @Test("Refresh operation updates dashboard data")
    func testRefreshCoordinatesData() async {
        let (viewModel, assessmentRepo, classSessionRepo, _) = makeViewModel()

        assessmentRepo.assessmentsToReturn = []
        classSessionRepo.sessionsToReturn = []

        await viewModel.refresh(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.priorityAssessments.isEmpty)
        #expect(viewModel.nextClass == nil)
    }
}

// MARK: - 2. AssessmentsViewModel Tests

@Suite("AssessmentsViewModel Tests")
@MainActor
struct AssessmentsViewModelTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeViewModel(
        assessmentRepo: MockAssessmentRepository = MockAssessmentRepository()
    ) -> (AssessmentsViewModel, MockAssessmentRepository) {
        let calculatePriorityUseCase = CalculateAssessmentPriorityUseCase()
        let getPriorityUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: assessmentRepo,
            calculatePriorityUseCase: calculatePriorityUseCase
        )
        let viewModel = AssessmentsViewModel(
            getPriorityAssessmentsUseCase: getPriorityUseCase,
            calculatePriorityUseCase: calculatePriorityUseCase
        )
        return (viewModel, assessmentRepo)
    }

    @Test("Prioritised assessments exposed correctly with paired priority")
    func testPrioritisedAssessmentsExposedCorrectly() async {
        let (viewModel, assessmentRepo) = makeViewModel()

        let criticalAssessment = Assessment(
            title: "Final Submission",
            dueDate: referenceDate.addingTimeInterval(86400 * 1), // Critical
            weighting: 40.0,
            estimatedWorkloadHours: 25.0,
            progress: 0.0,
            isCompleted: false
        )

        let lowAssessment = Assessment(
            title: "Reading Log",
            dueDate: referenceDate.addingTimeInterval(86400 * 25), // Low
            weighting: 5.0,
            estimatedWorkloadHours: 2.0,
            progress: 0.0,
            isCompleted: false
        )

        assessmentRepo.assessmentsToReturn = [lowAssessment, criticalAssessment]

        await viewModel.loadAssessments(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isEmpty)
        #expect(viewModel.items.count == 2)

        // First item must be critical
        #expect(viewModel.items[0].assessment.title == "Final Submission")
        #expect(viewModel.items[0].priority == .critical)

        // Second item must be low
        #expect(viewModel.items[1].assessment.title == "Reading Log")
        #expect(viewModel.items[1].priority == .low)

        // Underlying domain accessor
        #expect(viewModel.assessments.count == 2)
        #expect(viewModel.assessments.first?.title == "Final Submission")
    }

    @Test("Empty assessment result sets isEmpty correctly")
    func testEmptyAssessmentResult() async {
        let (viewModel, assessmentRepo) = makeViewModel()
        assessmentRepo.assessmentsToReturn = []

        await viewModel.loadAssessments(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
    }

    @Test("Failure state sets error message")
    func testFailureState() async {
        let (viewModel, assessmentRepo) = makeViewModel()
        assessmentRepo.shouldFail = true

        await viewModel.loadAssessments(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.items.isEmpty)
    }

    @Test("Filtering by subjectId loads assessments for that subject")
    func testFilterBySubjectId() async {
        let (viewModel, assessmentRepo) = makeViewModel()
        let targetSubjectId = UUID()
        let otherSubjectId = UUID()

        let targetAssessment = Assessment(
            subjectId: targetSubjectId,
            title: "Subject A Assessment",
            dueDate: referenceDate.addingTimeInterval(86400 * 3),
            weighting: 15.0,
            estimatedWorkloadHours: 8.0,
            isCompleted: false
        )

        let otherAssessment = Assessment(
            subjectId: otherSubjectId,
            title: "Subject B Assessment",
            dueDate: referenceDate.addingTimeInterval(86400 * 3),
            weighting: 15.0,
            estimatedWorkloadHours: 8.0,
            isCompleted: false
        )

        assessmentRepo.assessmentsToReturn = [targetAssessment, otherAssessment]

        await viewModel.loadAssessments(relativeTo: referenceDate, subjectId: targetSubjectId)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.assessment.title == "Subject A Assessment")
    }
}

// MARK: - 3. NextClassViewModel Tests

@Suite("NextClassViewModel Tests")
@MainActor
struct NextClassViewModelTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeViewModel(
        classSessionRepo: MockClassSessionRepository = MockClassSessionRepository()
    ) -> (NextClassViewModel, MockClassSessionRepository) {
        let getNextClassUseCase = GetNextClassUseCase(classSessionRepository: classSessionRepo)
        let viewModel = NextClassViewModel(getNextClassUseCase: getNextClassUseCase)
        return (viewModel, classSessionRepo)
    }

    @Test("Upcoming class exposed correctly")
    func testUpcomingClassExposed() async {
        let (viewModel, classSessionRepo) = makeViewModel()

        let pastClass = ClassSession(
            classType: .lecture,
            startDate: referenceDate.addingTimeInterval(-3600),
            endDate: referenceDate.addingTimeInterval(-1800),
            campus: "Parkville",
            building: "Peter Hall",
            room: "JH"
        )

        let futureClass = ClassSession(
            classType: .lab,
            startDate: referenceDate.addingTimeInterval(3600),
            endDate: referenceDate.addingTimeInterval(7200),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "Lab 1.02"
        )

        classSessionRepo.sessionsToReturn = [pastClass, futureClass]

        await viewModel.loadNextClass(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasNextClass)
        #expect(viewModel.nextClass?.room == "Lab 1.02")
        #expect(viewModel.nextClass?.classType == .lab)
    }

    @Test("No upcoming class state handled cleanly")
    func testNoUpcomingClassState() async {
        let (viewModel, classSessionRepo) = makeViewModel()
        classSessionRepo.sessionsToReturn = []

        await viewModel.loadNextClass(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.hasNextClass)
        #expect(viewModel.nextClass == nil)
    }

    @Test("Failure state sets error message")
    func testFailureState() async {
        let (viewModel, classSessionRepo) = makeViewModel()
        classSessionRepo.shouldFail = true

        await viewModel.loadNextClass(relativeTo: referenceDate)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.nextClass == nil)
        #expect(!viewModel.hasNextClass)
    }
}

// MARK: - 4. ClassPreparationViewModel Tests

@Suite("ClassPreparationViewModel Tests")
@MainActor
struct ClassPreparationViewModelTests {
    let sessionId = UUID()

    private func makeViewModel(
        prepRepo: MockPreparationItemRepository = MockPreparationItemRepository()
    ) -> (ClassPreparationViewModel, MockPreparationItemRepository) {
        let useCase = GetClassPreparationUseCase(preparationItemRepository: prepRepo)
        let viewModel = ClassPreparationViewModel(getClassPreparationUseCase: useCase)
        return (viewModel, prepRepo)
    }

    @Test("Checklist exposed correctly with completed count, remaining count, and progress")
    func testChecklistMetricsCalculatedCorrectly() async {
        let (viewModel, prepRepo) = makeViewModel()

        let item1 = PreparationItem(
            classSessionId: sessionId,
            title: "Download skeleton code",
            isCompleted: true,
            orderIndex: 0
        )
        let item2 = PreparationItem(
            classSessionId: sessionId,
            title: "Bring Laptop",
            isCompleted: true,
            orderIndex: 1
        )
        let item3 = PreparationItem(
            classSessionId: sessionId,
            title: "Read Chapter 4",
            isCompleted: false,
            orderIndex: 2
        )
        let item4 = PreparationItem(
            classSessionId: sessionId,
            title: "Install Simulator",
            isCompleted: false,
            orderIndex: 3
        )

        prepRepo.itemsToReturn = [item4, item1, item3, item2]

        await viewModel.loadPreparation(forSessionId: sessionId)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isEmpty)
        #expect(viewModel.items.count == 4)

        // Predictable order
        #expect(viewModel.items[0].title == "Download skeleton code")
        #expect(viewModel.items[1].title == "Bring Laptop")
        #expect(viewModel.items[2].title == "Read Chapter 4")
        #expect(viewModel.items[3].title == "Install Simulator")

        // Metric calculations
        #expect(viewModel.completedCount == 2)
        #expect(viewModel.remainingCount == 2)
        #expect(viewModel.progress == 0.5)
    }

    @Test("Empty checklist returns 0 counts and 0.0 progress")
    func testEmptyChecklist() async {
        let (viewModel, prepRepo) = makeViewModel()
        prepRepo.itemsToReturn = []

        await viewModel.loadPreparation(forSessionId: sessionId)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
        #expect(viewModel.completedCount == 0)
        #expect(viewModel.remainingCount == 0)
        #expect(viewModel.progress == 0.0)
    }

    @Test("Failure state sets error message")
    func testFailureState() async {
        let (viewModel, prepRepo) = makeViewModel()
        prepRepo.shouldFail = true

        await viewModel.loadPreparation(forSessionId: sessionId)

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.items.isEmpty)
    }

    @Test("Convenience overload using ClassSession model works identically")
    func testConvenienceLoadWithSessionModel() async {
        let (viewModel, prepRepo) = makeViewModel()
        let session = ClassSession(
            id: sessionId,
            classType: .tutorial,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "Lab 2"
        )

        let item = PreparationItem(
            classSessionId: sessionId,
            title: "Bring Notebook",
            isCompleted: false
        )
        prepRepo.itemsToReturn = [item]

        await viewModel.loadPreparation(for: session)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.title == "Bring Notebook")
    }
}
