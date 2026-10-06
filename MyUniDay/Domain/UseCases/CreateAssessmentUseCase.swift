//
//  CreateAssessmentUseCase.swift
//  MyUniDay
//
//  Domain use case validating and persisting newly created assessments.
//

import Foundation

/// Validates and persists an academic assessment associated with a university subject.
public final class CreateAssessmentUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol

    /// Initializes the use case with an assessment repository.
    public init(assessmentRepository: AssessmentRepositoryProtocol) {
        self.assessmentRepository = assessmentRepository
    }

    /// Validates assessment parameters and persists the assessment to storage.
    ///
    /// - Parameters:
    ///   - assessment: The assessment domain model to validate and save.
    ///   - subjectId: The UUID of the parent university subject.
    /// - Throws: `AssessmentCreationError` if validation fails or persistence fails.
    public func execute(assessment: Assessment, forSubjectId subjectId: UUID) async throws {
        let trimmedTitle = assessment.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw AssessmentCreationError.emptyTitle
        }

        guard assessment.weighting >= 0.0 && assessment.weighting <= 100.0 else {
            throw AssessmentCreationError.invalidWeighting
        }

        guard assessment.progress >= 0.0 && assessment.progress <= 1.0 else {
            throw AssessmentCreationError.invalidProgress
        }

        guard assessment.estimatedWorkloadHours >= 0.0 else {
            throw AssessmentCreationError.invalidWorkload
        }

        var validated = assessment
        validated.title = trimmedTitle
        validated.subjectId = subjectId

        // Synchronize progress with tasks if breakdown tasks exist
        AssessmentProgressCalculator.synchronize(&validated)

        do {
            try await assessmentRepository.save(assessment: validated, forSubjectId: subjectId)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        } catch {
            throw AssessmentCreationError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
