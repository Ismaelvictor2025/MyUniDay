//
//  DeleteGroupProjectUseCase.swift
//  MyUniDay
//
//  Domain Use Case handling group project deletion.
//

import Foundation

/// Deletes a group project and cleans up its associated deliverables.
public final class DeleteGroupProjectUseCase: Sendable {
    private let groupProjectRepository: GroupProjectRepositoryProtocol

    public init(groupProjectRepository: GroupProjectRepositoryProtocol) {
        self.groupProjectRepository = groupProjectRepository
    }

    /// Deletes the specified group project.
    public func execute(byId id: UUID) async throws {
        do {
            try await groupProjectRepository.deleteProject(by: id)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
