//
//  AssessmentsViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for prioritised assessment lists.
//

import Foundation
import Observation

/// ViewModel providing future assessment screens with prioritised assessment data.
///
/// Connects `GetPriorityAssessmentsUseCase` and `CalculateAssessmentPriorityUseCase` to the presentation layer,
/// pairing each assessment with its computed priority tier without duplicating domain models.
@Observable
@MainActor
public final class AssessmentsViewModel {
    // MARK: - Dependencies
    private let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    private let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase

    // MARK: - Presentation State
    /// Ordered assessment items paired with their computed priority classifications.
    public private(set) var items: [PrioritisedAssessmentItem] = []

    /// Indicates whether assessments are actively being fetched.
    public private(set) var isLoading: Bool = false

    /// User-friendly error message if loading fails.
    public private(set) var errorMessage: String?

    /// Convenient helper indicating whether the list is currently empty after loading.
    public var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    /// Convenience accessor for the underlying domain assessments in priority order.
    public var assessments: [Assessment] {
        items.map { $0.assessment }
    }

    // MARK: - Initialization
    /// Initializes the assessments ViewModel.
    ///
    /// - Parameters:
    ///   - getPriorityAssessmentsUseCase: Use case that retrieves and orders incomplete assessments.
    ///   - calculatePriorityUseCase: Use case that computes assessment priority (defaults to new instance).
    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase = CalculateAssessmentPriorityUseCase()
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
    }

    // MARK: - Actions
    /// Loads assessments in priority order.
    ///
    /// - Parameters:
    ///   - referenceDate: Reference timestamp used for priority calculations (defaults to current date).
    ///   - subjectId: Optional subject identifier to filter assessments by.
    public func loadAssessments(
        relativeTo referenceDate: Date = Date(),
        subjectId: UUID? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched: [Assessment]
            if let subjectId = subjectId {
                fetched = try await getPriorityAssessmentsUseCase.execute(forSubjectId: subjectId, relativeTo: referenceDate)
            } else {
                fetched = try await getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)
            }

            self.items = fetched.map { assessment in
                let priority = calculatePriorityUseCase.execute(for: assessment, relativeTo: referenceDate)
                return PrioritisedAssessmentItem(assessment: assessment, priority: priority)
            }
        } catch {
            self.errorMessage = "Unable to load assessments. Please try again."
        }

        isLoading = false
    }
}
