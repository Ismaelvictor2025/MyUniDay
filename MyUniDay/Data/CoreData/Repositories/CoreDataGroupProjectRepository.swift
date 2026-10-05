//
//  CoreDataGroupProjectRepository.swift
//  MyUniDay
//
//  Core Data implementation of GroupProjectRepositoryProtocol.
//

import Foundation
import CoreData

/// Core Data backed repository providing persistence for `GroupProject` models.
public final class CoreDataGroupProjectRepository: GroupProjectRepositoryProtocol {
    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    public func fetchAllProjects() async throws -> [GroupProject] {
        try await context.perform {
            let request: NSFetchRequest<GroupProjectEntity> = GroupProjectEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \GroupProjectEntity.dueDate, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchProject(by id: UUID) async throws -> GroupProject? {
        try await context.perform {
            let request: NSFetchRequest<GroupProjectEntity> = GroupProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let results = try self.context.fetch(request)
            return results.first?.toDomain()
        }
    }

    public func save(project: GroupProject) async throws {
        try await context.perform {
            let request: NSFetchRequest<GroupProjectEntity> = GroupProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
            request.fetchLimit = 1

            let projectEntity: GroupProjectEntity
            if let existing = try self.context.fetch(request).first {
                projectEntity = existing
            } else {
                projectEntity = GroupProjectEntity(context: self.context)
            }

            projectEntity.update(from: project)

            // 1. Synchronize Members
            let existingMembers = (projectEntity.members as? Set<GroupMemberEntity>) ?? []
            var existingMembersById = [UUID: GroupMemberEntity]()
            for memberEntity in existingMembers {
                if let memberId = memberEntity.id {
                    existingMembersById[memberId] = memberEntity
                }
            }

            let currentMemberIds = Set(project.members.map { $0.id })

            // Delete removed members
            for (memberId, memberEntity) in existingMembersById where !currentMemberIds.contains(memberId) {
                self.context.delete(memberEntity)
            }

            // Insert or update members
            var memberEntitiesById = [UUID: GroupMemberEntity]()
            for member in project.members {
                let memberEntity = existingMembersById[member.id] ?? GroupMemberEntity(context: self.context)
                memberEntity.update(from: member)
                memberEntity.project = projectEntity
                memberEntitiesById[member.id] = memberEntity
            }

            // 2. Synchronize Tasks
            let existingTasks = (projectEntity.tasks as? Set<GroupTaskEntity>) ?? []
            var existingTasksById = [UUID: GroupTaskEntity]()
            for taskEntity in existingTasks {
                if let taskId = taskEntity.id {
                    existingTasksById[taskId] = taskEntity
                }
            }

            let currentTaskIds = Set(project.tasks.map { $0.id })

            // Delete removed tasks
            for (taskId, taskEntity) in existingTasksById where !currentTaskIds.contains(taskId) {
                self.context.delete(taskEntity)
            }

            // Insert or update tasks
            for task in project.tasks {
                let taskEntity = existingTasksById[task.id] ?? GroupTaskEntity(context: self.context)
                taskEntity.update(from: task)
                taskEntity.project = projectEntity
                if let assignedId = task.assignedMemberId {
                    taskEntity.assignedMember = memberEntitiesById[assignedId]
                } else {
                    taskEntity.assignedMember = nil
                }
            }

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }

    public func deleteProject(by id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<GroupProjectEntity> = GroupProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let results = try self.context.fetch(request)

            for entity in results {
                if let tasks = entity.tasks as? Set<GroupTaskEntity> {
                    for task in tasks {
                        task.assignedMember = nil
                        self.context.delete(task)
                    }
                }
                if let members = entity.members as? Set<GroupMemberEntity> {
                    for member in members {
                        self.context.delete(member)
                    }
                }
                self.context.delete(entity)
            }

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
}
