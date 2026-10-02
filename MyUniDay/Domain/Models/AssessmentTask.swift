//
//  AssessmentTask.swift
//  MyUniDay
//
//  Domain model representing an actionable subtask of an assessment.
//

import Foundation

/// Represents a discrete task or milestone that contributes to an `Assessment`.
public struct AssessmentTask: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the task.
    public let id: UUID

    /// Optional reference to the parent assessment's identifier.
    public var assessmentId: UUID?

    /// Description of the subtask, e.g. "Draft literature review" or "Complete unit tests".
    public var title: String

    /// Whether this task has been completed.
    public var isCompleted: Bool

    /// Optional target completion date for this specific milestone.
    public var dueDate: Date?

    /// Sorting order index within the assessment's task list.
    public var orderIndex: Int

    /// Creates a new `AssessmentTask` domain model instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - assessmentId: Optional parent assessment ID.
    ///   - title: Short description of the subtask.
    ///   - isCompleted: Completion state (defaults to false).
    ///   - dueDate: Optional milestone due date.
    ///   - orderIndex: Position index in the task list (defaults to 0).
    public init(
        id: UUID = UUID(),
        assessmentId: UUID? = nil,
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.assessmentId = assessmentId
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.orderIndex = orderIndex
    }
}
