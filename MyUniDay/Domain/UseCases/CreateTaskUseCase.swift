//
//  CreateTaskUseCase.swift
//  MyUniDay
//
//  Domain use case validating and adding assessment tasks or class preparation items.
//

import Foundation

/// Handles adding new tasks to an assessment or preparation items to a class session.
public final class CreateTaskUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol
    private let preparationItemRepository: PreparationItemRepositoryProtocol

    /// Initializes the use case with dependencies.
    public init(
        assessmentRepository: AssessmentRepositoryProtocol,
        preparationItemRepository: PreparationItemRepositoryProtocol
    ) {
        self.assessmentRepository = assessmentRepository
        self.preparationItemRepository = preparationItemRepository
    }

    /// Appends a new milestone task to an assessment.
    ///
    /// - Parameters:
    ///   - title: Short description of the subtask.
    ///   - dueDate: Optional milestone deadline.
    ///   - assessmentId: The UUID of the parent assessment.
    /// - Returns: The newly created `AssessmentTask`.
    @discardableResult
    public func addAssessmentTask(
        title: String,
        dueDate: Date? = nil,
        toAssessmentId assessmentId: UUID
    ) async throws -> AssessmentTask {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Task title cannot be empty.")
        }

        guard var assessment = try await assessmentRepository.fetchAssessment(by: assessmentId) else {
            throw RepositoryError.notFound(id: assessmentId)
        }

        guard let subjectId = assessment.subjectId else {
            throw RepositoryError.invalidData(reason: "Assessment has no parent subject.")
        }

        let task = AssessmentTask(
            id: UUID(),
            assessmentId: assessmentId,
            title: trimmed,
            isCompleted: false,
            dueDate: dueDate,
            orderIndex: assessment.tasks.count
        )

        assessment.tasks.append(task)

        // Recalculate progress using central calculator
        AssessmentProgressCalculator.synchronize(&assessment)

        try await assessmentRepository.save(assessment: assessment, forSubjectId: subjectId)
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        return task
    }

    /// Updates an existing milestone task within an assessment and synchronizes progress.
    @discardableResult
    public func updateAssessmentTask(
        taskId: UUID,
        title: String,
        dueDate: Date? = nil,
        isCompleted: Bool? = nil,
        inAssessmentId assessmentId: UUID
    ) async throws -> Assessment {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Task title cannot be empty.")
        }

        guard var assessment = try await assessmentRepository.fetchAssessment(by: assessmentId) else {
            throw RepositoryError.notFound(id: assessmentId)
        }

        guard let taskIndex = assessment.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw RepositoryError.notFound(id: taskId)
        }

        guard let subjectId = assessment.subjectId else {
            throw RepositoryError.invalidData(reason: "Assessment has no parent subject.")
        }

        assessment.tasks[taskIndex].title = trimmed
        if let dueDate = dueDate {
            assessment.tasks[taskIndex].dueDate = dueDate
        }
        if let isCompleted = isCompleted {
            assessment.tasks[taskIndex].isCompleted = isCompleted
        }

        AssessmentProgressCalculator.synchronize(&assessment)
        try await assessmentRepository.save(assessment: assessment, forSubjectId: subjectId)
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        return assessment
    }

    /// Deletes a milestone task from an assessment and recalculates progress.
    @discardableResult
    public func deleteAssessmentTask(
        taskId: UUID,
        fromAssessmentId assessmentId: UUID
    ) async throws -> Assessment {
        guard var assessment = try await assessmentRepository.fetchAssessment(by: assessmentId) else {
            throw RepositoryError.notFound(id: assessmentId)
        }

        guard let subjectId = assessment.subjectId else {
            throw RepositoryError.invalidData(reason: "Assessment has no parent subject.")
        }

        assessment.tasks.removeAll { $0.id == taskId }

        // Re-index remaining tasks
        for (idx, _) in assessment.tasks.enumerated() {
            assessment.tasks[idx].orderIndex = idx
        }

        AssessmentProgressCalculator.synchronize(&assessment)
        try await assessmentRepository.save(assessment: assessment, forSubjectId: subjectId)
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        return assessment
    }

    /// Appends a new preparation item to a class session.
    ///
    /// - Parameters:
    ///   - title: Title or description of the preparation item.
    ///   - notes: Optional additional context.
    ///   - sessionId: The UUID of the parent class session.
    /// - Returns: The newly created `PreparationItem`.
    @discardableResult
    public func addPreparationItem(
        title: String,
        notes: String? = nil,
        toSessionId sessionId: UUID
    ) async throws -> PreparationItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidData(reason: "Preparation item title cannot be empty.")
        }

        let existing = try await preparationItemRepository.fetchPreparationItems(forSessionId: sessionId)
        let item = PreparationItem(
            id: UUID(),
            classSessionId: sessionId,
            title: trimmed,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false,
            orderIndex: existing.count
        )

        try await preparationItemRepository.save(item: item, forSessionId: sessionId)
        NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        return item
    }
}
