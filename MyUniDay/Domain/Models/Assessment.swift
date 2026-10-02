//
//  Assessment.swift
//  MyUniDay
//
//  Domain model representing an academic assessment or assignment.
//

import Foundation

/// Represents an assessment, project, or exam in a university subject.
///
/// Contains key academic metrics (due date, weighting, workload, progress, completion status)
/// to enable intelligent priority calculation and workload management in later stages.
public struct Assessment: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the assessment.
    public let id: UUID

    /// Optional reference to the parent subject's identifier.
    public var subjectId: UUID?

    /// Descriptive title of the assessment, e.g. "Assignment 1: Architecture Report".
    public var title: String

    /// Submission deadline date and time.
    public var dueDate: Date

    /// Percentage weighting toward the final subject grade (e.g. 25.0 for 25%).
    public var weighting: Double

    /// Estimated total workload in hours required to complete this assessment.
    public var estimatedWorkloadHours: Double

    /// Current completion progress represented from 0.0 (not started) to 1.0 (fully completed).
    public var progress: Double

    /// Explicit completion flag.
    public var isCompleted: Bool

    /// Optional notes, submission guidelines, or criteria.
    public var notes: String?

    /// Granular tasks comprising this assessment.
    public var tasks: [AssessmentTask]

    /// Creates a new `Assessment` domain model instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - subjectId: Optional parent subject ID.
    ///   - title: Title of the assessment.
    ///   - dueDate: Due date and time.
    ///   - weighting: Grade weighting percentage (0-100).
    ///   - estimatedWorkloadHours: Estimated workload in hours.
    ///   - progress: Progress between 0.0 and 1.0 (defaults to 0.0).
    ///   - isCompleted: Whether the assessment is complete (defaults to false).
    ///   - notes: Optional notes or instructions.
    ///   - tasks: Breakdown tasks for this assessment (defaults to empty).
    public init(
        id: UUID = UUID(),
        subjectId: UUID? = nil,
        title: String,
        dueDate: Date,
        weighting: Double,
        estimatedWorkloadHours: Double,
        progress: Double = 0.0,
        isCompleted: Bool = false,
        notes: String? = nil,
        tasks: [AssessmentTask] = []
    ) {
        self.id = id
        self.subjectId = subjectId
        self.title = title
        self.dueDate = dueDate
        self.weighting = weighting
        self.estimatedWorkloadHours = estimatedWorkloadHours
        self.progress = progress
        self.isCompleted = isCompleted
        self.notes = notes
        self.tasks = tasks
    }
}
