//
//  DashboardViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel coordinating the unified student dashboard.
//

import Foundation
import Observation

/// ViewModel powering the main student dashboard screen.
///
/// Orchestrates data across several domain use cases to deliver:
/// - Incomplete assessments ordered by deterministic priority
/// - The student's immediate next upcoming class
/// - Preparation checklist for the upcoming class
/// - Quick action creation flows
/// - Loading and user-friendly error states
@Observable
@MainActor
public final class DashboardViewModel {
    // MARK: - Use Case Dependencies
    private let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    private let getNextClassUseCase: GetNextClassUseCase
    private let getClassPreparationUseCase: GetClassPreparationUseCase
    private let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase
    private let getSubjectsUseCase: GetSubjectsUseCase?
    private let createAssessmentUseCase: CreateAssessmentUseCase?
    private let createClassSessionUseCase: CreateClassSessionUseCase?
    private let createTaskUseCase: CreateTaskUseCase?
    private let createSubjectUseCase: CreateSubjectUseCase?
    private let getStudentTasksUseCase: GetStudentTasksUseCase?

    // MARK: - Presentation State
    /// Incomplete assessments paired with their calculated priority classifications.
    public private(set) var prioritisedAssessments: [PrioritisedAssessmentItem] = []

    /// Incomplete assessments sorted by priority and urgency.
    public private(set) var priorityAssessments: [Assessment] = []

    /// The student's next upcoming class session, or nil if none scheduled.
    public private(set) var nextClass: ClassSession?

    /// Preparation items required for the next upcoming class session.
    public private(set) var nextClassPreparationItems: [PreparationItem] = []

    /// Subjects keyed by ID for contextual card display.
    public private(set) var subjectsById: [UUID: UniversitySubject] = [:]

    /// Available subjects for quick action creation sheets.
    public private(set) var availableSubjects: [UniversitySubject] = []

    /// Available assessments for quick task creation sheets.
    public private(set) var availableAssessments: [Assessment] = []

    /// Available class sessions for quick prep creation sheets.
    public private(set) var availableSessions: [ClassSession] = []

    /// Subject corresponding to the upcoming class session.
    public var nextClassSubject: UniversitySubject? {
        guard let subjectId = nextClass?.subjectId else { return nil }
        return subjectsById[subjectId]
    }

    /// Indicates whether a load or refresh operation is in progress.
    public private(set) var isLoading: Bool = false

    /// User-facing error message when data loading fails.
    public private(set) var errorMessage: String?

    // MARK: - Initialization
    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        getNextClassUseCase: GetNextClassUseCase,
        getClassPreparationUseCase: GetClassPreparationUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase,
        getSubjectsUseCase: GetSubjectsUseCase? = nil,
        createAssessmentUseCase: CreateAssessmentUseCase? = nil,
        createClassSessionUseCase: CreateClassSessionUseCase? = nil,
        createTaskUseCase: CreateTaskUseCase? = nil,
        createSubjectUseCase: CreateSubjectUseCase? = nil,
        getStudentTasksUseCase: GetStudentTasksUseCase? = nil
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.getNextClassUseCase = getNextClassUseCase
        self.getClassPreparationUseCase = getClassPreparationUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
        self.getSubjectsUseCase = getSubjectsUseCase
        self.createAssessmentUseCase = createAssessmentUseCase
        self.createClassSessionUseCase = createClassSessionUseCase
        self.createTaskUseCase = createTaskUseCase
        self.createSubjectUseCase = createSubjectUseCase
        self.getStudentTasksUseCase = getStudentTasksUseCase

