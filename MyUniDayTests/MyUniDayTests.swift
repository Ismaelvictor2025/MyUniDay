//
//  MyUniDayTests.swift
//  MyUniDayTests
//
//  Tests validating the domain models, Core Data persistence stack, and repository queries.
//

import Testing
import Foundation
import CoreData
@testable import MyUniDay

@Suite("Domain Models Tests")
struct DomainModelsTests {

    @Test("Subject domain model holds assessments and class sessions conceptually")
    func testSubjectModelHierarchy() {
        let prepItem = PreparationItem(
            title: "Bring Laptop",
            notes: "Ensure Xcode 16 is installed",
            isCompleted: false,
            orderIndex: 0
        )

        let session = ClassSession(
            classType: .workshop,
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "Lab 3.01",
            preparationItems: [prepItem]
        )

        let task = AssessmentTask(
            title: "Write Domain Models",
            isCompleted: true,
            dueDate: Date(),
            orderIndex: 0
        )

        let assessment = Assessment(
            title: "Stage 1 Milestone",
            dueDate: Date().addingTimeInterval(86400 * 3),
            weighting: 15.0,
            estimatedWorkloadHours: 12.0,
            progress: 0.5,
            isCompleted: false,
            notes: "Foundation only",
            tasks: [task]
        )

        let subject = UniversitySubject(
            code: "SWEN30006",
            name: "Software Modelling and Design",
            colorHex: "#1E88E5",
            assessments: [assessment],
            classSessions: [session]
        )

        #expect(subject.code == "SWEN30006")
        #expect(subject.assessments.count == 1)
        #expect(subject.assessments.first?.tasks.count == 1)
        #expect(subject.assessments.first?.weighting == 15.0)
        #expect(subject.classSessions.count == 1)
        #expect(subject.classSessions.first?.classType == .workshop)
        #expect(subject.classSessions.first?.preparationItems.count == 1)
        #expect(subject.classSessions.first?.preparationItems.first?.title == "Bring Laptop")
    }

    @Test("Assessment model contains necessary priority metrics")
    func testAssessmentPriorityMetrics() {
        let assessment = Assessment(
            title: "Final Project",
            dueDate: Date().addingTimeInterval(86400 * 14),
            weighting: 40.0,
            estimatedWorkloadHours: 50.0,
            progress: 0.2,
            isCompleted: false
        )

        #expect(assessment.title == "Final Project")
        #expect(assessment.weighting == 40.0)
        #expect(assessment.estimatedWorkloadHours == 50.0)
        #expect(assessment.progress == 0.2)
        #expect(!assessment.isCompleted)
    }

    @Test("ClassSession model captures location information")
    func testClassSessionLocation() {
        let session = ClassSession(
            classType: .lecture,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            campus: "Parkville",
            building: "Redmond Barry",
            room: "Theatre 1"
        )

        #expect(session.campus == "Parkville")
        #expect(session.building == "Redmond Barry")
        #expect(session.room == "Theatre 1")
        #expect(session.classType == .lecture)
    }
}

@Suite("Core Data Repository & Query Tests")
struct CoreDataRepositoryTests {

    private func makeTestController() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    @Test("Save and fetch subject with CoreDataSubjectRepository")
    func testSubjectPersistence() async throws {
        let controller = makeTestController()
        let repository = CoreDataSubjectRepository(context: controller.container.viewContext)

        let subject = UniversitySubject(
            code: "INFO20003",
            name: "Database Systems",
            colorHex: "#FF5722"
        )

        try await repository.save(subject: subject)

        let fetched = try await repository.fetchSubjects()
        #expect(fetched.count == 1)
        #expect(fetched.first?.code == "INFO20003")
        #expect(fetched.first?.name == "Database Systems")

        let fetchedById = try await repository.fetchSubject(by: subject.id)
        #expect(fetchedById?.id == subject.id)

        try await repository.deleteSubject(by: subject.id)
        let afterDelete = try await repository.fetchSubjects()
        #expect(afterDelete.isEmpty)
    }

    @Test("Save and query incomplete assessments due within time period")
    func testIncompleteAssessmentsQuery() async throws {
        let controller = makeTestController()
        let subjectRepo = CoreDataSubjectRepository(context: controller.container.viewContext)
        let assessmentRepo = CoreDataAssessmentRepository(context: controller.container.viewContext)

        let subject = UniversitySubject(code: "COMP30022", name: "IT Project")
        try await subjectRepo.save(subject: subject)

        let now = Date()
        let dueSoonIncomplete = Assessment(
            title: "Sprint 1 Review",
            dueDate: now.addingTimeInterval(86400 * 2), // 2 days from now
            weighting: 10.0,
            estimatedWorkloadHours: 8.0,
            isCompleted: false
        )

        let dueSoonCompleted = Assessment(
            title: "Sprint 0 Pitch",
            dueDate: now.addingTimeInterval(86400 * 1), // 1 day from now
            weighting: 5.0,
            estimatedWorkloadHours: 4.0,
            isCompleted: true
        )

        let dueFarIncomplete = Assessment(
            title: "Final Submission",
            dueDate: now.addingTimeInterval(86400 * 30), // 30 days from now
            weighting: 35.0,
            estimatedWorkloadHours: 40.0,
            isCompleted: false
        )

        try await assessmentRepo.save(assessment: dueSoonIncomplete, forSubjectId: subject.id)
        try await assessmentRepo.save(assessment: dueSoonCompleted, forSubjectId: subject.id)
        try await assessmentRepo.save(assessment: dueFarIncomplete, forSubjectId: subject.id)

        // Query window: next 7 days
        let windowEnd = now.addingTimeInterval(86400 * 7)
        let dueSoon = try await assessmentRepo.fetchIncompleteAssessments(dueBetween: now, and: windowEnd)

        #expect(dueSoon.count == 1)
        #expect(dueSoon.first?.title == "Sprint 1 Review")
    }

