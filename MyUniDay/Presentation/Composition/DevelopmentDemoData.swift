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

    /// Isolated in-memory repository for demo subjects.
    public final class DemoSubjectRepository: SubjectRepositoryProtocol {
        public var subjects: [UniversitySubject]

        public init(subjects: [UniversitySubject]) {
            self.subjects = subjects
        }

        public func fetchSubjects() async throws -> [UniversitySubject] {
            subjects
        }

        public func fetchSubject(by id: UUID) async throws -> UniversitySubject? {
            subjects.first { $0.id == id }
        }

        public func save(subject: UniversitySubject) async throws {
            if let idx = subjects.firstIndex(where: { $0.id == subject.id }) {
                subjects[idx] = subject
            } else {
                subjects.append(subject)
            }
        }

        public func deleteSubject(by id: UUID) async throws {
            subjects.removeAll { $0.id == id }
        }
    }

    /// Isolated in-memory repository for demo assessments.
    public final class DemoAssessmentRepository: AssessmentRepositoryProtocol {
        public var assessments: [Assessment]

        public init(assessments: [Assessment]) {
            self.assessments = assessments
        }

        public func fetchAllAssessments() async throws -> [Assessment] {
            assessments
        }

        public func fetchAssessments(forSubjectId subjectId: UUID) async throws -> [Assessment] {
            assessments.filter { $0.subjectId == subjectId }
        }

        public func fetchAssessment(by id: UUID) async throws -> Assessment? {
            assessments.first { $0.id == id }
        }

        public func fetchIncompleteAssessments(dueBetween startDate: Date, and endDate: Date) async throws -> [Assessment] {
            assessments.filter { !$0.isCompleted && $0.dueDate >= startDate && $0.dueDate <= endDate }
        }

        public func save(assessment: Assessment, forSubjectId subjectId: UUID) async throws {
            var updated = assessment
            updated.subjectId = subjectId
            if let idx = assessments.firstIndex(where: { $0.id == assessment.id }) {
                assessments[idx] = updated
            } else {
                assessments.append(updated)
            }
        }

        public func deleteAssessment(by id: UUID) async throws {
            assessments.removeAll { $0.id == id }
        }
    }

    /// Isolated in-memory repository for demo class sessions.
    public final class DemoClassSessionRepository: ClassSessionRepositoryProtocol {
        public var sessions: [ClassSession]

        public init(sessions: [ClassSession]) {
            self.sessions = sessions
        }

        public func fetchAllClassSessions() async throws -> [ClassSession] {
            sessions
        }

        public func fetchClassSessions(forSubjectId subjectId: UUID) async throws -> [ClassSession] {
            sessions.filter { $0.subjectId == subjectId }
        }

        public func fetchClassSession(by id: UUID) async throws -> ClassSession? {
            sessions.first { $0.id == id }
        }

        public func fetchUpcomingClassSessions(from date: Date) async throws -> [ClassSession] {
            sessions
                .filter { $0.startDate >= date }
                .sorted { $0.startDate < $1.startDate }
        }

        public func save(classSession: ClassSession, forSubjectId subjectId: UUID) async throws {
            var updated = classSession
            updated.subjectId = subjectId
            if let idx = sessions.firstIndex(where: { $0.id == classSession.id }) {
                sessions[idx] = updated
            } else {
                sessions.append(updated)
            }
        }

        public func deleteClassSession(by id: UUID) async throws {
            sessions.removeAll { $0.id == id }
        }
    }

    /// Isolated in-memory repository for demo preparation items.
    public final class DemoPreparationItemRepository: PreparationItemRepositoryProtocol {
        public var items: [UUID: [PreparationItem]]
        public weak var classSessionRepo: DemoClassSessionRepository?

        public init(items: [UUID: [PreparationItem]] = [:], classSessionRepo: DemoClassSessionRepository? = nil) {
            self.items = items
            self.classSessionRepo = classSessionRepo
        }

        public func fetchAllPreparationItems() async throws -> [PreparationItem] {
            items.values.flatMap { $0 }
        }

        public func fetchPreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
            items[sessionId] ?? []
        }

        public func fetchIncompletePreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
            (items[sessionId] ?? []).filter { !$0.isCompleted }
        }

        public func save(item: PreparationItem, forSessionId sessionId: UUID) async throws {
            var sessionItems = items[sessionId] ?? []
            if let idx = sessionItems.firstIndex(where: { $0.id == item.id }) {
                sessionItems[idx] = item
            } else {
                sessionItems.append(item)
            }
            items[sessionId] = sessionItems

            // Synchronize with class sessions
            if let sessionIdx = classSessionRepo?.sessions.firstIndex(where: { $0.id == sessionId }) {
                classSessionRepo?.sessions[sessionIdx].preparationItems = sessionItems
            }
        }

        public func deletePreparationItem(by id: UUID) async throws {
            for (key, list) in items {
                items[key] = list.filter { $0.id != id }
            }
        }
    }

    /// Isolated in-memory repository for demo group projects.
    public final class DemoGroupProjectRepository: GroupProjectRepositoryProtocol {
        public var projects: [GroupProject]

        public init(projects: [GroupProject] = []) {
            self.projects = projects
        }

        public func fetchAllProjects() async throws -> [GroupProject] {
            projects
        }

        public func fetchProject(by id: UUID) async throws -> GroupProject? {
            projects.first { $0.id == id }
        }

        public func save(project: GroupProject) async throws {
            if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                projects[idx] = project
            } else {
                projects.append(project)
            }
        }

        public func deleteProject(by id: UUID) async throws {
            projects.removeAll { $0.id == id }
        }
    }

    /// Creates an isolated in-memory `AppDependencyContainer` pre-populated with realistic university data.
    public static func makeDemoContainer() -> AppDependencyContainer {
        let referenceNow = Date()

        // 1. Subjects
        let comp2014Id = UUID()
        let info20003Id = UUID()
        let mast10006Id = UUID()

        let comp2014 = UniversitySubject(
            id: comp2014Id,
            code: "COMP2014",
            name: "Object Oriented Programming",
            colorHex: "#3F51B5"
        )
        let info20003 = UniversitySubject(
            id: info20003Id,
            code: "INFO20003",
            name: "Database Systems",
            colorHex: "#00897B"
        )
        let mast10006 = UniversitySubject(
            id: mast10006Id,
            code: "MAST10006",
            name: "Calculus 2",
            colorHex: "#E65100"
        )

        // 2. Assessments
        // Hero: Assignment 2 (COMP2014, High Priority, 6 tasks, 3 complete = 50% progress)
        let assignment2Id = UUID()
        let task1 = AssessmentTask(
            id: UUID(),
            assessmentId: assignment2Id,
            title: "Understand requirements & specs",
            isCompleted: true,
            orderIndex: 0
        )
        let task2 = AssessmentTask(
            id: UUID(),
            assessmentId: assignment2Id,
            title: "Research polymorphic design",
            isCompleted: true,
            orderIndex: 1
        )
        let task3 = AssessmentTask(
            id: UUID(),
            assessmentId: assignment2Id,
            title: "Create UML class diagram",
            isCompleted: true,
            orderIndex: 2
        )
        let task4 = AssessmentTask(
            id: UUID(),
            assessmentId: assignment2Id,
            title: "Implement models & hierarchy",
            isCompleted: false,
            orderIndex: 3
        )
        let task5 = AssessmentTask(
            id: UUID(),
            assessmentId: assignment2Id,
            title: "Build user interface",
            isCompleted: false,
            orderIndex: 4
        )
        let task6 = AssessmentTask(
            id: UUID(),
            assessmentId: assignment2Id,
            title: "Unit testing & final report",
            isCompleted: false,
            orderIndex: 5
        )
        var assignment2 = Assessment(
            id: assignment2Id,
            subjectId: comp2014Id,
            title: "Assignment 2: Polymorphic System",
            dueDate: referenceNow.addingTimeInterval(86400 * 2), // 2 days away
            weighting: 35.0,
            estimatedWorkloadHours: 18.0,
            progress: 0.50,
            isCompleted: false,
            notes: "Ensure all UML diagram specs match grading rubric.",
            tasks: [task1, task2, task3, task4, task5, task6]
        )
        AssessmentProgressCalculator.synchronize(&assignment2)

        // Secondary: Database Normalisation (INFO20003, 4 tasks, 1 complete = 25% progress)
        let dbProjectId = UUID()
        let task7 = AssessmentTask(
            id: UUID(),
            assessmentId: dbProjectId,
            title: "Design 3NF relational schema",
            isCompleted: true,
            orderIndex: 0
        )
        let task8 = AssessmentTask(
            id: UUID(),
            assessmentId: dbProjectId,
            title: "Write SQL DDL creation script",
            isCompleted: false,
            orderIndex: 1
        )
        let task9 = AssessmentTask(
            id: UUID(),
            assessmentId: dbProjectId,
            title: "Execute workload test queries",
            isCompleted: false,
            orderIndex: 2
        )
        let task10 = AssessmentTask(
            id: UUID(),
            assessmentId: dbProjectId,
            title: "Performance optimization report",
            isCompleted: false,
            orderIndex: 3
        )
        var dbProject = Assessment(
            id: dbProjectId,
            subjectId: info20003Id,
            title: "Database Normalisation Project",
            dueDate: referenceNow.addingTimeInterval(86400 * 5), // 5 days away
            weighting: 25.0,
            estimatedWorkloadHours: 12.0,
            progress: 0.25,
            isCompleted: false,
            notes: "PostgreSQL compatibility required.",
            tasks: [task7, task8, task9, task10]
        )
        AssessmentProgressCalculator.synchronize(&dbProject)

        // Standalone Incomplete: Problem Set 3 (MAST10006, 0 breakdown tasks, 0% progress)
        let problemSet = Assessment(
            id: UUID(),
            subjectId: mast10006Id,
            title: "Calculus Problem Set 3",
            dueDate: referenceNow.addingTimeInterval(86400 * 8), // 8 days away
            weighting: 10.0,
            estimatedWorkloadHours: 6.0,
            progress: 0.0,
            isCompleted: false,
            notes: "Show all mathematical derivation steps.",
            tasks: []
        )

        // Completed Assessment: Week 4 Lab Milestone Quiz (COMP2014, 2 tasks, 2 complete = 100%)
        let quizId = UUID()
        let task11 = AssessmentTask(
            id: UUID(),
            assessmentId: quizId,
            title: "Complete online quiz questions",
            isCompleted: true,
            orderIndex: 0
        )
        let task12 = AssessmentTask(
            id: UUID(),
            assessmentId: quizId,
            title: "Verify submission receipt",
            isCompleted: true,
            orderIndex: 1
        )
        var labQuiz = Assessment(
            id: quizId,
            subjectId: comp2014Id,
            title: "Week 4 Lab Milestone Quiz",
            dueDate: referenceNow.addingTimeInterval(-86400 * 2), // 2 days ago
            weighting: 10.0,
            estimatedWorkloadHours: 2.0,
            progress: 1.0,
            isCompleted: true,
            notes: "Completed in lab session.",
            tasks: [task11, task12]
        )
        AssessmentProgressCalculator.synchronize(&labQuiz)

        // 3. Class Sessions & Preparation Items
        // Session 1: Workshop in 2 hours
        let session1Id = UUID()
        let prepItems1 = [
            PreparationItem(
                id: UUID(),
                classSessionId: session1Id,
                title: "Laptop & charger",
                notes: "Charged to at least 80%",
                isCompleted: true,
                orderIndex: 0
            ),
            PreparationItem(
                id: UUID(),
                classSessionId: session1Id,
                title: "Xcode project cloned",
                notes: "Branch: main",
                isCompleted: true,
                orderIndex: 1
            ),
            PreparationItem(
                id: UUID(),
                classSessionId: session1Id,
                title: "Assignment questions prepared",
                notes: "Review Section 3 requirements",
                isCompleted: false,
                orderIndex: 2
            )
        ]
        let session1 = ClassSession(
            id: session1Id,
            subjectId: comp2014Id,
            classType: .workshop,
            startDate: referenceNow.addingTimeInterval(3600 * 2),
            endDate: referenceNow.addingTimeInterval(3600 * 4),
            campus: "City",
            building: "Building EA",
            room: "Room 15",
            preparationItems: prepItems1
        )

        // Session 2: Lecture Tomorrow 10:00 AM
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceNow) ?? referenceNow
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        tomorrowComponents.hour = 10
        tomorrowComponents.minute = 0
        let tomorrowStart = calendar.date(from: tomorrowComponents) ?? tomorrow
        let tomorrowEnd = tomorrowStart.addingTimeInterval(3600 * 2)

        let session2Id = UUID()
        let prepItems2 = [
            PreparationItem(
                id: UUID(),
                classSessionId: session2Id,
                title: "Download Lecture 8 slides",
                notes: "LMS Week 8 Module",
                isCompleted: true,
                orderIndex: 0
            ),
            PreparationItem(
                id: UUID(),
                classSessionId: session2Id,
                title: "Read database indexing chapter",
                notes: "Pages 145-162",
                isCompleted: false,
                orderIndex: 1
            )
        ]
        let session2 = ClassSession(
            id: session2Id,
            subjectId: info20003Id,
            classType: .lecture,
            startDate: tomorrowStart,
            endDate: tomorrowEnd,
            campus: "Parkville",
            building: "Peter Hall Building",
            room: "Room G01",
            preparationItems: prepItems2
        )

        // Session 3: Tutorial in 2 days 1:00 PM
        let in2Days = calendar.date(byAdding: .day, value: 2, to: referenceNow) ?? referenceNow
        var in2DaysComponents = calendar.dateComponents([.year, .month, .day], from: in2Days)
        in2DaysComponents.hour = 13
        in2DaysComponents.minute = 0
        let in2DaysStart = calendar.date(from: in2DaysComponents) ?? in2Days
        let in2DaysEnd = in2DaysStart.addingTimeInterval(3600)

        let session3Id = UUID()
        let prepItems3 = [
            PreparationItem(
                id: UUID(),
                classSessionId: session3Id,
                title: "Calculus tutorial worksheet printed",
                notes: "Week 7 problem sheet",
                isCompleted: false,
                orderIndex: 0
            )
        ]
        let session3 = ClassSession(
            id: session3Id,
            subjectId: mast10006Id,
            classType: .tutorial,
            startDate: in2DaysStart,
            endDate: in2DaysEnd,
            campus: "Parkville",
            building: "Old Geology Building",
            room: "Room 201",
            preparationItems: prepItems3
        )

        // 4. Group Projects
        let groupProjectId = UUID()
        let member1 = GroupMember(id: UUID(), name: "Vicky", role: "Developer")
        let member2 = GroupMember(id: UUID(), name: "Sarah", role: "Research")
        let member3 = GroupMember(id: UUID(), name: "John", role: "Presentation")

        let groupTask1 = GroupTask(
            id: UUID(),
            title: "Research competitors & user personas",
            dueDate: referenceNow.addingTimeInterval(86400 * 3),
            assignedMemberId: member2.id,
            isCompleted: true,
            orderIndex: 0
        )
        let groupTask2 = GroupTask(
            id: UUID(),
            title: "Build UI Prototype & SwiftUI Screens",
            dueDate: referenceNow.addingTimeInterval(86400 * 7),
            assignedMemberId: member1.id,
            isCompleted: false,
            orderIndex: 1
        )
        let groupTask3 = GroupTask(
            id: UUID(),
            title: "Prepare final presentation slides",
            dueDate: referenceNow.addingTimeInterval(86400 * 12),
            assignedMemberId: member3.id,
            isCompleted: false,
            orderIndex: 2
        )

        let groupProject = GroupProject(
            id: groupProjectId,
            name: "Mobile App Project",
            subjectId: comp2014Id,
            dueDate: referenceNow.addingTimeInterval(86400 * 14),
            myRole: "Lead",
            members: [member1, member2, member3],
            tasks: [groupTask1, groupTask2, groupTask3]
        )

        let subjectRepo = DemoSubjectRepository(subjects: [comp2014, info20003, mast10006])
        let assessmentRepo = DemoAssessmentRepository(assessments: [assignment2, dbProject, problemSet])
        let classSessionRepo = DemoClassSessionRepository(sessions: [session1, session2, session3])
        let prepRepo = DemoPreparationItemRepository(
            items: [
                session1Id: prepItems1,
                session2Id: prepItems2,
                session3Id: prepItems3
            ],
            classSessionRepo: classSessionRepo
        )
        let groupProjectRepo = DemoGroupProjectRepository(projects: [groupProject])

        return AppDependencyContainer(
            subjectRepository: subjectRepo,
            assessmentRepository: assessmentRepo,
            classSessionRepository: classSessionRepo,
            preparationItemRepository: prepRepo,
            groupProjectRepository: groupProjectRepo
        )
    }

    /// Creates an isolated in-memory `DashboardViewModel` pre-populated with realistic university data.
    public static func makeDemoViewModel() -> DashboardViewModel {
        let container = makeDemoContainer()
        return container.makeDashboardViewModel()
    }
}
#endif
