//
//  GroupProjectRepositoryProtocol.swift
//  MyUniDay
//
//  Repository interface for Group Project persistence.
//

import Foundation

/// Defines persistence operations for `GroupProject`, `GroupMember`, and `GroupTask`.
public protocol GroupProjectRepositoryProtocol: Sendable {
    /// Retrieves all group projects.
    func fetchAllProjects() async throws -> [GroupProject]

    /// Retrieves a single group project by ID.
    func fetchProject(by id: UUID) async throws -> GroupProject?

    /// Saves or updates a group project, including its members and tasks.
    func save(project: GroupProject) async throws

    /// Deletes a group project by ID.
    func deleteProject(by id: UUID) async throws
}
