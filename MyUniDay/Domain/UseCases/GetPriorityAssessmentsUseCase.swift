//
//  GetPriorityAssessmentsUseCase.swift
//  MyUniDay
//
//  Use case that retrieves and orders incomplete assessments by priority.
//

import Foundation

/// Retrieves assessments via `AssessmentRepositoryProtocol` and returns only incomplete
/// assessments ordered deterministically by priority and urgency.
public final class GetPriorityAssessmentsUseCase: Sendable {
    public let assessmentRepository: AssessmentRepositoryProtocol
    public let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase

    /// Initializes the use case with dependencies.
    ///
    /// - Parameters:
    ///   - assessmentRepository: The persistence repository conforming to `AssessmentRepositoryProtocol`.
    ///   - calculatePriorityUseCase: The priority calculation use case (defaults to a new instance).
    public init(
        assessmentRepository: AssessmentRepositoryProtocol,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase = CalculateAssessmentPriorityUseCase()
    ) {
        self.assessmentRepository = assessmentRepository
        self.calculatePriorityUseCase = calculatePriorityUseCase
    }

    /// Retrieves all incomplete assessments across all subjects, ordered by priority.
    ///
    /// - Parameters:
    ///   - referenceDate: Reference timestamp for priority calculation (defaults to current date).
    ///   - maxDueDate: Optional upper bound for due date (defaults to `.distantFuture`).
    /// - Returns: Incomplete assessments sorted from highest to lowest urgency.
    public func execute(
        relativeTo referenceDate: Date = Date(),
        maxDueDate: Date = .distantFuture
    ) async throws -> [Assessment] {
        var fetched = try await assessmentRepository.fetchIncompleteAssessments(
            dueBetween: .distantPast,
            and: maxDueDate
        )

        // Safety fallback: if query returned nothing, verify against all assessments to guarantee
        // no incomplete coursework is missed due to date filter boundary edge cases.
        if fetched.isEmpty {
            let all = try await assessmentRepository.fetchAllAssessments()
            fetched = all.filter { !$0.isCompleted && $0.progress < 0.999 && $0.dueDate <= maxDueDate }
        }

        return orderIncompleteAssessments(fetched, relativeTo: referenceDate)
    }

    /// Retrieves incomplete assessments for a specific subject, ordered by priority.
    ///
    /// - Parameters:
    ///   - subjectId: The unique identifier of the subject.
    ///   - referenceDate: Reference timestamp for priority calculation (defaults to current date).
    /// - Returns: Incomplete assessments for the given subject, sorted from highest to lowest urgency.
    public func execute(
        forSubjectId subjectId: UUID,
        relativeTo referenceDate: Date = Date()
    ) async throws -> [Assessment] {
        let fetched = try await assessmentRepository.fetchAssessments(forSubjectId: subjectId)
        return orderIncompleteAssessments(fetched, relativeTo: referenceDate)
    }

    /// Orders a given collection of assessments, filtering out completed ones and applying deterministic tie-breakers.
    ///
    /// - Parameters:
    ///   - assessments: The candidate assessments to filter and order.
    ///   - referenceDate: The reference timestamp for priority calculation.
    /// - Returns: Incomplete assessments sorted by priority, due date, weighting, and title.
    public func orderIncompleteAssessments(
        _ assessments: [Assessment],
        relativeTo referenceDate: Date = Date()
    ) -> [Assessment] {
        return assessments
            .filter { !$0.isCompleted && $0.progress < 1.0 }
            .sorted { lhs, rhs in
                let lhsPriority = calculatePriorityUseCase.execute(for: lhs, relativeTo: referenceDate)
                let rhsPriority = calculatePriorityUseCase.execute(for: rhs, relativeTo: referenceDate)

                // 1. Primary ordering: Highest priority first
                if lhsPriority != rhsPriority {
                    return lhsPriority > rhsPriority
                }

                // 2. Tie-breaker 1: Earlier due date
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }

                // 3. Tie-breaker 2: Higher grade weighting
                if lhs.weighting != rhs.weighting {
                    return lhs.weighting > rhs.weighting
                }

                // 4. Tie-breaker 3: Alphabetical by title
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
    }
}
