//
//  SubjectRepositoryProtocol.swift
//  MyUniDay
//
//  Abstract repository interface for UniversitySubject persistence.
//

import Foundation

/// Defines persistence operations for `UniversitySubject` domain entities.
///
/// Implementations must encapsulate all database-specific logic (e.g. Core Data)
/// so that domain models, view models, and future use cases remain decoupled from persistence frameworks.
public protocol SubjectRepositoryProtocol: Sendable {
    /// Retrieves all enrolled subjects.
    ///
    /// - Returns: An array of `UniversitySubject` domain models.
    func fetchSubjects() async throws -> [UniversitySubject]

    /// Retrieves a specific subject by its unique identifier.
    ///
    /// - Parameter id: The unique UUID of the subject.
    /// - Returns: The matching `UniversitySubject`, or nil if not found.
    func fetchSubject(by id: UUID) async throws -> UniversitySubject?

    /// Saves or updates a subject in persistent storage.
    ///
    /// - Parameter subject: The `UniversitySubject` domain model to persist.
    func save(subject: UniversitySubject) async throws

    /// Deletes a subject and its associated cascaded data by its unique identifier.
    ///
    /// - Parameter id: The unique UUID of the subject to delete.
    func deleteSubject(by id: UUID) async throws
}
