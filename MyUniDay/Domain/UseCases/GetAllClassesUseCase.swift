//
//  GetAllClassesUseCase.swift
//  MyUniDay
//
//  Domain use case retrieving scheduled class sessions chronologically.
//

import Foundation

/// Retrieves scheduled class sessions ordered chronologically.
public final class GetAllClassesUseCase: Sendable {
    private let classSessionRepository: ClassSessionRepositoryProtocol

    /// Initializes the use case with a class session repository.
    public init(classSessionRepository: ClassSessionRepositoryProtocol) {
        self.classSessionRepository = classSessionRepository
    }

    /// Retrieves scheduled class sessions.
    ///
    /// - Parameter fromDate: The reference date from which to fetch sessions (defaults to current date).
    /// - Returns: An array of `ClassSession` models sorted chronologically by start time.
    public func execute(from fromDate: Date = Date()) async throws -> [ClassSession] {
        try await classSessionRepository.fetchUpcomingClassSessions(from: fromDate)
    }
}
