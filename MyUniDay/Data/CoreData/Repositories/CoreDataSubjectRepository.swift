//
//  CoreDataSubjectRepository.swift
//  MyUniDay
//
//  Core Data implementation of SubjectRepositoryProtocol.
//

import Foundation
import CoreData

/// Core Data backed repository providing persistence for `UniversitySubject`.
public final class CoreDataSubjectRepository: SubjectRepositoryProtocol {
    private let context: NSManagedObjectContext

    /// Initializes the repository with a managed object context.
    /// - Parameter context: The managed object context to use (defaults to PersistenceController viewContext).
    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    public func fetchSubjects() async throws -> [UniversitySubject] {
        try await context.perform {
            let request: NSFetchRequest<SubjectEntity> = SubjectEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SubjectEntity.code, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchSubject(by id: UUID) async throws -> UniversitySubject? {
        try await context.perform {
            let request: NSFetchRequest<SubjectEntity> = SubjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let results = try self.context.fetch(request)
            return results.first?.toDomain()
        }
    }

    public func save(subject: UniversitySubject) async throws {
        try await context.perform {
            let request: NSFetchRequest<SubjectEntity> = SubjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", subject.id as CVarArg)
            request.fetchLimit = 1

            let entity: SubjectEntity
            if let existing = try self.context.fetch(request).first {
                entity = existing
            } else {
                entity = SubjectEntity(context: self.context)
            }

            entity.update(from: subject)

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }

    public func deleteSubject(by id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<SubjectEntity> = SubjectEntity.fetchRequest()
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
