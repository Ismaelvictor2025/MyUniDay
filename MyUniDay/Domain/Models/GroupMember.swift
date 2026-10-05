//
//  GroupMember.swift
//  MyUniDay
//
//  Domain model representing a member within a group project.
//

import Foundation

/// Represents a student collaborator in a local group project.
public struct GroupMember: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier of the group member.
    public let id: UUID

    /// Full name of the collaborator (e.g. "Vicky", "Sarah", "John").
    public var name: String

    /// Optional functional role within the team (e.g. "Developer", "Research", "Presentation").
    public var role: String?

    public init(
        id: UUID = UUID(),
        name: String,
        role: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
    }
}
