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
    /// - Throws: `RepositoryError.invalidData` if subject code or name is blank.
    public func execute(subject: UniversitySubject) async throws {
        let trimmedCode = subject.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            throw RepositoryError.invalidData(reason: "Subject code cannot be empty.")
        }

        let trimmedName = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RepositoryError.invalidData(reason: "Subject name cannot be empty.")
        }

        var validated = subject
        validated.code = trimmedCode
        validated.name = trimmedName

        try await subjectRepository.save(subject: validated)
    }
}
