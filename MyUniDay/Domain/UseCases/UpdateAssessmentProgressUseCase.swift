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
    @discardableResult
    public func execute(assessmentId: UUID, progress: Double) async throws -> Assessment {
        guard var assessment = try await assessmentRepository.fetchAssessment(by: assessmentId) else {
            throw RepositoryError.notFound(id: assessmentId)
        }
        guard let subjectId = assessment.subjectId else {
            throw RepositoryError.invalidData(reason: "Assessment has no parent subject.")
        }

        // Section 5 Rule: Manual progress only applies when there are zero breakdown tasks
        if assessment.tasks.isEmpty {
            let clamped = min(max(progress, 0.0), 1.0)
            assessment.progress = clamped
            assessment.isCompleted = clamped >= 0.999
            try await assessmentRepository.save(assessment: assessment, forSubjectId: subjectId)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        }

        return assessment
    }
}
