//
//  GroupProject.swift
//  MyUniDay
//
//  Domain model representing a local group project.
//

import Foundation

/// Represents a collaborative group project with team members and assigned deliverables.
public struct GroupProject: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the group project.
    public let id: UUID

    /// Name of the project (e.g. "Mobile App Project").
    public var name: String

    /// Optional reference to the associated UniversitySubject.
    public var subjectId: UUID?

    /// Final deadline for the group project.
    public var dueDate: Date

    /// The user's role in this group project (e.g. "Lead", "Developer", "Researcher").
    public var myRole: String

    /// Team members collaborating on this project.
    public var members: [GroupMember]

    /// Actionable deliverables and task assignments.
    public var tasks: [GroupTask]

    /// Progress derived automatically from group tasks (0.0 to 1.0).
    public var progress: Double {
        guard !tasks.isEmpty else { return 0.0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }

    /// Number of completed tasks.
    public var completedTasksCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    /// Total number of tasks.
    public var totalTasksCount: Int {
        tasks.count
    }

    public init(
        id: UUID = UUID(),
        name: String,
        subjectId: UUID? = nil,
        dueDate: Date,
        myRole: String = "Member",
        members: [GroupMember] = [],
        tasks: [GroupTask] = []
    ) {
        self.id = id
        self.name = name
        self.subjectId = subjectId
        self.dueDate = dueDate
        self.myRole = myRole
        self.members = members
        self.tasks = tasks
    }
}
