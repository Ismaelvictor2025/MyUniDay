//
//  CoreDataAssessmentRepository.swift
//  MyUniDay
//
//  Core Data implementation of AssessmentRepositoryProtocol.
//

import Foundation
import CoreData

/// Core Data backed repository providing persistence for `Assessment` models.
public final class CoreDataAssessmentRepository: AssessmentRepositoryProtocol {
    private let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    public func fetchAssessments(forSubjectId subjectId: UUID) async throws -> [Assessment] {
        try await context.perform {
            let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "subject.id == %@", subjectId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \AssessmentEntity.dueDate, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func fetchAssessment(by id: UUID) async throws -> Assessment? {
        try await context.perform {
            let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let results = try self.context.fetch(request)
            return results.first?.toDomain()
        }
    }

    public func fetchIncompleteAssessments(dueBetween startDate: Date, and endDate: Date) async throws -> [Assessment] {
        try await context.perform {
            let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "isCompleted == NO AND dueDate >= %@ AND dueDate <= %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \AssessmentEntity.dueDate, ascending: true)]
            let results = try self.context.fetch(request)
            return results.map { $0.toDomain() }
        }
    }

    public func save(assessment: Assessment, forSubjectId subjectId: UUID) async throws {
        try await context.perform {
            // Find parent subject
            let subjectRequest: NSFetchRequest<SubjectEntity> = SubjectEntity.fetchRequest()
            subjectRequest.predicate = NSPredicate(format: "id == %@", subjectId as CVarArg)
            subjectRequest.fetchLimit = 1
            guard let subjectEntity = try self.context.fetch(subjectRequest).first else {
                throw RepositoryError.notFound(id: subjectId)
            }

            // Find or create assessment
            let assessmentRequest: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
            assessmentRequest.predicate = NSPredicate(format: "id == %@", assessment.id as CVarArg)
            assessmentRequest.fetchLimit = 1

            let assessmentEntity: AssessmentEntity
            if let existing = try self.context.fetch(assessmentRequest).first {
                assessmentEntity = existing
            } else {
                assessmentEntity = AssessmentEntity(context: self.context)
            }

            assessmentEntity.update(from: assessment)
            assessmentEntity.subject = subjectEntity

            // Synchronize tasks
            let existingTasks = (assessmentEntity.tasks as? Set<AssessmentTaskEntity>) ?? []
            var existingTasksById = [UUID: AssessmentTaskEntity]()
            for taskEntity in existingTasks {
                if let taskId = taskEntity.id {
                    existingTasksById[taskId] = taskEntity
                }
            }

            let currentTaskIds = Set(assessment.tasks.map { $0.id })

            // Delete removed tasks
            for (taskId, taskEntity) in existingTasksById where !currentTaskIds.contains(taskId) {
                self.context.delete(taskEntity)
            }

            // Insert or update tasks
            for task in assessment.tasks {
                let taskEntity = existingTasksById[task.id] ?? AssessmentTaskEntity(context: self.context)
                taskEntity.update(from: task)
                taskEntity.assessment = assessmentEntity
            }

            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }

    public func deleteAssessment(by id: UUID) async throws {
        try await context.perform {
            let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
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
