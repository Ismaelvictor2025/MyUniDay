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
/// - Priority-ordered incomplete assessments
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

    // MARK: - Presentation State
    /// Incomplete assessments sorted by priority and urgency.
    public private(set) var priorityAssessments: [Assessment] = []

    /// The student's next upcoming class session, or nil if none scheduled.
    public private(set) var nextClass: ClassSession?

    /// Preparation items required for the next upcoming class session.
    public private(set) var nextClassPreparationItems: [PreparationItem] = []

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
    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        getNextClassUseCase: GetNextClassUseCase,
        getClassPreparationUseCase: GetClassPreparationUseCase
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.getNextClassUseCase = getNextClassUseCase
        self.getClassPreparationUseCase = getClassPreparationUseCase
    }

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

            let (fetchedAssessments, fetchedNextClass) = try await (assessmentsTask, nextClassTask)

            self.priorityAssessments = fetchedAssessments
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
