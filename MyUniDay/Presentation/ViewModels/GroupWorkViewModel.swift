//
//  GroupWorkViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel managing local collaborative group projects, members, and task assignments.
//

import Foundation
import Observation

/// ViewModel managing group projects, team members, deliverables, and automated progress via Domain Use Cases.
@Observable
@MainActor
public final class GroupWorkViewModel {
    private let getGroupProjectsUseCase: GetGroupProjectsUseCase
    private let saveGroupProjectUseCase: SaveGroupProjectUseCase
    private let deleteGroupProjectUseCase: DeleteGroupProjectUseCase
    private let toggleGroupTaskUseCase: ToggleGroupTaskUseCase
    private let manageGroupDeliverablesUseCase: ManageGroupDeliverablesUseCase
    private let getSubjectsUseCase: GetSubjectsUseCase?

    public private(set) var projects: [GroupProject] = []
    public private(set) var subjectsById: [UUID: UniversitySubject] = [:]
    public private(set) var subjects: [UniversitySubject] = []
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    public init(
        getGroupProjectsUseCase: GetGroupProjectsUseCase,
        saveGroupProjectUseCase: SaveGroupProjectUseCase,
        deleteGroupProjectUseCase: DeleteGroupProjectUseCase,
        toggleGroupTaskUseCase: ToggleGroupTaskUseCase,
        manageGroupDeliverablesUseCase: ManageGroupDeliverablesUseCase,
        getSubjectsUseCase: GetSubjectsUseCase? = nil
    ) {
        self.getGroupProjectsUseCase = getGroupProjectsUseCase
        self.saveGroupProjectUseCase = saveGroupProjectUseCase
        self.deleteGroupProjectUseCase = deleteGroupProjectUseCase
        self.toggleGroupTaskUseCase = toggleGroupTaskUseCase
        self.manageGroupDeliverablesUseCase = manageGroupDeliverablesUseCase
        self.getSubjectsUseCase = getSubjectsUseCase
    }

    /// Loads all persisted group projects and subjects.
    public func loadProjects() async {
        isLoading = true
        errorMessage = nil

        do {
            async let projectsTask = getGroupProjectsUseCase.execute()
            async let subjectsTask = getSubjectsUseCase?.execute() ?? []

            let (fetchedProjects, fetchedSubjects) = try await (projectsTask, subjectsTask)

            var subMap = [UUID: UniversitySubject]()
            for s in fetchedSubjects {
                subMap[s.id] = s
            }
            self.subjectsById = subMap
            self.subjects = fetchedSubjects.sorted { $0.code < $1.code }
            self.projects = fetchedProjects
        } catch {
            self.errorMessage = "Unable to load group projects. Please try again."
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
            throw GroupProjectError.emptyName
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

        _ = try await saveGroupProjectUseCase.execute(project: project)
        await loadProjects()
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
            throw GroupProjectError.emptyName
        }

        guard var project = try await getGroupProjectsUseCase.execute(byId: id) else {
            throw GroupProjectError.projectNotFound
        }

        project.name = trimmed
        project.subjectId = subjectId
        project.dueDate = dueDate
        project.myRole = myRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Member" : myRole

        _ = try await saveGroupProjectUseCase.execute(project: project)
        await loadProjects()
    }

    /// Deletes a group project and cleans up its associated data.
    public func deleteProject(id: UUID) async {
        do {
            try await deleteGroupProjectUseCase.execute(byId: id)
            await loadProjects()
        } catch {
            self.errorMessage = "Failed to delete group project."
        }
    }

    /// Toggles a task completion state and persists the project.
    public func toggleTask(taskId: UUID, inProjectId projectId: UUID) async {
        do {
            _ = try await toggleGroupTaskUseCase.execute(taskId: taskId, inProjectId: projectId)
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
        _ = try await manageGroupDeliverablesUseCase.addTask(
            title: title,
            dueDate: dueDate,
            assignedMemberId: assignedMemberId,
            toProjectId: projectId
        )
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
        _ = try await manageGroupDeliverablesUseCase.updateTask(
            taskId: taskId,
            title: title,
            dueDate: dueDate,
            assignedMemberId: assignedMemberId,
            isCompleted: isCompleted,
            inProjectId: projectId
        )
        await loadProjects()
    }

    /// Deletes a task from a group project.
    public func deleteTask(taskId: UUID, inProjectId projectId: UUID) async throws {
        _ = try await manageGroupDeliverablesUseCase.deleteTask(
            taskId: taskId,
            inProjectId: projectId
        )
        await loadProjects()
    }

    /// Adds a team member to a project.
    public func addMember(
        name: String,
        role: String? = nil,
        toProjectId projectId: UUID
    ) async throws {
        _ = try await manageGroupDeliverablesUseCase.addMember(
            name: name,
            role: role,
            toProjectId: projectId
        )
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
            throw GroupProjectError.emptyName
        }

        guard var project = try await getGroupProjectsUseCase.execute(byId: projectId) else {
            throw GroupProjectError.projectNotFound
        }

        guard let memberIndex = project.members.firstIndex(where: { $0.id == memberId }) else {
            throw GroupProjectError.memberNotFound
        }

        project.members[memberIndex].name = trimmed
        project.members[memberIndex].role = role?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? role : nil

        _ = try await saveGroupProjectUseCase.execute(project: project)
        await loadProjects()
    }

    /// Removes a team member and unassigns their tasks.
    public func deleteMember(memberId: UUID, inProjectId projectId: UUID) async throws {
        _ = try await manageGroupDeliverablesUseCase.deleteMember(
            memberId: memberId,
            fromProjectId: projectId
        )
        await loadProjects()
    }

    /// Convenience to get subject code and name for a project.
    public func subjectDescription(for subjectId: UUID?) -> String? {
        guard let id = subjectId, let s = subjectsById[id] else { return nil }
        return "\(s.code) — \(s.name)"
    }
}
