//
//  GetSubjectsUseCase.swift
//  MyUniDay
//
//  Domain use case retrieving all enrolled university subjects.
//

import Foundation

/// Retrieves all enrolled university subjects ordered by subject code.
public final class GetSubjectsUseCase: Sendable {
    private let subjectRepository: SubjectRepositoryProtocol

    /// Initializes the use case with a subject repository.
    public init(subjectRepository: SubjectRepositoryProtocol) {
        self.subjectRepository = subjectRepository
    }

    /// Retrieves all subjects.
    ///
    /// - Returns: An array of `UniversitySubject` domain models.
    public func execute() async throws -> [UniversitySubject] {
        try await subjectRepository.fetchSubjects()
    }
}
