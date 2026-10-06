//
//  UpdateAssessmentProgressUseCase.swift
//  MyUniDay
//
//  Domain Use Case allowing students to manually record completion progress for
//  assessments that do not contain child breakdown tasks (Section 5).
//

import Foundation

/// Domain Use Case allowing students to record progress for standalone assessments.
public final class UpdateAssessmentProgressUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol

    public init(assessmentRepository: AssessmentRepositoryProtocol) {
        self.assessmentRepository = assessmentRepository
    }

    /// Updates progress for an assessment with zero breakdown tasks.
    ///
    /// - Parameters:
    ///   - assessmentId: The UUID of the assessment to update.
    ///   - progress: The user-specified progress (0.0 to 1.0).
    /// - Returns: The updated assessment.
    /// - Throws: `AssessmentProgressUpdateError` if assessment is not found, has child tasks, or cannot be saved.
    @discardableResult
    public func execute(assessmentId: UUID, progress: Double) async throws -> Assessment {
        guard var assessment = try await assessmentRepository.fetchAssessment(by: assessmentId) else {
            throw AssessmentProgressUpdateError.assessmentNotFound
        }
        guard let subjectId = assessment.subjectId else {
            throw AssessmentProgressUpdateError.missingParentSubject
        }

        // Section 5 Rule: Manual progress only applies when there are zero breakdown tasks
        guard assessment.tasks.isEmpty else {
            throw AssessmentProgressUpdateError.manualOverrideForbidden(taskCount: assessment.tasks.count)
        }

        guard progress >= 0.0 && progress <= 1.0 else {
            throw AssessmentProgressUpdateError.invalidProgressRange(progress: progress)
        }

        assessment.progress = progress
        assessment.isCompleted = progress >= 0.999

        do {
            try await assessmentRepository.save(assessment: assessment, forSubjectId: subjectId)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return assessment
        } catch {
            throw AssessmentProgressUpdateError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
