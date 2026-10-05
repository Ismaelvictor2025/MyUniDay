//
//  CoreDataPreparationItemRepository.swift
//  MyUniDay
//
//  Core Data implementation of PreparationItemRepositoryProtocol.
//

import Foundation
import CoreData

/// Core Data backed repository providing persistence for `PreparationItem` models.
public final class CoreDataPreparationItemRepository: PreparationItemRepositoryProtocol {
    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    public func fetchAllPreparationItems() async throws -> [PreparationItem] {
        try await context.perform {
            let request: NSFetchRequest<PreparationItemEntity> = PreparationItemEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PreparationItemEntity.orderIndex, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchPreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
        try await context.perform {
            let request: NSFetchRequest<PreparationItemEntity> = PreparationItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "classSession.id == %@", sessionId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PreparationItemEntity.orderIndex, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchIncompletePreparationItems(forSessionId sessionId: UUID) async throws -> [PreparationItem] {
        try await context.perform {
            let request: NSFetchRequest<PreparationItemEntity> = PreparationItemEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "classSession.id == %@ AND isCompleted == NO",
                sessionId as CVarArg
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \PreparationItemEntity.orderIndex, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func save(item: PreparationItem, forSessionId sessionId: UUID) async throws {
        try await context.perform {
            // Find parent session
            let sessionRequest: NSFetchRequest<ClassSessionEntity> = ClassSessionEntity.fetchRequest()
            sessionRequest.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
            sessionRequest.fetchLimit = 1
            guard let sessionEntity = try self.context.fetch(sessionRequest).first else {
                throw RepositoryError.notFound(id: sessionId)
            }

            // Find or create item
            let itemRequest: NSFetchRequest<PreparationItemEntity> = PreparationItemEntity.fetchRequest()
            itemRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            itemRequest.fetchLimit = 1

            let itemEntity: PreparationItemEntity
            if let existing = try self.context.fetch(itemRequest).first {
                itemEntity = existing
            } else {
                itemEntity = PreparationItemEntity(context: self.context)
            }

            itemEntity.update(from: item)
            itemEntity.classSession = sessionEntity

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }

    public func deletePreparationItem(by id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<PreparationItemEntity> = PreparationItemEntity.fetchRequest()
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
