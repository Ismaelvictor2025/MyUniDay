//
//  Stage6HomeRedesignTests.swift
//  MyUniDayTests
//
//  Unit tests verifying Stage 6 Home Redesign business logic:
//  - Study Now smart prioritisation recommendation
//  - My Progress academic productivity & completion calculations
//  - Reminders aggregation across assessments, classes, and tasks
//  - Zero-state and empty-state robustness (preventing divide-by-zero)
//

import Testing
import Foundation
@testable import MyUniDay

@Suite("Stage 6 Home Redesign & Features Tests")
@MainActor
struct Stage6HomeRedesignTests {

    private func makeTestContainer() -> AppDependencyContainer {
        #if DEBUG
        return DevelopmentDemoData.makeDemoContainer()
        #else
        return AppDependencyContainer(persistenceController: PersistenceController(inMemory: true))
        #endif
    }

    // MARK: - 1. Study Now Recommendation Tests

    @Test("GetStudyNowRecommendationUseCase selects the highest priority incomplete assessment")
    func testStudyNowSelectsHighestPriorityAssessment() async throws {
        let container = makeTestContainer()
        let recommendation = try await container.getStudyNowRecommendationUseCase.execute()

        let rec = try #require(recommendation)
        // In demo data, Assignment 2 (COMP2014) is Critical due in 2 days at 65% progress
        #expect(rec.assessment.title.contains("Assignment 2"))
        #expect(rec.priority == .critical)
        #expect(rec.remainingHours > 0)
        #expect(!rec.recommendedActionTitle.isEmpty)
        #expect(rec.nextPendingTask != nil)
    }

    @Test("GetStudyNowRecommendationUseCase returns nil when all assessments are completed")
    func testStudyNowReturnsNilWhenAllCompleted() async throws {
        // Create an isolated assessment repository with only completed assessments
        let completedTask = AssessmentTask(title: "Done task", isCompleted: true)
        let completedAssessment = Assessment(
            title: "Completed Project",
            dueDate: Date().addingTimeInterval(86400),
            weighting: 20.0,
            estimatedWorkloadHours: 10.0,
            progress: 1.0,
            isCompleted: true,
            tasks: [completedTask]
        )

        #if DEBUG
        let assessmentRepo = DevelopmentDemoData.DemoAssessmentRepository(assessments: [completedAssessment])
        let calcPriority = CalculateAssessmentPriorityUseCase()
        let getPriorityUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: assessmentRepo,
            calculatePriorityUseCase: calcPriority
        )
        let studyNowUseCase = GetStudyNowRecommendationUseCase(
            getPriorityAssessmentsUseCase: getPriorityUseCase,
            calculatePriorityUseCase: calcPriority
        )

        let result = try await studyNowUseCase.execute()
        #expect(result == nil)
        #endif
    }

    // MARK: - 2. My Progress Calculation Tests

    @Test("CalculateAcademicProgressUseCase derives legitimate completion metrics")
    func testAcademicProgressMetrics() async throws {
        let container = makeTestContainer()
        let report = try await container.calculateAcademicProgressUseCase.execute()

        #expect(report.totalAssessments > 0)
        #expect(report.totalTasks > 0)
        #expect(report.totalPreparationItems > 0)

        // Rates must be bounded between 0.0 and 1.0
        #expect(report.assessmentCompletionRate >= 0.0 && report.assessmentCompletionRate <= 1.0)
        #expect(report.taskCompletionRate >= 0.0 && report.taskCompletionRate <= 1.0)
        #expect(report.preparationCompletionRate >= 0.0 && report.preparationCompletionRate <= 1.0)
        #expect(report.overallCompletionRate >= 0.0 && report.overallCompletionRate <= 1.0)

        // Check math consistency
        #expect(report.completedAssessments + report.remainingAssessments == report.totalAssessments)
        #expect(report.completedTasks + report.remainingTasks == report.totalTasks)
        #expect(report.completedPreparationItems + report.remainingPreparationItems == report.totalPreparationItems)

        // Subject breakdowns exist
        #expect(!report.subjectSummaries.isEmpty)
        for summary in report.subjectSummaries {
            #expect(!summary.subjectCode.isEmpty)
            #expect(summary.progressRate >= 0.0 && summary.progressRate <= 1.0)
        }
    }

    @Test("CalculateAcademicProgressUseCase safely handles empty repositories without dividing by zero")
    func testAcademicProgressEmptyStateSafety() async throws {
        #if DEBUG
        let emptyAssessmentRepo = DevelopmentDemoData.DemoAssessmentRepository(assessments: [])
        let emptyPrepRepo = DevelopmentDemoData.DemoPreparationItemRepository(items: [:])
        let emptySubjectRepo = DevelopmentDemoData.DemoSubjectRepository(subjects: [])

        let useCase = CalculateAcademicProgressUseCase(
            assessmentRepository: emptyAssessmentRepo,
            preparationItemRepository: emptyPrepRepo,
            subjectRepository: emptySubjectRepo
        )

        let report = try await useCase.execute()
        #expect(report.totalAssessments == 0)
        #expect(report.completedAssessments == 0)
        #expect(report.assessmentCompletionRate == 0.0)
        #expect(report.overallCompletionRate == 0.0)
        #expect(report.subjectSummaries.isEmpty)
        #endif
    }

    // MARK: - 3. Reminders Aggregation Tests

    @Test("RemindersViewModel aggregates upcoming deadlines, prep, and tasks")
    func testRemindersAggregationAndFiltering() async throws {
        let container = makeTestContainer()
        let viewModel = container.makeRemindersViewModel()

        await viewModel.loadReminders()

        #expect(!viewModel.reminders.isEmpty)

        // Category filtering: Assessments
        viewModel.selectedCategory = .assessments
        #expect(viewModel.filteredReminders.allSatisfy { $0.category == .assessments })

        // Category filtering: Classes & Prep
        viewModel.selectedCategory = .classes
        #expect(viewModel.filteredReminders.allSatisfy { $0.category == .classes })

        // Category filtering: Tasks
        viewModel.selectedCategory = .tasks
        #expect(viewModel.filteredReminders.allSatisfy { $0.category == .tasks })

        // Category filtering: All
        viewModel.selectedCategory = .all
        #expect(viewModel.filteredReminders.count == viewModel.reminders.count)
    }

    // MARK: - 4. Study Now & Progress ViewModel State Tests

    @Test("StudyNowViewModel coordinates recommendation and subject details")
    func testStudyNowViewModel() async throws {
        let container = makeTestContainer()
        let viewModel = container.makeStudyNowViewModel()

        await viewModel.loadRecommendation()

        #expect(viewModel.recommendation != nil)
        #expect(viewModel.subject != nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("MyProgressViewModel successfully loads progress report")
    func testMyProgressViewModel() async throws {
        let container = makeTestContainer()
        let viewModel = container.makeMyProgressViewModel()

        await viewModel.loadProgress()

        #expect(viewModel.report.totalAssessments > 0)
        #expect(viewModel.errorMessage == nil)
    }
}
