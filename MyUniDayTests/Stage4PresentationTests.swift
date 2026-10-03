//
//  Stage4PresentationTests.swift
//  MyUniDayTests
//
//  Unit tests covering Stage 4 presentation wiring, composition, and demo isolation:
//  - DashboardViewModel prioritisedAssessments exposure
//  - AppDependencyContainer dependency composition
//  - DevelopmentDemoData population and isolation guarantees
//

import Testing
import Foundation
import CoreData
@testable import MyUniDay

@Suite("Stage 4 Presentation & Composition Tests")
@MainActor
struct Stage4PresentationTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("DashboardViewModel exposes prioritisedAssessments paired with priority classifications")
    func testPrioritisedAssessmentsPaired() async {
        let assessmentRepo = MockAssessmentRepository()
        let classSessionRepo = MockClassSessionRepository()
        let prepRepo = MockPreparationItemRepository()

        let criticalAssessment = Assessment(
            title: "Urgent Project",
            dueDate: referenceDate.addingTimeInterval(86400 * 1),
            weighting: 40.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.0,
            isCompleted: false
        )

        let mediumAssessment = Assessment(
            title: "Weekly Task",
            dueDate: referenceDate.addingTimeInterval(86400 * 6),
            weighting: 5.0,
            estimatedWorkloadHours: 3.0,
            progress: 0.0,
            isCompleted: false
        )

        assessmentRepo.assessmentsToReturn = [criticalAssessment, mediumAssessment]

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
            getClassPreparationUseCase: getClassPrepUseCase,
            calculatePriorityUseCase: priorityUseCase
        )

        await viewModel.loadDashboard(relativeTo: referenceDate)

        #expect(viewModel.prioritisedAssessments.count == 2)
        #expect(viewModel.prioritisedAssessments[0].assessment.title == "Urgent Project")
        #expect(viewModel.prioritisedAssessments[0].priority == .critical)
        #expect(viewModel.prioritisedAssessments[1].assessment.title == "Weekly Task")
        #expect(viewModel.prioritisedAssessments[1].priority == .medium)
    }

    @Test("AppDependencyContainer correctly wires dependencies and creates a functional DashboardViewModel")
    func testAppDependencyContainerComposition() async {
        let inMemoryPersistence = PersistenceController(inMemory: true)
        let container = AppDependencyContainer(persistenceController: inMemoryPersistence)

        let viewModel = container.makeDashboardViewModel()

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.prioritisedAssessments.isEmpty)
        #expect(viewModel.nextClass == nil)

        // Verify executing loadDashboard runs cleanly against the in-memory store
        await viewModel.loadDashboard()

        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    #if DEBUG
    @Test("DevelopmentDemoData populates realistic university dataset for simulator review")
    func testDevelopmentDemoDataPopulated() async {
        let demoViewModel = DevelopmentDemoData.makeDemoViewModel()

        await demoViewModel.loadDashboard()

        // 1. Verify priority assessments (Assignment 2 + Weekly Quiz)
        #expect(demoViewModel.prioritisedAssessments.count == 2)
        let hero = demoViewModel.prioritisedAssessments.first
        #expect(hero?.assessment.title.contains("Assignment 2") == true)
        #expect(hero?.assessment.progress == 0.65)
        #expect(hero?.priority == .critical || hero?.priority == .high)

        // 2. Verify next class session (Building EA, Room 15)
        #expect(demoViewModel.nextClass != nil)
        #expect(demoViewModel.nextClass?.building == "Building EA")
        #expect(demoViewModel.nextClass?.room == "Room 15")

        // 3. Verify preparation items (3 items: Laptop, Xcode, Questions)
        #expect(demoViewModel.nextClassPreparationItems.count == 3)
        #expect(demoViewModel.nextClassPreparationItems[0].title == "Laptop & charger")
        #expect(demoViewModel.nextClassPreparationItems[0].isCompleted == true)
        #expect(demoViewModel.nextClassPreparationItems[2].isCompleted == false)
    }

    @Test("DevelopmentDemoData does not write to or contaminate an independent store")
    func testDevelopmentDemoDataIsolation() async {
        let cleanPersistence = PersistenceController(inMemory: true)
        let cleanRepo = CoreDataAssessmentRepository(context: cleanPersistence.container.viewContext)

        // Generate demo view model (which seeds into its own private in-memory store)
        let _ = DevelopmentDemoData.makeDemoViewModel()

        // Verify independent clean persistence remains 100% empty
        let cleanAssessments = try? await cleanRepo.fetchIncompleteAssessments(
            dueBetween: .distantPast,
            and: .distantFuture
        )
        #expect(cleanAssessments?.isEmpty == true)
    }
    #endif
}
