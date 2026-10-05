//
//  AssessmentRepositoryProtocol.swift
//  MyUniDay
//
//  Abstract repository interface for Assessment persistence.
//

import Foundation

/// Defines persistence operations for `Assessment` and associated `AssessmentTask` domain entities.
///
/// Designed to support upcoming priority calculation and dashboard queries.
public protocol AssessmentRepositoryProtocol: Sendable {
    /// Retrieves all assessments across all subjects.
    ///
    /// - Returns: An array of `Assessment` models.
    func fetchAllAssessments() async throws -> [Assessment]

    /// Retrieves all assessments for a specific subject.
    ///
    /// - Parameter subjectId: The UUID of the parent subject.
    /// - Returns: An array of `Assessment` models.
    func fetchAssessments(forSubjectId subjectId: UUID) async throws -> [Assessment]

    /// Retrieves a single assessment by its unique identifier.
    ///
    /// - Parameter id: The UUID of the assessment.
    /// - Returns: The matching `Assessment` domain model, or nil if not found.
    func fetchAssessment(by id: UUID) async throws -> Assessment?

    /// Retrieves incomplete assessments due within a specified date window.
    ///
    /// Useful for dashboard deadlines and urgency calculations.
    /// - Parameters:
    ///   - startDate: Start of the query window.
    ///   - endDate: End of the query window.
    /// - Returns: An array of incomplete `Assessment` models sorted by due date.
    func fetchIncompleteAssessments(dueBetween startDate: Date, and endDate: Date) async throws -> [Assessment]

    /// Saves or updates an assessment, optionally associating it with a parent subject.
    ///
    /// - Parameters:
    ///   - assessment: The `Assessment` domain model to persist.
    ///   - subjectId: The UUID of the parent subject.
    func save(assessment: Assessment, forSubjectId subjectId: UUID) async throws

    /// Deletes an assessment by its unique identifier.
    ///
    /// - Parameter id: The UUID of the assessment to delete.
    func deleteAssessment(by id: UUID) async throws
}

public extension AssessmentRepositoryProtocol {
    func fetchAllAssessments() async throws -> [Assessment] {
        try await fetchIncompleteAssessments(dueBetween: .distantPast, and: .distantFuture)
    }
}
