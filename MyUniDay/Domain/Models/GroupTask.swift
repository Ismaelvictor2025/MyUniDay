//
//  GroupTask.swift
//  MyUniDay
//
//  Domain model representing an actionable deliverable or task in a group project.
//

import Foundation

/// Represents a task or milestone within a group project with assigned team member.
public struct GroupTask: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the group task.
    public let id: UUID

    /// Description of the deliverable (e.g. "Create UI Prototype").
    public var title: String

    /// Optional target completion date.
    public var dueDate: Date?

    /// Identifier of the assigned `GroupMember` (if assigned).
    public var assignedMemberId: UUID?

    /// Whether this group task has been completed.
    public var isCompleted: Bool

    /// Ordering position within the project's task list.
    public var orderIndex: Int

    public init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        assignedMemberId: UUID? = nil,
        isCompleted: Bool = false,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.assignedMemberId = assignedMemberId
        self.isCompleted = isCompleted
        self.orderIndex = orderIndex
    }
}
