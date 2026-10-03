//
//  DevelopmentDemoData.swift
//  MyUniDay
//
//  Isolated development-only demo data provider for simulator evaluation.
//

#if DEBUG
import Foundation

/// Development-only helper providing deterministic, realistic sample data for UI verification.
///
/// **Safety & Architecture Guarantees:**
/// - Demo data is housed in isolated in-memory repositories conforming to domain protocols.
/// - Completely isolated from production Core Data repositories and SQLite stores.
/// - Never writes to, modifies, or silently seeds the production persistent store.
/// - Fully isolated under `#if DEBUG` and compiled out of release builds.
@MainActor
public enum DevelopmentDemoData {

    /// Isolated in-memory repository for demo assessments.
    private final class DemoAssessmentRepository: AssessmentRepositoryProtocol {
        var assessments: [Assessment]

        init(assessments: [Assessment]) {
            self.assessments = assessments
        }

        func fetchAssessments(forSubjectId subjectId: UUID) async throws -> [Assessment] {
            assessments
        }

        func fetchAssessment(by id: UUID) async throws -> Assessment? {
            assessments.first { $0.id == id }
        }

        func fetchIncompleteAssessments(dueBetween startDate: Date, and endDate: Date) async throws -> [Assessment] {
            assessments.filter { !$0.isCompleted && $0.dueDate >= startDate && $0.dueDate <= endDate }
        }

        func save(assessment: Assessment, forSubjectId subjectId: UUID) async throws {
            assessments.append(assessment)
        }

        func deleteAssessment(by id: UUID) async throws {
            assessments.removeAll { $0.id == id }
        }
    }

    /// Isolated in-memory repository for demo class sessions.
    private final class DemoClassSessionRepository: ClassSessionRepositoryProtocol {
        var sessions: [ClassSession]

        init(sessions: [ClassSession]) {
            self.sessions = sessions
        }

        func fetchClassSessions(forSubjectId subjectId: UUID) async throws -> [ClassSession] {
            sessions
        }

        func fetchClassSession(by id: UUID) async throws -> ClassSession? {
            sessions.first { $0.id == id }
        }

        func fetchUpcomingClassSessions(from date: Date) async throws -> [ClassSession] {
            sessions
                .filter { $0.startDate >= date }
                .sorted { $0.startDate < $1.startDate }
        }

        func save(classSession: ClassSession, forSubjectId subjectId: UUID) async throws {
            sessions.append(classSession)
        }

        func deleteClassSession(by id: UUID) async throws {
            sessions.removeAll { $0.id == id }
        }
    }

    /// Isolated in-memory repository for demo preparation items.
    private final class DemoPreparationItemRepository: PreparationItemRepositoryProtocol {
        var items: [UUID: [PreparationItem]]

        init(items: [UUID: [PreparationItem]]) {
            self.items = items
        }

        func fetchPreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
            items[sessionId] ?? []
        }

        func fetchIncompletePreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
            (items[sessionId] ?? []).filter { !$0.isCompleted }
        }

        func save(item: PreparationItem, forSessionId sessionId: UUID) async throws {
            var sessionItems = items[sessionId] ?? []
            sessionItems.append(item)
            items[sessionId] = sessionItems
        }

        func deletePreparationItem(by id: UUID) async throws {
            for (key, list) in items {
                items[key] = list.filter { $0.id != id }
            }
        }
    }

    /// Creates an isolated in-memory `DashboardViewModel` pre-populated with realistic university data.
    public static func makeDemoViewModel() -> DashboardViewModel {
        let referenceNow = Date()

        // 1. Hero Assessment: Assignment 2 (65% progress, due in 2 days)
        let task1 = AssessmentTask(
            title: "Implement inheritance hierarchy",
            isCompleted: true,
            orderIndex: 0
        )
        let task2 = AssessmentTask(
            title: "Unit test core services",
            isCompleted: false,
            orderIndex: 1
        )
        let assignment2 = Assessment(
            title: "Assignment 2: Polymorphic System",
            dueDate: referenceNow.addingTimeInterval(86400 * 2), // 2 days away
            weighting: 35.0,
            estimatedWorkloadHours: 18.0,
            progress: 0.65,
            isCompleted: false,
            notes: "COMP2014 Object Oriented Programming",
            tasks: [task1, task2]
        )

        // 2. Secondary Assessment: Weekly Workshop Quiz
        let quiz = Assessment(
            title: "Weekly Workshop Quiz 4",
            dueDate: referenceNow.addingTimeInterval(86400 * 6), // 6 days away
            weighting: 5.0,
            estimatedWorkloadHours: 2.0,
            progress: 0.20,
            isCompleted: false,
            notes: "COMP2014 Object Oriented Programming"
        )

        // 3. Next Class Session: Workshop at Building EA Room 15 in 2 hours
        let sessionId = UUID()
        let prepItems = [
            PreparationItem(
                title: "Laptop & charger",
                notes: "Charged to at least 80%",
                isCompleted: true,
                orderIndex: 0
            ),
            PreparationItem(
                title: "Xcode project cloned",
                notes: "Branch: main",
                isCompleted: true,
                orderIndex: 1
            ),
            PreparationItem(
                title: "Assignment questions prepared",
                notes: "Review Section 3 requirements",
                isCompleted: false,
                orderIndex: 2
            )
        ]

        let session = ClassSession(
            id: sessionId,
            classType: .workshop,
            startDate: referenceNow.addingTimeInterval(3600 * 2), // In 2 hours
            endDate: referenceNow.addingTimeInterval(3600 * 4),
            campus: "City",
            building: "Building EA",
            room: "Room 15",
            preparationItems: prepItems
        )

        // Assemble isolated demo repositories
        let demoAssessmentRepo = DemoAssessmentRepository(assessments: [assignment2, quiz])
        let demoClassSessionRepo = DemoClassSessionRepository(sessions: [session])
        let demoPrepRepo = DemoPreparationItemRepository(items: [sessionId: prepItems])

        let priorityUseCase = CalculateAssessmentPriorityUseCase()
        let getPriorityUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: demoAssessmentRepo,
            calculatePriorityUseCase: priorityUseCase
        )
        let getNextClassUseCase = GetNextClassUseCase(classSessionRepository: demoClassSessionRepo)
        let getClassPrepUseCase = GetClassPreparationUseCase(preparationItemRepository: demoPrepRepo)

        return DashboardViewModel(
            getPriorityAssessmentsUseCase: getPriorityUseCase,
            getNextClassUseCase: getNextClassUseCase,
            getClassPreparationUseCase: getClassPrepUseCase,
            calculatePriorityUseCase: priorityUseCase
        )
    }
}
#endif
