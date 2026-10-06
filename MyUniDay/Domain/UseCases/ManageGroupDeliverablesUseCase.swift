//
//  ManageGroupDeliverablesUseCase.swift
//  MyUniDay
//
//  Domain Use Case managing team members and task deliverables within group projects.
//

import Foundation

/// Coordinates additions, updates, and removals of group project members and deliverables.
public final class ManageGroupDeliverablesUseCase: Sendable {
    private let groupProjectRepository: GroupProjectRepositoryProtocol

    public init(groupProjectRepository: GroupProjectRepositoryProtocol) {
        self.groupProjectRepository = groupProjectRepository
    }

    /// Appends a new task deliverable to a group project.
    @discardableResult
    public func addTask(
        title: String,
        dueDate: Date? = nil,
        assignedMemberId: UUID? = nil,
        toProjectId projectId: UUID
    ) async throws -> GroupProject {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroupProjectError.emptyName
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        let task = GroupTask(
            id: UUID(),
            title: trimmed,
            dueDate: dueDate,
            assignedMemberId: assignedMemberId,
            isCompleted: false,
            orderIndex: project.tasks.count
        )

        project.tasks.append(task)

        do {
            try await groupProjectRepository.save(project: project)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return project
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    /// Updates an existing task deliverable within a group project.
    @discardableResult
    public func updateTask(
        taskId: UUID,
        title: String,
        dueDate: Date? = nil,
        assignedMemberId: UUID? = nil,
        isCompleted: Bool? = nil,
        inProjectId projectId: UUID
    ) async throws -> GroupProject {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroupProjectError.emptyName
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw GroupProjectError.taskNotFound
        }

        project.tasks[taskIndex].title = trimmed
        if let dueDate = dueDate {
            project.tasks[taskIndex].dueDate = dueDate
        }
        project.tasks[taskIndex].assignedMemberId = assignedMemberId
        if let isCompleted = isCompleted {
            project.tasks[taskIndex].isCompleted = isCompleted
        }

        do {
            try await groupProjectRepository.save(project: project)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return project
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    /// Deletes a task deliverable from a group project and recalculates progress.
    @discardableResult
    public func deleteTask(taskId: UUID, inProjectId projectId: UUID) async throws -> GroupProject {
        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        project.tasks.removeAll { $0.id == taskId }
        for (idx, _) in project.tasks.enumerated() {
            project.tasks[idx].orderIndex = idx
        }

        do {
            try await groupProjectRepository.save(project: project)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return project
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    /// Adds a team member to a group project.
    @discardableResult
    public func addMember(
        name: String,
        role: String? = nil,
        toProjectId projectId: UUID
    ) async throws -> GroupProject {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroupProjectError.emptyName
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        let member = GroupMember(
            id: UUID(),
            name: trimmed,
            role: role?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? role : nil
        )

        project.members.append(member)

        do {
            try await groupProjectRepository.save(project: project)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return project
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    /// Deletes a member from a group project and unassigns any tasks allocated to them.
    @discardableResult
    public func deleteMember(memberId: UUID, fromProjectId projectId: UUID) async throws -> GroupProject {
        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        project.members.removeAll { $0.id == memberId }
        for (idx, task) in project.tasks.enumerated() {
            if task.assignedMemberId == memberId {
                project.tasks[idx].assignedMemberId = nil
            }
        }

        do {
            try await groupProjectRepository.save(project: project)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
            return project
        } catch {
            throw GroupProjectError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