        self.dataObserver = NotificationCenter.default.addObserver(
            forName: .academicDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.loadDashboard()
            }
        }
    }

    /// Convenience initializer maintaining backwards compatibility.
    public convenience init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        getNextClassUseCase: GetNextClassUseCase,
        getClassPreparationUseCase: GetClassPreparationUseCase
    ) {
        self.init(
            getPriorityAssessmentsUseCase: getPriorityAssessmentsUseCase,
            getNextClassUseCase: getNextClassUseCase,
            getClassPreparationUseCase: getClassPreparationUseCase,
            calculatePriorityUseCase: CalculateAssessmentPriorityUseCase()
        )
    }

    deinit {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @ObservationIgnored
    private nonisolated(unsafe) var dataObserver: (any NSObjectProtocol)?

    // MARK: - Quick Action Methods
    /// Creates and persists a new assessment associated with an enrolled subject.
    public func createAssessment(
        title: String,
        subjectId: UUID,
        dueDate: Date,
        weighting: Double,
        estimatedWorkloadHours: Double,
        progress: Double,
        notes: String?,
        breakdownSteps: [String]
    ) async throws {
        guard let useCase = createAssessmentUseCase else { return }
        let assessmentId = UUID()
        let tasks = breakdownSteps.enumerated().map { idx, step in
            AssessmentTask(
                id: UUID(),
                assessmentId: assessmentId,
                title: step,
                isCompleted: false,
                orderIndex: idx
            )
        }
        let assessment = Assessment(
            id: assessmentId,
            subjectId: subjectId,
            title: title,
            dueDate: dueDate,
            weighting: weighting,
            estimatedWorkloadHours: estimatedWorkloadHours,
            progress: progress,
            isCompleted: progress >= 1.0,
            notes: notes,
            tasks: tasks
        )
        try await useCase.execute(assessment: assessment, forSubjectId: subjectId)
        await loadDashboard()
    }

    /// Creates and persists a new class session associated with an enrolled subject.
    public func createClassSession(
        subjectId: UUID,
        classType: ClassType,
        startDate: Date,
        endDate: Date,
        campus: String,
        building: String,
        room: String
    ) async throws {
        guard let useCase = createClassSessionUseCase else { return }
        let session = ClassSession(
            subjectId: subjectId,
            classType: classType,
            startDate: startDate,
            endDate: endDate,
            campus: campus,
            building: building,
            room: room
        )
        try await useCase.execute(classSession: session, forSubjectId: subjectId)
        await loadDashboard()
    }

    /// Adds a milestone task to an assessment.
    public func createAssessmentTask(title: String, dueDate: Date? = nil, assessmentId: UUID) async throws {
        guard let useCase = createTaskUseCase else { return }
        _ = try await useCase.addAssessmentTask(title: title, dueDate: dueDate, toAssessmentId: assessmentId)
        await loadDashboard()
    }

    /// Adds a preparation item to a class session.
    public func createPreparationItem(title: String, notes: String? = nil, sessionId: UUID) async throws {
        guard let useCase = createTaskUseCase else { return }
        _ = try await useCase.addPreparationItem(title: title, notes: notes, toSessionId: sessionId)
        await loadDashboard()
    }

    /// Creates and persists a new enrolled university subject.
    @discardableResult
    public func createSubject(code: String, name: String) async throws -> UniversitySubject {
        let subject = UniversitySubject(code: code, name: name, colorHex: "#3F51B5")
        if let useCase = createSubjectUseCase {
            try await useCase.execute(subject: subject)
            await loadDashboard()
        }
        return subject
    }

    // MARK: - Actions
    /// Loads dashboard data coordinated across the injected use cases.
    public func loadDashboard(relativeTo referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            async let assessmentsTask = getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)
            async let nextClassTask = getNextClassUseCase.execute(relativeTo: referenceDate)
            async let subjectsTask = getSubjectsUseCase?.execute() ?? []
            async let tasksOverviewTask = getStudentTasksUseCase?.execute()

            let (fetchedAssessments, fetchedNextClass, fetchedSubjects, tasksOverview) = try await (assessmentsTask, nextClassTask, subjectsTask, tasksOverviewTask)

            var map: [UUID: UniversitySubject] = [:]
            for s in fetchedSubjects { map[s.id] = s }
            self.subjectsById = map
            self.availableSubjects = fetchedSubjects

            if let overview = tasksOverview {
                self.availableAssessments = overview.assessments
                self.availableSessions = overview.sessions
            }

            self.priorityAssessments = fetchedAssessments
            self.prioritisedAssessments = fetchedAssessments.map { assessment in
                let priority = calculatePriorityUseCase.execute(for: assessment, relativeTo: referenceDate)
                return PrioritisedAssessmentItem(assessment: assessment, priority: priority)
            }
            self.nextClass = fetchedNextClass

            if let classSession = fetchedNextClass {
                self.nextClassPreparationItems = try await getClassPreparationUseCase.execute(for: classSession)
            } else {
                self.nextClassPreparationItems = []
            }
        } catch {
            self.errorMessage = "Unable to load dashboard data. Please try again."
        }

        isLoading = false
    }

    /// Refreshes all dashboard information.
    public func refresh(relativeTo referenceDate: Date = Date()) async {
        await loadDashboard(relativeTo: referenceDate)
    }
}
