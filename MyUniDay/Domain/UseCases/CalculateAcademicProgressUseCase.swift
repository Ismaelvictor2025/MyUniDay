//
//  CalculateAcademicProgressUseCase.swift
//  MyUniDay
//
//  Domain Use Case calculating university student productivity and completion metrics.
//

import Foundation

/// Summary of productivity and completion progress for an individual subject.
public struct SubjectProgressSummary: Identifiable, Sendable, Equatable {
    public let subjectId: UUID
    public let subjectCode: String
    public let subjectName: String
    public let colorHex: String?
    public let totalAssessments: Int
    public let completedAssessments: Int
    public let progressRate: Double

    public var id: UUID { subjectId }

    public init(
        subjectId: UUID,
        subjectCode: String,
        subjectName: String,
        colorHex: String? = nil,
        totalAssessments: Int,
        completedAssessments: Int,
        progressRate: Double
    ) {
        self.subjectId = subjectId
        self.subjectCode = subjectCode
        self.subjectName = subjectName
        self.colorHex = colorHex
        self.totalAssessments = totalAssessments
        self.completedAssessments = completedAssessments
        self.progressRate = progressRate
    }
}

/// Aggregate productivity and completion metrics across coursework and preparation.
public struct AcademicProgressReport: Sendable, Equatable {
    public let totalAssessments: Int
    public let completedAssessments: Int
    public let assessmentCompletionRate: Double

    public let totalTasks: Int
    public let completedTasks: Int
    public let taskCompletionRate: Double

    public let totalPreparationItems: Int
    public let completedPreparationItems: Int
    public let preparationCompletionRate: Double

    public let overallCompletionRate: Double
    public let subjectSummaries: [SubjectProgressSummary]

    public var remainingAssessments: Int {
        max(0, totalAssessments - completedAssessments)
    }

    public var remainingTasks: Int {
        max(0, totalTasks - completedTasks)
    }

    public var remainingPreparationItems: Int {
        max(0, totalPreparationItems - completedPreparationItems)
    }

    public init(
        totalAssessments: Int,
        completedAssessments: Int,
        assessmentCompletionRate: Double,
        totalTasks: Int,
        completedTasks: Int,
        taskCompletionRate: Double,
        totalPreparationItems: Int,
        completedPreparationItems: Int,
        preparationCompletionRate: Double,
        overallCompletionRate: Double,
        subjectSummaries: [SubjectProgressSummary]
    ) {
        self.totalAssessments = totalAssessments
        self.completedAssessments = completedAssessments
        self.assessmentCompletionRate = assessmentCompletionRate
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.taskCompletionRate = taskCompletionRate
        self.totalPreparationItems = totalPreparationItems
        self.completedPreparationItems = completedPreparationItems
        self.preparationCompletionRate = preparationCompletionRate
        self.overallCompletionRate = overallCompletionRate
        self.subjectSummaries = subjectSummaries
    }

    /// Empty report for initial/zero states without division by zero.
    public static var empty: AcademicProgressReport {
        AcademicProgressReport(
            totalAssessments: 0,
            completedAssessments: 0,
            assessmentCompletionRate: 0.0,
            totalTasks: 0,
            completedTasks: 0,
            taskCompletionRate: 0.0,
            totalPreparationItems: 0,
            completedPreparationItems: 0,
            preparationCompletionRate: 0.0,
            overallCompletionRate: 0.0,
            subjectSummaries: []
        )
    }
}

