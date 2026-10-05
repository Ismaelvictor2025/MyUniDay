//
//  ClassSessionRepositoryProtocol.swift
//  MyUniDay
//
//  Abstract repository interface for ClassSession persistence.
//

import Foundation

/// Defines persistence operations for `ClassSession` domain entities.
///
/// Designed to support upcoming timetable and class preparation workflows.
public protocol ClassSessionRepositoryProtocol: Sendable {
    /// Retrieves all class sessions across all subjects.
    ///
    /// - Returns: An array of `ClassSession` models.
    func fetchAllClassSessions() async throws -> [ClassSession]

    /// Retrieves all class sessions for a specific subject.
    ///
    /// - Parameter subjectId: The UUID of the parent subject.
    /// - Returns: An array of `ClassSession` models.
    func fetchClassSessions(forSubjectId subjectId: UUID) async throws -> [ClassSession]

    /// Retrieves a single class session by its unique identifier.
    ///
    /// - Parameter id: The UUID of the session.
    /// - Returns: The matching `ClassSession` domain model, or nil if not found.
    func fetchClassSession(by id: UUID) async throws -> ClassSession?

    /// Retrieves upcoming class sessions scheduled to start after the given timestamp.
    ///
    /// Useful for answering "Where do I need to be next?" on the student dashboard.
    /// - Parameter fromDate: The starting reference date (e.g. `Date()`).
    /// - Returns: An array of upcoming `ClassSession` models sorted chronologically.
    func fetchUpcomingClassSessions(from fromDate: Date) async throws -> [ClassSession]

    /// Saves or updates a class session for a specific subject.
    ///
    /// - Parameters:
    ///   - classSession: The `ClassSession` domain model to persist.
    ///   - subjectId: The UUID of the parent subject.
    func save(classSession: ClassSession, forSubjectId subjectId: UUID) async throws

    /// Deletes a class session by its unique identifier.
    ///
    /// - Parameter id: The UUID of the class session to delete.
    func deleteClassSession(by id: UUID) async throws
}

public extension ClassSessionRepositoryProtocol {
    func fetchAllClassSessions() async throws -> [ClassSession] {
        try await fetchUpcomingClassSessions(from: .distantPast)
    }
}
