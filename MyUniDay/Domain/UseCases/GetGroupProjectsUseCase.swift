//
//  GetGroupProjectsUseCase.swift
//  MyUniDay
//
//  Domain Use Case retrieving and sorting group projects.
//

import Foundation

/// Retrieves all collaborative group projects ordered chronologically by due date.
public final class GetGroupProjectsUseCase: Sendable {
    private let groupProjectRepository: GroupProjectRepositoryProtocol

    public init(groupProjectRepository: GroupProjectRepositoryProtocol) {
        self.groupProjectRepository = groupProjectRepository
    }

    /// Fetches all group projects sorted by due date.
    public func execute() async throws -> [GroupProject] {
        do {
            let projects = try await groupProjectRepository.fetchAllProjects()
            return projects.sorted { $0.dueDate < $1.dueDate }
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches a specific group project by its identifier.
    public func execute(byId id: UUID) async throws -> GroupProject? {
        do {
            return try await groupProjectRepository.fetchProject(by: id)
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