/// Use case calculating legitimate student completion metrics from stored assessments, tasks, and preparation items.
public final class CalculateAcademicProgressUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol
    private let preparationItemRepository: PreparationItemRepositoryProtocol
    private let subjectRepository: SubjectRepositoryProtocol?

    public init(
        assessmentRepository: AssessmentRepositoryProtocol,
        preparationItemRepository: PreparationItemRepositoryProtocol,
        subjectRepository: SubjectRepositoryProtocol? = nil
    ) {
        self.assessmentRepository = assessmentRepository
        self.preparationItemRepository = preparationItemRepository
        self.subjectRepository = subjectRepository
    }

    /// Calculates the current productivity and completion report.
    ///
    /// DETERMINISTIC OVERALL PROGRESS RULE (Section 10):
    /// Overall completion rate = completed trackable items / total trackable items.
    /// Trackable items comprise:
    /// 1. Assessment breakdown tasks: When an assessment has breakdown tasks, each task is 1 trackable item
    ///    representing that unit of work.
    /// 2. Standalone assessments: When an assessment has zero breakdown tasks, the assessment itself is treated
    ///    as 1 trackable item (completed if isCompleted == true or progress >= 0.999).
    /// 3. Class preparation items: Each class preparation item is 1 trackable item.
    ///
    /// Double-counting is strictly avoided: an assessment and its breakdown tasks are never both counted
    /// as independent items.
    public func execute() async throws -> AcademicProgressReport {
        let assessments = try await assessmentRepository.fetchAllAssessments()
        let prepItems = try await preparationItemRepository.fetchAllPreparationItems()
        let subjects = (try? await subjectRepository?.fetchSubjects()) ?? []

        // 1. Assessment metrics
        let totalAssessments = assessments.count
        let completedAssessments = assessments.filter { $0.isCompleted || $0.progress >= 0.999 }.count
        let assessmentRate = totalAssessments > 0 ? Double(completedAssessments) / Double(totalAssessments) : 0.0

        // 2. Subtasks metrics (across all assessments)
        let allTasks = assessments.flatMap { $0.tasks }
        let totalTasks = allTasks.count
        let completedTasks = allTasks.filter { $0.isCompleted }.count
        let taskRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0

        // 3. Preparation items metrics
        let totalPrep = prepItems.count
        let completedPrep = prepItems.filter { $0.isCompleted }.count
        let prepRate = totalPrep > 0 ? Double(completedPrep) / Double(totalPrep) : 0.0

        // 4. Item-based overall completion rate (Section 10 & 11 - avoid double counting)
        var totalTrackableItems: Double = 0.0
        var completedTrackableItems: Double = 0.0

        for assessment in assessments {
            if assessment.tasks.isEmpty {
                totalTrackableItems += 1.0
                completedTrackableItems += min(max(assessment.progress, 0.0), 1.0)
            } else {
                totalTrackableItems += Double(assessment.tasks.count)
                completedTrackableItems += Double(assessment.tasks.filter { $0.isCompleted }.count)
            }
        }

        totalTrackableItems += Double(prepItems.count)
        completedTrackableItems += Double(prepItems.filter { $0.isCompleted }.count)

        let overallRate = totalTrackableItems > 0 ? (completedTrackableItems / totalTrackableItems) : 0.0

        // 5. Subject breakdowns
        var summaries: [SubjectProgressSummary] = []
        for subject in subjects {
            let subjectAssessments = assessments.filter { $0.subjectId == subject.id }
            let total = subjectAssessments.count
            let completed = subjectAssessments.filter { $0.isCompleted || $0.progress >= 0.999 }.count

            var subjTotalTrackable = 0
            var subjCompletedTrackable = 0
            for a in subjectAssessments {
                if a.tasks.isEmpty {
                    subjTotalTrackable += 1
                    if a.isCompleted || a.progress >= 0.999 { subjCompletedTrackable += 1 }
                } else {
                    subjTotalTrackable += a.tasks.count
                    subjCompletedTrackable += a.tasks.filter { $0.isCompleted }.count
                }
            }
            let rate = subjTotalTrackable > 0 ? Double(subjCompletedTrackable) / Double(subjTotalTrackable) : (total > 0 ? Double(completed) / Double(total) : 0.0)

            summaries.append(
                SubjectProgressSummary(
                    subjectId: subject.id,
                    subjectCode: subject.code,
                    subjectName: subject.name,
                    colorHex: subject.colorHex,
                    totalAssessments: total,
                    completedAssessments: completed,
                    progressRate: rate
                )
            )
        }

        return AcademicProgressReport(
            totalAssessments: totalAssessments,
            completedAssessments: completedAssessments,
            assessmentCompletionRate: assessmentRate,
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            taskCompletionRate: taskRate,
            totalPreparationItems: totalPrep,
            completedPreparationItems: completedPrep,
            preparationCompletionRate: prepRate,
            overallCompletionRate: overallRate,
            subjectSummaries: summaries
        )
    }
}
