//
//  GetStudyNowRecommendationUseCase.swift
//  MyUniDay
//
//  Domain Use Case determining the highest-priority academic focus recommendation
//  using the existing priority calculation and incomplete assessment ranking.
//

import Foundation

/// Recommendation model answering "What should I work on right now?"
public struct StudyRecommendation: Sendable, Equatable {
    public let assessment: Assessment
    public let priority: AssessmentPriority
    public let remainingHours: Double
    public let recommendedActionTitle: String
    public let recommendedActionDetail: String
    public let nextPendingTask: AssessmentTask?

    public init(
        assessment: Assessment,
        priority: AssessmentPriority,
        remainingHours: Double,
        recommendedActionTitle: String,
        recommendedActionDetail: String,
        nextPendingTask: AssessmentTask? = nil
    ) {
        self.assessment = assessment
        self.priority = priority
        self.remainingHours = remainingHours
        self.recommendedActionTitle = recommendedActionTitle
        self.recommendedActionDetail = recommendedActionDetail
        self.nextPendingTask = nextPendingTask
    }
}

/// Use Case delivering deterministic smart prioritisation for the "Study Now" experience.
public final class GetStudyNowRecommendationUseCase: Sendable {
    private let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    private let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase

    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase = CalculateAssessmentPriorityUseCase()
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
    }

    /// Evaluates all upcoming assessments and returns the top recommended focus item.
    ///
    /// - Parameter referenceDate: The current reference timestamp (defaults to current date).
    /// - Returns: The highest-priority `StudyRecommendation`, or `nil` if no incomplete assessments exist.
    public func execute(relativeTo referenceDate: Date = Date()) async throws -> StudyRecommendation? {
        let prioritizedList: [Assessment]
        do {
            prioritizedList = try await getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)
        } catch {
            throw StudyRecommendationError.recommendationUnavailable(reason: error.localizedDescription)
        }

        // Find the first incomplete assessment in the prioritized ordering
        guard let topAssessment = prioritizedList.first(where: { !$0.isCompleted && $0.progress < 0.999 }) else {
            return nil
        }

        let priority = calculatePriorityUseCase.execute(for: topAssessment, relativeTo: referenceDate)

        // Calculate workload remaining
        let progressClamped = min(max(topAssessment.progress, 0.0), 1.0)
        let remainingHours = max(0.5, topAssessment.estimatedWorkloadHours * (1.0 - progressClamped))

        // Check for next pending subtask
        let nextTask = topAssessment.tasks
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { !$0.isCompleted }

        let actionTitle: String
        let actionDetail: String

        if let task = nextTask {
            actionTitle = "Next Milestone: \(task.title)"
            actionDetail = "Tackle this step to advance your progress from \(Int(progressClamped * 100))% towards completion."
        } else if progressClamped > 0.0 {
            actionTitle = "Continue Coursework"
            actionDetail = "You are \(Int(progressClamped * 100))% done. Dedicate focused time to complete the remaining \(String(format: "%.1f", remainingHours)) hours."
        } else {
            actionTitle = "Kickstart Assessment"
            actionDetail = "Begin initial research and outline milestones for this \(Int(topAssessment.weighting))% weighting task."
        }

        return StudyRecommendation(
            assessment: topAssessment,
            priority: priority,
            remainingHours: remainingHours,
            recommendedActionTitle: actionTitle,
            recommendedActionDetail: actionDetail,
            nextPendingTask: nextTask
        )
    }
}
