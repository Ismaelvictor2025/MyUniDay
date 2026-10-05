//
//  GroupWorkViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel managing local collaborative group projects, members, and task assignments.
//

import Foundation
import Observation

/// ViewModel managing group projects, team members, deliverables, and automated progress.
@Observable
@MainActor
public final class GroupWorkViewModel {
    private let groupProjectRepository: GroupProjectRepositoryProtocol
    private let subjectRepository: SubjectRepositoryProtocol?

    public private(set) var projects: [GroupProject] = []
    public private(set) var subjectsById: [UUID: UniversitySubject] = [:]
    public private(set) var subjects: [UniversitySubject] = []
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    public init(
        groupProjectRepository: GroupProjectRepositoryProtocol,
        subjectRepository: SubjectRepositoryProtocol? = nil
    ) {
        self.groupProjectRepository = groupProjectRepository
        self.subjectRepository = subjectRepository
    }

    /// Loads all persisted group projects and subjects.
    public func loadProjects() async {
        isLoading = true
        errorMessage = nil

        do {
            async let projectsTask = groupProjectRepository.fetchAllProjects()
            async let subjectsTask = subjectRepository?.fetchSubjects() ?? []

            let (fetchedProjects, fetchedSubjects) = try await (projectsTask, subjectsTask)

            var subMap = [UUID: UniversitySubject]()
            for s in fetchedSubjects {
                subMap[s.id] = s
            }
            self.subjectsById = subMap
            self.subjects = fetchedSubjects.sorted { $0.code < $1.code }
            self.projects = fetchedProjects
        } catch {
            self.errorMessage = "Unable to load group projects."
        }

        isLoading = false
    }

    /// Creates and persists a new group project with initial members and tasks.
    public func createProject(
        name: String,
        subjectId: UUID? = nil,
        dueDate: Date,
        myRole: String = "Member",
        members: [GroupMember] = [],
        tasks: [GroupTask] = []
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Project name cannot be empty.")
        }

        let project = GroupProject(
            id: UUID(),
            name: trimmed,
            subjectId: subjectId,
            dueDate: dueDate,
            myRole: myRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Member" : myRole,
            members: members,
            tasks: tasks
        )

        try await groupProjectRepository.save(project: project)
        await loadProjects()
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
    }

    /// Updates an existing group project's metadata while preserving its members, tasks, and progress.
    public func updateProject(
        id: UUID,
        name: String,
        subjectId: UUID? = nil,
        dueDate: Date,
        myRole: String = "Member"
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Project name cannot be empty.")
        }

        guard var project = try await groupProjectRepository.fetchProject(by: id) else {
            throw RepositoryError.notFound(id: id)
        }

        project.name = trimmed
        project.subjectId = subjectId
        project.dueDate = dueDate
        project.myRole = myRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Member" : myRole

        try await groupProjectRepository.save(project: project)
        await loadProjects()
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
    }

    /// Deletes a group project and cleans up its associated data.
    public func deleteProject(id: UUID) async {
        do {
            try await groupProjectRepository.deleteProject(by: id)
            await loadProjects()
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        } catch {
            self.errorMessage = "Failed to delete group project."
        }
    }

    /// Toggles a task completion state and persists the project.
    public func toggleTask(taskId: UUID, inProjectId projectId: UUID) async {
        guard var project = projects.first(where: { $0.id == projectId }) else { return }
        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == taskId }) else { return }

        project.tasks[taskIndex].isCompleted.toggle()

        do {
            try await groupProjectRepository.save(project: project)
            await loadProjects()
        } catch {
            self.errorMessage = "Failed to update group task status."
        }
    }

    /// Adds a new task to a group project with optional assigned member.
    public func addTask(
        title: String,
        dueDate: Date? = nil,
        assignedMemberId: UUID? = nil,
        toProjectId projectId: UUID
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Task title cannot be empty.")
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw RepositoryError.notFound(id: projectId)
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
        try await groupProjectRepository.save(project: project)
        await loadProjects()
    }

    /// Updates a task's title, due date, or assigned member.
    public func updateTask(
        taskId: UUID,
        title: String,
        dueDate: Date? = nil,
        assignedMemberId: UUID? = nil,
        isCompleted: Bool? = nil,
        inProjectId projectId: UUID
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Task title cannot be empty.")
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw RepositoryError.notFound(id: projectId)
        }

        guard let taskIndex = project.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw RepositoryError.notFound(id: taskId)
        }

        project.tasks[taskIndex].title = trimmed
        if let dueDate = dueDate {
            project.tasks[taskIndex].dueDate = dueDate
        }
        project.tasks[taskIndex].assignedMemberId = assignedMemberId
        if let isCompleted = isCompleted {
            project.tasks[taskIndex].isCompleted = isCompleted
        }

        try await groupProjectRepository.save(project: project)
        await loadProjects()
    }

    /// Deletes a task from a group project.
    public func deleteTask(taskId: UUID, inProjectId projectId: UUID) async throws {
        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw RepositoryError.notFound(id: projectId)
        }

        project.tasks.removeAll { $0.id == taskId }
        for (idx, _) in project.tasks.enumerated() {
            project.tasks[idx].orderIndex = idx
        }

        try await groupProjectRepository.save(project: project)
        await loadProjects()
    }

    /// Adds a team member to a project.
    public func addMember(
        name: String,
        role: String? = nil,
        toProjectId projectId: UUID
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Member name cannot be empty.")
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw RepositoryError.notFound(id: projectId)
        }

        let member = GroupMember(
            id: UUID(),
            name: trimmed,
            role: role?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? role : nil
        )

        project.members.append(member)
        try await groupProjectRepository.save(project: project)
        await loadProjects()
    }

    /// Updates a team member's name or role.
    public func updateMember(
        memberId: UUID,
        name: String,
        role: String? = nil,
        inProjectId projectId: UUID
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Member name cannot be empty.")
        }

        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw RepositoryError.notFound(id: projectId)
        }

        guard let memberIndex = project.members.firstIndex(where: { $0.id == memberId }) else {
            throw RepositoryError.notFound(id: memberId)
        }

        project.members[memberIndex].name = trimmed
        project.members[memberIndex].role = role?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? role : nil

        try await groupProjectRepository.save(project: project)
        await loadProjects()
    }

    /// Removes a team member and unassigns their tasks.
    public func deleteMember(memberId: UUID, inProjectId projectId: UUID) async throws {
        guard var project = try await groupProjectRepository.fetchProject(by: projectId) else {
            throw RepositoryError.notFound(id: projectId)
        }

        project.members.removeAll { $0.id == memberId }

        // Unassign member from tasks
        for (idx, task) in project.tasks.enumerated() where task.assignedMemberId == memberId {
            project.tasks[idx].assignedMemberId = nil
        }

        try await groupProjectRepository.save(project: project)
        await loadProjects()
    }

    /// Convenience to get subject code and name for a project.
    public func subjectDescription(for subjectId: UUID?) -> String? {
        guard let id = subjectId, let s = subjectsById[id] else { return nil }
        return "\(s.code) — \(s.name)"
    }
}
