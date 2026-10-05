//
//  CoreDataClassSessionRepository.swift
//  MyUniDay
//
//  Core Data implementation of ClassSessionRepositoryProtocol.
//

import Foundation
import CoreData

/// Core Data backed repository providing persistence for `ClassSession` models.
public final class CoreDataClassSessionRepository: ClassSessionRepositoryProtocol {
    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    public func fetchAllClassSessions() async throws -> [ClassSession] {
        try await context.perform {
            let request: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClassSessionEntity.startDate, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchClassSessions(forSubjectId subjectId: UUID) async throws -> [ClassSession] {
        try await context.perform {
            let request: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "subject.id == %@", subjectId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClassSessionEntity.startDate, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchClassSession(by id: UUID) async throws -> ClassSession? {
        try await context.perform {
            let request: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let results = try self.context.fetch(request)
            return results.first?.toDomain()
        }
    }

    public func fetchUpcomingClassSessions(from fromDate: Date) async throws -> [ClassSession] {
        try await context.perform {
            let request: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "startDate >= %@", fromDate as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClassSessionEntity.startDate, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func save(classSession: ClassSession, forSubjectId subjectId: UUID) async throws {
        try await context.perform {
            // Find parent subject
            let subjectRequest: NSFetchRequest<SubjectEntity> = SubjectEntity.fetchRequest()
            subjectRequest.predicate = NSPredicate(format: "id == %@", subjectId as CVarArg)
            subjectRequest.fetchLimit = 1
            guard let subjectEntity = try self.context.fetch(subjectRequest).first else {
                throw RepositoryError.notFound(id: subjectId)
            }

            // Find or create session
            let sessionRequest: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            sessionRequest.predicate = NSPredicate(format: "id == %@", classSession.id as CVarArg)
            sessionRequest.fetchLimit = 1

            let sessionEntity: ClassSessionEntity
            if let existing = try self.context.fetch(sessionRequest).first {
                sessionEntity = existing
            } else {
                sessionEntity = ClassSessionEntity(context: self.context)
            }

            sessionEntity.update(from: classSession)
            sessionEntity.subject = subjectEntity

            // Synchronize preparation items
            let existingItems = (sessionEntity.preparationItems as? Set<PreparationItemEntity>) ?? []
            var existingItemsById = [UUID: PreparationItemEntity]()
            for itemEntity in existingItems {
                if let itemId = itemEntity.id {
                    existingItemsById[itemId] = itemEntity
                }
            }

            let currentItemIds = Set(classSession.preparationItems.map { $0.id })

            // Delete removed items
            for (itemId, itemEntity) in existingItemsById where !currentItemIds.contains(itemId) {
                self.context.delete(itemEntity)
            }

            // Insert or update items
            for item in classSession.preparationItems {
                let itemEntity = existingItemsById[item.id] ?? PreparationItemEntity(context: self.context)
                itemEntity.update(from: item)
                itemEntity.classSession = sessionEntity
            }

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }

    public func deleteClassSession(by id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let results = try self.context.fetch(request)

            for entity in results {
                self.context.delete(entity)
            }

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
}
