//
//  CreateSubjectUseCase.swift
//  MyUniDay
//
//  Domain use case validating and saving university subjects.
//

import Foundation

/// Validates and persists enrolled university subjects.
public final class CreateSubjectUseCase: Sendable {
    private let subjectRepository: SubjectRepositoryProtocol

    /// Initializes the use case with a subject repository.
    public init(subjectRepository: SubjectRepositoryProtocol) {
        self.subjectRepository = subjectRepository
    }

    /// Validates subject parameters and saves the subject.
    ///
    /// - Parameter subject: The university subject domain model.
    /// - Throws: `SubjectCreationError` if subject code or name is blank, or persistence fails.
    public func execute(subject: UniversitySubject) async throws {
        let trimmedCode = subject.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            throw SubjectCreationError.emptyCode
        }

        let trimmedName = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SubjectCreationError.emptyName
        }

        var validated = subject
        validated.code = trimmedCode
        validated.name = trimmedName

        do {
            try await subjectRepository.save(subject: validated)
        } catch {
            throw SubjectCreationError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
