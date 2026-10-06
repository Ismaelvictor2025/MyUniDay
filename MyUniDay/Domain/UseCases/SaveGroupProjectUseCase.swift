//
//  SaveGroupProjectUseCase.swift
//  MyUniDay
//
//  Domain Use Case validating and saving group projects with progress synchronization.
//

import Foundation

/// Validates group project metadata and persists the project while synchronizing team progress.
public final class SaveGroupProjectUseCase: Sendable {
    private let groupProjectRepository: GroupProjectRepositoryProtocol

    public init(groupProjectRepository: GroupProjectRepositoryProtocol) {
        self.groupProjectRepository = groupProjectRepository
    }

    /// Validates and saves a group project.
    @discardableResult
    public func execute(project: GroupProject) async throws -> GroupProject {
        let trimmedName = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw GroupProjectError.emptyName
        }

        var validated = project
        validated.name = trimmedName

        do {
            try await groupProjectRepository.save(project: validated)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return validated
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
