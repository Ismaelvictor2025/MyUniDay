//
//  NotificationExtensionTests.swift
//  MyUniDayTests
//
//  Unit tests verifying Notification Content Extension integration, payload serialization,
//  defensive deserialization, category registration, and reminder scheduling logic.
//

import Testing
import Foundation
import UserNotifications
@testable import MyUniDay

// MARK: - Mock Notification Service
private final class MockNotificationSchedulingService: NotificationSchedulingServiceProtocol, @unchecked Sendable {
    var authorizationGranted: Bool = true
    var registeredCategories: [UNNotificationCategory] = []
    var scheduledRequests: [UNNotificationRequest] = []

    func requestAuthorization() async throws -> Bool {
        return authorizationGranted
    }

    func registerCategories() async {
        let category = UNNotificationCategory(
            identifier: AssessmentReminderPayload.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        self.registeredCategories.append(category)
    }

    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        self.scheduledRequests.append(request)
    }
}

@Suite("Notification Content Extension & Reminder Workflow Tests")
@MainActor
struct NotificationExtensionTests {

    // MARK: - 1. Payload Serialization and Deserialization

    @Test("Correct payload generated from assessment properties")
    func testPayloadGeneration() {
        let assessmentId = UUID()
        let dueDate = Date().addingTimeInterval(86400 * 2)

        let payload = AssessmentReminderPayload(
            assessmentId: assessmentId,
            assessmentTitle: "Assignment 2: Polymorphic System",
            subjectCode: "COMP2014",
            subjectName: "Object Oriented Programming",
            priority: "Critical",
            dueDate: dueDate,
            formattedDueDate: "Due in 2 days",
            progress: 0.50,
            remainingTaskCount: 3,
            totalTaskCount: 6
        )

        #expect(payload.assessmentTitle == "Assignment 2: Polymorphic System")
        #expect(payload.subjectCode == "COMP2014")
        #expect(payload.subjectName == "Object Oriented Programming")
        #expect(payload.priority == "Critical")
        #expect(payload.formattedDueDate == "Due in 2 days")
        #expect(payload.progress == 0.50)
        #expect(payload.formattedProgress == "50% complete")
        #expect(payload.remainingTaskCount == 3)
        #expect(payload.totalTaskCount == 6)
        #expect(payload.formattedTasksRemaining == "3 tasks remaining")
    }

    @Test("Payload userInfo roundtrip serialization preserves values")
    func testPayloadUserInfoRoundTrip() {
        let sample = AssessmentReminderPayload.previewSample
        let userInfo = sample.toUserInfo()

        let restored = AssessmentReminderPayload(userInfo: userInfo)

        #expect(restored.assessmentTitle == sample.assessmentTitle)
        #expect(restored.subjectCode == sample.subjectCode)
        #expect(restored.priority == sample.priority)
        #expect(restored.formattedDueDate == sample.formattedDueDate)
        #expect(restored.progress == sample.progress)
        #expect(restored.remainingTaskCount == sample.remainingTaskCount)
        #expect(restored.totalTaskCount == sample.totalTaskCount)
        #expect(restored.formattedProgress == sample.formattedProgress)
        #expect(restored.formattedTasksRemaining == sample.formattedTasksRemaining)
    }

    @Test("Malformed or missing userInfo values are safely defaulted without crashing")
    func testMalformedMissingUserInfoHandling() {
        // Completely empty dictionary
        let emptyPayload = AssessmentReminderPayload(userInfo: [:])
        #expect(emptyPayload.assessmentTitle == "Academic Assessment")
        #expect(emptyPayload.subjectCode == "MYUNIDAY")
        #expect(emptyPayload.priority == "High")
        #expect(emptyPayload.progress == 0.0)
        #expect(emptyPayload.remainingTaskCount == 0)
        #expect(emptyPayload.formattedProgress == "0% complete")
        #expect(emptyPayload.formattedTasksRemaining == "All tasks complete")

        // Corrupted types (strings where numbers are expected, etc.)
        let corrupted: [AnyHashable: Any] = [
            AssessmentReminderPayload.Keys.assessmentTitle: 12345, // invalid type
            AssessmentReminderPayload.Keys.progress: "invalid_progress", // invalid type
            AssessmentReminderPayload.Keys.remainingTaskCount: "three" // invalid type
        ]
        let safePayload = AssessmentReminderPayload(userInfo: corrupted)
        #expect(safePayload.assessmentTitle == "Academic Assessment")
        #expect(safePayload.progress == 0.0)
        #expect(safePayload.remainingTaskCount == 0)
    }

    @Test("Notification category identifier matches MYUNIDAY_ASSESSMENT_REMINDER")
    func testCategoryIdentifierMatches() {
        #expect(AssessmentReminderPayload.categoryIdentifier == "MYUNIDAY_ASSESSMENT_REMINDER")
    }

    // MARK: - 2. Scheduling Logic and Use Case Integration

