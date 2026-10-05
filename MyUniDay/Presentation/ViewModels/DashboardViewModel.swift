//
//  DashboardViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel coordinating data for the My Uni Day dashboard.
//

import Foundation
import Observation

/// Coordinates data for the My Uni Day student dashboard view.
///
/// Connects existing Domain Use Cases to future SwiftUI views, presenting:
/// - Priority-ordered incomplete assessments paired with their priority classifications
/// - The student's immediate next upcoming class
/// - Preparation checklist for the upcoming class
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
    /// Initializes the dashboard ViewModel with required domain use cases.
    ///
    /// - Parameters:
    ///   - getPriorityAssessmentsUseCase: Use case for retrieving priority-ordered assessments.
    ///   - getNextClassUseCase: Use case for retrieving the next class session.
    ///   - getClassPreparationUseCase: Use case for retrieving class preparation items.
    ///   - calculatePriorityUseCase: Use case for pairing assessments with their priority (defaults to a new instance).
    ///   - getSubjectsUseCase: Optional use case for retrieving enrolled university subjects.
    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        getNextClassUseCase: GetNextClassUseCase,
        getClassPreparationUseCase: GetClassPreparationUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase = CalculateAssessmentPriorityUseCase(),
        getSubjectsUseCase: GetSubjectsUseCase? = nil
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.getNextClassUseCase = getNextClassUseCase
        self.getClassPreparationUseCase = getClassPreparationUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
        self.getSubjectsUseCase = getSubjectsUseCase

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

    deinit {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private nonisolated(unsafe) var dataObserver: (any NSObjectProtocol)?

    // MARK: - Actions
    /// Loads dashboard data coordinated across the injected use cases.
    ///
    /// - Parameter referenceDate: Reference timestamp used for date-dependent queries (defaults to current date).
    public func loadDashboard(relativeTo referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            async let assessmentsTask = getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)
            async let nextClassTask = getNextClassUseCase.execute(relativeTo: referenceDate)
            async let subjectsTask = getSubjectsUseCase?.execute() ?? []

            let (fetchedAssessments, fetchedNextClass, fetchedSubjects) = try await (assessmentsTask, nextClassTask, subjectsTask)

            var map: [UUID: UniversitySubject] = [:]
            for s in fetchedSubjects { map[s.id] = s }
            self.subjectsById = map

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
    ///
    /// - Parameter referenceDate: Reference timestamp for the refresh operation.
    public func refresh(relativeTo referenceDate: Date = Date()) async {
        await loadDashboard(relativeTo: referenceDate)
    }
}
