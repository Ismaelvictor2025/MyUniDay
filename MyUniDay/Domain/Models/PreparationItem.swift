//
//  PreparationItem.swift
//  MyUniDay
//
//  Domain model representing an actionable item to prepare or bring for a class.
//

import Foundation

/// Represents a requirement or material that a student needs to prepare or bring for a class session.
///
/// Designed to directly answer the product question: "What do I need to bring?".
public struct PreparationItem: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the preparation item.
    public let id: UUID

    /// Optional reference to the parent class session's identifier.
    public var classSessionId: UUID?

    /// Description of what to prepare or bring, e.g. "Charged iPad", "Read Chapter 4", or "Lab Coat".
    public var title: String

    /// Optional extra details or links.
    public var notes: String?

    /// Indicates whether the item has been prepared/packed.
    public var isCompleted: Bool

    /// Sorting order index within the class session preparation checklist.
    public var orderIndex: Int

    /// Creates a new `PreparationItem` domain model instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - classSessionId: Optional parent class session ID.
    ///   - title: Title or description of the preparation item.
    ///   - notes: Optional additional context or details.
    ///   - isCompleted: Completion state (defaults to false).
    ///   - orderIndex: Position index in the checklist (defaults to 0).
    public init(
        id: UUID = UUID(),
        classSessionId: UUID? = nil,
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.classSessionId = classSessionId
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.orderIndex = orderIndex
    }
}