    @Test("ScheduleAssessmentReminderUseCase selects top priority assessment and builds request")
    func testSchedulingLogicSelectsTopAssessment() async throws {
        let mockService = MockNotificationSchedulingService()
        let demoContainer = DevelopmentDemoData.makeDemoContainer()

        let useCase = ScheduleAssessmentReminderUseCase(
            getPriorityAssessmentsUseCase: demoContainer.getPriorityAssessmentsUseCase,
            calculatePriorityUseCase: demoContainer.calculatePriorityUseCase,
            subjectRepository: demoContainer.subjectRepository,
            notificationService: mockService
        )

        let payload = try await useCase.scheduleReminder(delaySeconds: 5)

        // Verify payload content matches highest priority assessment in demo data
        #expect(payload.assessmentTitle == "Assignment 2: Polymorphic System")
        #expect(payload.subjectCode == "COMP2014")
        #expect(payload.priority.lowercased() == "critical")
        #expect(payload.progress == 0.50)
        #expect(payload.remainingTaskCount == 3)
        #expect(payload.totalTaskCount == 6)

        // Verify request was submitted to notification service
        #expect(mockService.scheduledRequests.count == 1)
        let request = mockService.scheduledRequests[0]
        #expect(request.content.categoryIdentifier == "MYUNIDAY_ASSESSMENT_REMINDER")
        #expect(request.content.title == "ASSESSMENT DUE SOON")
        #expect(request.content.subtitle.contains("COMP2014"))
        #expect(request.content.subtitle.contains("CRITICAL"))
        #expect(request.content.body.contains("Assignment 2"))
    }

    @Test("Scheduling logic rejects completed assessments")
    func testDoesNotScheduleCompletedAssessment() async {
        let mockService = MockNotificationSchedulingService()
        let subject = UniversitySubject(id: UUID(), code: "TEST101", name: "Intro to Testing")
        let completed = Assessment(
            id: UUID(),
            subjectId: subject.id,
            title: "Finished Assignment",
            dueDate: Date().addingTimeInterval(86400),
            weighting: 20.0,
            estimatedWorkloadHours: 5.0,
            progress: 1.0,
            isCompleted: true,
            tasks: []
        )

        let useCase = ScheduleAssessmentReminderUseCase(
            getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase(
                assessmentRepository: DevelopmentDemoData.DemoAssessmentRepository(assessments: [completed])
            ),
            calculatePriorityUseCase: CalculateAssessmentPriorityUseCase(),
            subjectRepository: DevelopmentDemoData.DemoSubjectRepository(subjects: [subject]),
            notificationService: mockService
        )

        // Attempting to schedule with target completed assessment throws error
        await #expect(throws: NotificationReminderError.noIncompleteAssessments) {
            try await useCase.scheduleReminder(for: completed)
        }

        #expect(mockService.scheduledRequests.isEmpty)
    }

    @Test("Permission denied returns student-friendly error message")
    func testPermissionDeniedMessage() async {
        let mockService = MockNotificationSchedulingService()
        mockService.authorizationGranted = false

        let demoContainer = DevelopmentDemoData.makeDemoContainer()
        let useCase = ScheduleAssessmentReminderUseCase(
            getPriorityAssessmentsUseCase: demoContainer.getPriorityAssessmentsUseCase,
            calculatePriorityUseCase: demoContainer.calculatePriorityUseCase,
            subjectRepository: demoContainer.subjectRepository,
            notificationService: mockService
        )

        let result = await useCase.requestAuthorization()
        switch result {
        case .success:
            Issue.record("Expected authorization to fail")
        case .failure(let error):
            #expect(error == .permissionDenied)
            #expect(error.localizedDescription.contains("Notifications are turned off"))
            #expect(error.localizedDescription.contains("Settings"))
        }
    }

    // MARK: - 3. Extension Fallback and Bundle Configuration

    @Test("Fallback payload detection correctly distinguishes placeholder from valid payloads")
    func testFallbackPayloadDetection() {
        let placeholder = AssessmentReminderPayload.placeholder
        #expect(placeholder.isFallback == true)

        let emptyUserInfoPayload = AssessmentReminderPayload(userInfo: [:])
        #expect(emptyUserInfoPayload.isFallback == true)

        let realPayload = AssessmentReminderPayload.previewSample
        #expect(realPayload.isFallback == false)
    }

    @Test("Notification Content Extension bundle contains valid Info.plist with matching category")
    func testNotificationContentExtensionBundleConfig() {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL else { return }
        let appexURL = pluginsURL.appendingPathComponent("MyUniDayNotificationContent.appex")
        guard let bundle = Bundle(url: appexURL) else { return }

        let info = bundle.infoDictionary
        #expect(info != nil)
        let nsExtension = info?["NSExtension"] as? [String: Any]
        #expect(nsExtension != nil)
        let attributes = nsExtension?["NSExtensionAttributes"] as? [String: Any]
        #expect(attributes?["UNNotificationExtensionCategory"] as? String == "MYUNIDAY_ASSESSMENT_REMINDER")
        #expect(attributes?["UNNotificationExtensionDefaultContentHidden"] as? Bool == true)
        #expect(nsExtension?["NSExtensionPointIdentifier"] as? String == "com.apple.usernotifications.content-extension")
    }
}
