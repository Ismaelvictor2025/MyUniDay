//
//  PreparationItemRepositoryProtocol.swift
//  MyUniDay
//
//  Abstract repository interface for PreparationItem persistence.
//

import Foundation

/// Defines persistence operations for `PreparationItem` domain entities.
///
/// Designed to support upcoming "What do I need to bring?" queries and checklists.
public protocol PreparationItemRepositoryProtocol: Sendable {
    /// Retrieves all preparation items for a given class session.
    ///
    /// - Parameter sessionId: The UUID of the class session.
    /// - Returns: An array of `PreparationItem` models sorted by order index.
    func fetchPreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem]

    /// Retrieves incomplete preparation items for a given class session.
    ///
    /// - Parameter sessionId: The UUID of the class session.
    /// - Returns: An array of incomplete `PreparationItem` models.
    func fetchIncompletePreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem]

    /// Saves or updates a preparation item linked to a class session.
    ///
    /// - Parameters:
    ///   - item: The `PreparationItem` domain model to persist.
    ///   - sessionId: The UUID of the parent class session.
    func save(item: PreparationItem, forSessionId sessionId: UUID) async throws

    /// Deletes a preparation item by its unique identifier.
    ///
    /// - Parameter id: The UUID of the preparation item to delete.
    func deletePreparationItem(by id: UUID) async throws
}
