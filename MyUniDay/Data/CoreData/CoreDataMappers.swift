//
//  CoreDataMappers.swift
//  MyUniDay
//
//  Mapping extensions between Core Data NSManagedObject entities and pure Swift domain models.
//

import Foundation
import CoreData

// MARK: - Subject Mapping

extension SubjectEntity {
    /// Converts a persistent `SubjectEntity` to a domain `UniversitySubject`.
    public func toDomain() -> UniversitySubject {
        let assessmentEntities = (self.assessments as? Set<AssessmentEntity>) ?? []
        let domainAssessments = assessmentEntities
            .map { $0.toDomain() }
            .sorted { $0.dueDate < $1.dueDate }

        let sessionEntities = (self.classSessions as? Set<ClassSessionEntity>) ?? []
        let domainSessions = sessionEntities
            .map { $0.toDomain() }
            .sorted { $0.startDate < $1.startDate }

        return UniversitySubject(
            id: self.id ?? UUID(),
            code: self.code ?? "",
            name: self.name ?? "",
            colorHex: self.colorHex,
            assessments: domainAssessments,
            classSessions: domainSessions
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: UniversitySubject) {
        self.id = domain.id
        self.code = domain.code
        self.name = domain.name
        self.colorHex = domain.colorHex
    }
}

// MARK: - Assessment Mapping

extension AssessmentEntity {
    /// Converts a persistent `AssessmentEntity` to a domain `Assessment`.
    public func toDomain() -> Assessment {
        let taskEntities = (self.tasks as? Set<AssessmentTaskEntity>) ?? []
        let domainTasks = taskEntities
            .map { $0.toDomain() }
            .sorted { $0.orderIndex < $1.orderIndex }

        return Assessment(
            id: self.id ?? UUID(),
            subjectId: self.subject?.id,
            title: self.title ?? "",
            dueDate: self.dueDate ?? Date(),
            weighting: self.weighting,
            estimatedWorkloadHours: self.estimatedWorkloadHours,
            progress: self.progress,
            isCompleted: self.isCompleted,
            notes: self.notes,
            tasks: domainTasks
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: Assessment) {
        self.id = domain.id
        self.title = domain.title
        self.dueDate = domain.dueDate
        self.weighting = domain.weighting
        self.estimatedWorkloadHours = domain.estimatedWorkloadHours
        self.progress = domain.progress
        self.isCompleted = domain.isCompleted
        self.notes = domain.notes
    }
}

// MARK: - Assessment Task Mapping

extension AssessmentTaskEntity {
    /// Converts a persistent `AssessmentTaskEntity` to a domain `AssessmentTask`.
    public func toDomain() -> AssessmentTask {
        return AssessmentTask(
            id: self.id ?? UUID(),
            assessmentId: self.assessment?.id,
            title: self.title ?? "",
            isCompleted: self.isCompleted,
            dueDate: self.dueDate,
            orderIndex: Int(self.orderIndex)
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: AssessmentTask) {
        self.id = domain.id
        self.title = domain.title
        self.isCompleted = domain.isCompleted
        self.dueDate = domain.dueDate
        self.orderIndex = Int16(domain.orderIndex)
    }
}

// MARK: - Class Session Mapping

extension ClassSessionEntity {
    /// Converts a persistent `ClassSessionEntity` to a domain `ClassSession`.
    public func toDomain() -> ClassSession {
        let prepEntities = (self.preparationItems as? Set<PreparationItemEntity>) ?? []
        let domainPrepItems = prepEntities
            .map { $0.toDomain() }
            .sorted { $0.orderIndex < $1.orderIndex }

        let parsedType = ClassType(rawValue: self.classTypeRaw ?? "") ?? .other

        return ClassSession(
            id: self.id ?? UUID(),
            subjectId: self.subject?.id,
            classType: parsedType,
            startDate: self.startDate ?? Date(),
            endDate: self.endDate ?? Date(),
            campus: self.campus ?? "",
            building: self.building ?? "",
            room: self.room ?? "",
            preparationItems: domainPrepItems
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: ClassSession) {
        self.id = domain.id
        self.classTypeRaw = domain.classType.rawValue
        self.startDate = domain.startDate
        self.endDate = domain.endDate
        self.campus = domain.campus
        self.building = domain.building
        self.room = domain.room
    }
}

// MARK: - Preparation Item Mapping

extension PreparationItemEntity {
    /// Converts a persistent `PreparationItemEntity` to a domain `PreparationItem`.
    public func toDomain() -> PreparationItem {
        return PreparationItem(
            id: self.id ?? UUID(),
            classSessionId: self.classSession?.id,
            title: self.title ?? "",
            notes: self.notes,
            isCompleted: self.isCompleted,
            orderIndex: Int(self.orderIndex)
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: PreparationItem) {
        self.id = domain.id
        self.title = domain.title
        self.notes = domain.notes
        self.isCompleted = domain.isCompleted
        self.orderIndex = Int16(domain.orderIndex)
    }
}

// MARK: - Group Project Mapping

extension GroupProjectEntity {
    /// Converts a persistent `GroupProjectEntity` to a domain `GroupProject`.
    public func toDomain() -> GroupProject {
        let memberEntities = (self.members as? Set<GroupMemberEntity>) ?? []
        let domainMembers = memberEntities
            .map { $0.toDomain() }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        let taskEntities = (self.tasks as? Set<GroupTaskEntity>) ?? []
        let domainTasks = taskEntities
            .map { $0.toDomain() }
            .sorted { $0.orderIndex < $1.orderIndex }

        return GroupProject(
            id: self.id ?? UUID(),
            name: self.name ?? "",
            subjectId: self.subjectId,
            dueDate: self.dueDate ?? Date(),
            myRole: self.myRole ?? "Member",
            members: domainMembers,
            tasks: domainTasks
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: GroupProject) {
        self.id = domain.id
        self.name = domain.name
        self.subjectId = domain.subjectId
        self.dueDate = domain.dueDate
        self.myRole = domain.myRole
        self.progress = domain.progress
    }
}

// MARK: - Group Member Mapping

extension GroupMemberEntity {
    /// Converts a persistent `GroupMemberEntity` to a domain `GroupMember`.
    public func toDomain() -> GroupMember {
        return GroupMember(
            id: self.id ?? UUID(),
            name: self.name ?? "",
            role: self.role
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: GroupMember) {
        self.id = domain.id
        self.name = domain.name
        self.role = domain.role
    }
}

// MARK: - Group Task Mapping

extension GroupTaskEntity {
    /// Converts a persistent `GroupTaskEntity` to a domain `GroupTask`.
    public func toDomain() -> GroupTask {
        return GroupTask(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            dueDate: self.dueDate,
            assignedMemberId: self.assignedMember?.id,
            isCompleted: self.isCompleted,
            orderIndex: Int(self.orderIndex)
        )
    }

    /// Updates this managed object from a domain model.
    public func update(from domain: GroupTask) {
        self.id = domain.id
        self.title = domain.title
        self.dueDate = domain.dueDate
        self.isCompleted = domain.isCompleted
        self.orderIndex = Int16(domain.orderIndex)
    }
}
