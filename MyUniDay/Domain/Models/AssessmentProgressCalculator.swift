//
//  AssessmentProgressCalculator.swift
//  MyUniDay
//
//  Central, reusable progress calculation implementation for assessments.
//

import Foundation

/// Reusable utility providing standard, deterministic progress calculation
/// derived from breakdown tasks with fallback support for standalone assessments.
public enum AssessmentProgressCalculator {
    /// Result of calculating assessment progress.
    public struct Result: Equatable, Sendable {
        public let progress: Double
        public let isCompleted: Bool

        public init(progress: Double, isCompleted: Bool) {
            self.progress = progress
            self.isCompleted = isCompleted
        }
    }

    /// Computes progress and completion flag for an assessment.
    ///
    /// - If the assessment has breakdown tasks, progress is strictly `completedCount / totalCount`.
    ///   Completion is true if and only if all tasks are complete (or progress >= 0.999).
    /// - If there are zero breakdown tasks, it preserves the existing fallback progress (clamped to 0.0...1.0)
    ///   and completion flag.
    ///
    /// - Parameters:
    ///   - tasks: The breakdown tasks belonging to the assessment.
    ///   - fallbackProgress: Fallback progress value (used when tasks is empty).
    ///   - fallbackIsCompleted: Fallback completion state (used when tasks is empty).
    /// - Returns: Calculated progress (0.0 to 1.0) and completion status.
    public static func calculate(
        tasks: [AssessmentTask],
        fallbackProgress: Double = 0.0,
        fallbackIsCompleted: Bool = false
    ) -> Result {
        guard !tasks.isEmpty else {
            let clamped = min(max(fallbackProgress, 0.0), 1.0)
            let isComp = fallbackIsCompleted || clamped >= 0.999
            return Result(progress: clamped, isCompleted: isComp)
        }

        let completed = tasks.filter { $0.isCompleted }.count
        let total = tasks.count
        let progress = Double(completed) / Double(total)
        let isComp = (completed == total) || progress >= 0.999
        return Result(progress: progress, isCompleted: isComp)
    }

    /// Synchronizes an assessment's progress and isCompleted fields from its tasks.
    public static func synchronize(_ assessment: inout Assessment) {
        let result = calculate(
            tasks: assessment.tasks,
            fallbackProgress: assessment.progress,
            fallbackIsCompleted: assessment.isCompleted
        )
        assessment.progress = result.progress
        assessment.isCompleted = result.isCompleted
    }
}
