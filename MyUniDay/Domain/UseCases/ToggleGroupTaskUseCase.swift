//
//  ToggleGroupTaskUseCase.swift
//  MyUniDay
//
//  Domain Use Case toggling group task completion and synchronizing project progress.
//

import Foundation

/// Toggles the completion state of a group task and recalculates project progress.
public final class ToggleGroupTaskUseCase: Sendable {
    private let groupProjectRepository: GroupProjectRepositoryProtocol

    public init(groupProjectRepository: GroupProjectRepositoryProtocol) {
        self.groupProjectRepository = groupProjectRepository
    }

    /// Toggles a group task's completion flag and updates the parent project's progress.
    @discardableResult
    public func execute(taskId: UUID, inProjectId projectId: UUID) async throws -> GroupProject {
        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw GroupProjectError.taskNotFound
        }

        project.tasks[taskIndex].isCompleted.toggle()

        do {
            try await groupProjectRepository.save(project: project)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return project
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
