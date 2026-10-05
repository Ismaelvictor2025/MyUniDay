//
//  ToggleTaskCompletionUseCase.swift
//  MyUniDay
//
//  Domain use case toggling completion status for assessment milestones and class preparation items.
//

import Foundation

/// Handles toggling completion state for actionable university items and synchronizes progress.
public final class ToggleTaskCompletionUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol
    private let preparationItemRepository: PreparationItemRepositoryProtocol

    /// Initializes the use case with assessment and preparation item repositories.
    public init(
        assessmentRepository: AssessmentRepositoryProtocol,
        preparationItemRepository: PreparationItemRepositoryProtocol
    ) {
        self.assessmentRepository = assessmentRepository
        self.preparationItemRepository = preparationItemRepository
    }

    /// Toggles the completion flag of an `AssessmentTask` and recalculates parent assessment progress.
    ///
    /// - Parameters:
    ///   - taskId: The unique identifier of the task.
    ///   - assessmentId: The UUID of the parent assessment.
    /// - Returns: The updated parent `Assessment`.
    @discardableResult
    public func toggleAssessmentTask(taskId: UUID, inAssessmentId assessmentId: UUID) async throws -> Assessment {
        guard var assessment = try await assessmentRepository.fetchAssessment(by: assessmentId) else {
            throw RepositoryError.notFound(id: assessmentId)
        }

        guard let taskIndex = assessment.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw RepositoryError.notFound(id: taskId)
        }

        assessment.tasks[taskIndex].isCompleted.toggle()

        // Synchronize progress using central calculator
        AssessmentProgressCalculator.synchronize(&assessment)

        guard let subjectId = assessment.subjectId else {
            throw RepositoryError.invalidData(reason: "Assessment has no parent subject.")
        }

        try await assessmentRepository.save(assessment: assessment, forSubjectId: subjectId)
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        return assessment
    }

    /// Toggles the completion flag of a `PreparationItem`.
    ///
    /// - Parameters:
    ///   - item: The preparation item to toggle.
    ///   - sessionId: The UUID of the parent class session.
    /// - Returns: The updated `PreparationItem`.
    @discardableResult
    public func togglePreparationItem(item: PreparationItem, inSessionId sessionId: UUID) async throws -> PreparationItem {
        var updated = item
        updated.isCompleted.toggle()
        try await preparationItemRepository.save(item: updated, forSessionId: sessionId)
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        return updated
    }
}
