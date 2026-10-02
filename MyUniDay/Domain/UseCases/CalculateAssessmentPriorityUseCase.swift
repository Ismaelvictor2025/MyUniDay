//
//  CalculateAssessmentPriorityUseCase.swift
//  MyUniDay
//
//  Use case that computes deterministic assessment priority.
//

import Foundation

/// Determines the urgency and priority level of an assessment using deterministic academic rules.
///
/// The calculation incorporates four core dimensions present in the domain model:
/// 1. **Completion Status**: Completed assessments (`isCompleted == true` or `progress >= 1.0`) are never urgent and return `.low`.
/// 2. **Due Date Imminence** (0–50 points): Higher urgency for assessments that are overdue or due imminently.
/// 3. **Grade Weighting** (5–25 points): Higher impact for heavily weighted assignments (e.g. >= 30%).
/// 4. **Remaining Workload** (5–25 points): Effort required, computed as `estimatedWorkloadHours * (1.0 - progress)`.
///
/// Composite Score Thresholds:
/// - **Critical**: Score >= 75
/// - **High**: Score 50–74
/// - **Medium**: Score 30–49
/// - **Low**: Score < 30
public final class CalculateAssessmentPriorityUseCase: Sendable {

    /// Creates an instance of the use case.
    public init() {}

    /// Calculates the deterministic priority classification for an assessment.
    ///
    /// - Parameters:
    ///   - assessment: The `Assessment` to evaluate.
    ///   - referenceDate: The reference timestamp to compute days remaining from (defaults to current date).
    /// - Returns: The calculated `AssessmentPriority` (.low, .medium, .high, or .critical).
    public func execute(
        for assessment: Assessment,
        relativeTo referenceDate: Date = Date()
    ) -> AssessmentPriority {
        // Rule 1: Completed assessments are never urgent
        if assessment.isCompleted || assessment.progress >= 1.0 {
            return .low
        }

        let score = calculateCompositeScore(for: assessment, relativeTo: referenceDate)

        if score >= 75 {
            return .critical
        } else if score >= 50 {
            return .high
        } else if score >= 30 {
            return .medium
        } else {
            return .low
        }
    }

    /// Computes the underlying composite score (0–100) for tie-breaking and granular urgency ranking.
    ///
    /// - Parameters:
    ///   - assessment: The `Assessment` to evaluate.
    ///   - referenceDate: The reference timestamp.
    /// - Returns: An integer composite score between 0 and 100.
    public func calculateCompositeScore(
        for assessment: Assessment,
        relativeTo referenceDate: Date = Date()
    ) -> Int {
        if assessment.isCompleted || assessment.progress >= 1.0 {
            return 0
        }

        let daysRemaining = assessment.dueDate.timeIntervalSince(referenceDate) / 86400.0

        // 1. Time Imminence Score (up to 50 pts)
        let timeScore: Int
        if daysRemaining <= 0 {
            timeScore = 50 // Overdue
        } else if daysRemaining <= 2 {
            timeScore = 40 // Due in 2 days
        } else if daysRemaining <= 7 {
            timeScore = 25 // Due this week
        } else if daysRemaining <= 14 {
            timeScore = 15 // Due in 2 weeks
        } else {
            timeScore = 5  // Due later
        }

        // 2. Grade Weighting Score (up to 25 pts)
        let weightScore: Int
        if assessment.weighting >= 30.0 {
            weightScore = 25
        } else if assessment.weighting >= 15.0 {
            weightScore = 15
        } else {
            weightScore = 5
        }

        // 3. Remaining Workload Score (up to 25 pts)
        let remainingHours = assessment.estimatedWorkloadHours * max(0.0, 1.0 - assessment.progress)
        let workloadScore: Int
        if remainingHours >= 15.0 {
            workloadScore = 25
        } else if remainingHours >= 8.0 {
            workloadScore = 15
        } else if remainingHours >= 3.0 {
            workloadScore = 10
        } else {
            workloadScore = 5
        }

        return timeScore + weightScore + workloadScore
    }
}
