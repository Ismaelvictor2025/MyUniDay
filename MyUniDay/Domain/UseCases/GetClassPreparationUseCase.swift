//
//  GetClassPreparationUseCase.swift
//  MyUniDay
//
//  Use case that retrieves and orders preparation checklist items for a class session.
//

import Foundation

/// Retrieves preparation items for a class session using `PreparationItemRepositoryProtocol`
/// and provides the checklist in a predictable, stable order.
public final class GetClassPreparationUseCase: Sendable {
    private let preparationItemRepository: PreparationItemRepositoryProtocol

    /// Initializes the use case with a preparation item repository.
    ///
    /// - Parameter preparationItemRepository: The persistence repository conforming to `PreparationItemRepositoryProtocol`.
    public init(preparationItemRepository: PreparationItemRepositoryProtocol) {
        self.preparationItemRepository = preparationItemRepository
    }

    /// Retrieves preparation items for a given class session ID in a predictable order.
    ///
    /// Preserves completion status on every item so that downstream UI can render both
    /// prepared (completed) and pending items.
    ///
    /// - Parameter sessionId: The unique identifier of the target class session.
    /// - Returns: An array of `PreparationItem` domain models sorted predictably.
    public func execute(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
        let items = try await preparationItemRepository.fetchPreparationItems(forSessionId: sessionId)

        // Predictable ordering: by orderIndex first, then alphabetical by title
        return items.sorted { lhs, rhs in
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }
            return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }
    }

    /// Retrieves preparation items for a given `ClassSession` model.
    ///
    /// - Parameter session: The target `ClassSession`.
    /// - Returns: An array of `PreparationItem` domain models sorted predictably.
    public func execute(for session: ClassSession) async throws -> [PreparationItem] {
        return try await execute(forSessionId: session.id)
    }
}