    @Test("Query upcoming class sessions")
    func testUpcomingClassSessionsQuery() async throws {
        let controller = makeTestController()
        let subjectRepo = CoreDataSubjectRepository(context: controller.container.viewContext)
        let sessionRepo = CoreDataClassSessionRepository(context: controller.container.viewContext)

        let subject = UniversitySubject(code: "COMP90015", name: "Distributed Systems")
        try await subjectRepo.save(subject: subject)

        let now = Date()
        let pastSession = ClassSession(
            classType: .lecture,
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            campus: "Parkville",
            building: "Peter Hall",
            room: "G01"
        )

        let futureSession1 = ClassSession(
            classType: .tutorial,
            startDate: now.addingTimeInterval(3600 * 3),
            endDate: now.addingTimeInterval(3600 * 4),
            campus: "Parkville",
            building: "Old Geology",
            room: "201"
        )

        let futureSession2 = ClassSession(
            classType: .lab,
            startDate: now.addingTimeInterval(86400 * 2),
            endDate: now.addingTimeInterval(86400 * 2 + 7200),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "Lab 2.05"
        )

        try await sessionRepo.save(classSession: pastSession, forSubjectId: subject.id)
        try await sessionRepo.save(classSession: futureSession1, forSubjectId: subject.id)
        try await sessionRepo.save(classSession: futureSession2, forSubjectId: subject.id)

        let upcoming = try await sessionRepo.fetchUpcomingClassSessions(from: now)
        #expect(upcoming.count == 2)
        #expect(upcoming.first?.classType == .tutorial)
        #expect(upcoming.last?.classType == .lab)
    }

    @Test("Query incomplete preparation items for a class session")
    func testIncompletePreparationItemsQuery() async throws {
        let controller = makeTestController()
        let subjectRepo = CoreDataSubjectRepository(context: controller.container.viewContext)
        let sessionRepo = CoreDataClassSessionRepository(context: controller.container.viewContext)
        let prepRepo = CoreDataPreparationItemRepository(context: controller.container.viewContext)

        let subject = UniversitySubject(code: "SWEN30006", name: "Software Modelling")
        try await subjectRepo.save(subject: subject)

        let session = ClassSession(
            classType: .lab,
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            campus: "Parkville",
            building: "Doug McDonell",
            room: "Lab 1"
        )
        try await sessionRepo.save(classSession: session, forSubjectId: subject.id)

        let completedItem = PreparationItem(
            title: "Download skeleton code",
            isCompleted: true,
            orderIndex: 0
        )
        let pendingItem = PreparationItem(
            title: "Install PlantUML extension",
            isCompleted: false,
            orderIndex: 1
        )

        try await prepRepo.save(item: completedItem, forSessionId: session.id)
        try await prepRepo.save(item: pendingItem, forSessionId: session.id)

        let allItems = try await prepRepo.fetchPreparationItems(forSessionId: session.id)
        #expect(allItems.count == 2)

        let pendingItems = try await prepRepo.fetchIncompletePreparationItems(forSessionId: session.id)
        #expect(pendingItems.count == 1)
        #expect(pendingItems.first?.title == "Install PlantUML extension")
    }

    @Test("Cascade deletion from subject removes child assessments and sessions")
    func testCascadeDelete() async throws {
        let controller = makeTestController()
        let subjectRepo = CoreDataSubjectRepository(context: controller.container.viewContext)
        let assessmentRepo = CoreDataAssessmentRepository(context: controller.container.viewContext)
        let sessionRepo = CoreDataClassSessionRepository(context: controller.container.viewContext)

        let subject = UniversitySubject(code: "MAST10006", name: "Calculus 2")
        try await subjectRepo.save(subject: subject)

        let assessment = Assessment(
            title: "Assignment 1",
            dueDate: Date().addingTimeInterval(86400 * 5),
            weighting: 10.0,
            estimatedWorkloadHours: 15.0
        )
        try await assessmentRepo.save(assessment: assessment, forSubjectId: subject.id)

        let session = ClassSession(
            classType: .lecture,
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            campus: "Parkville",
            building: "Peter Hall",
            room: "JH"
        )
        try await sessionRepo.save(classSession: session, forSubjectId: subject.id)

        // Delete subject
        try await subjectRepo.deleteSubject(by: subject.id)

        let remainingAssessments = try await assessmentRepo.fetchAssessments(forSubjectId: subject.id)
        #expect(remainingAssessments.isEmpty)

        let remainingSessions = try await sessionRepo.fetchClassSessions(forSubjectId: subject.id)
        #expect(remainingSessions.isEmpty)
    }
}
