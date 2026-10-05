//
//  AssessmentsViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for prioritised assessment lists and management.
//

import Foundation
import Observation

/// ViewModel providing assessment screens with prioritised assessment data and creation actions.
///
/// Connects `GetPriorityAssessmentsUseCase`, `CalculateAssessmentPriorityUseCase`,
/// `CreateAssessmentUseCase`, and `ToggleTaskCompletionUseCase` to the presentation layer.
@Observable
@MainActor
public final class AssessmentsViewModel {
    // MARK: - Dependencies
    private let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    private let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase
    private let createAssessmentUseCase: CreateAssessmentUseCase?
    private let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase?
    private let createTaskUseCase: CreateTaskUseCase?
    private let getSubjectsUseCase: GetSubjectsUseCase?
    private let createSubjectUseCase: CreateSubjectUseCase?
    private let updateAssessmentProgressUseCase: UpdateAssessmentProgressUseCase?
    private nonisolated(unsafe) var dataObserver: (any NSObjectProtocol)?

    // MARK: - Presentation State
    /// Ordered assessment items paired with their computed priority classifications.
    public private(set) var items: [PrioritisedAssessmentItem] = []

    /// Enrolled university subjects for association and display.
    public private(set) var subjects: [UniversitySubject] = []

    /// Current priority filter selection (nil indicates 'All').
    public var selectedPriorityFilter: AssessmentPriority? = nil

    /// Filtered items matching the active priority filter.
    public var filteredItems: [PrioritisedAssessmentItem] {
        guard let filter = selectedPriorityFilter else {
            return items
        }
        return items.filter { $0.priority == filter }
    }

    /// Indicates whether assessments are actively being fetched.
    public private(set) var isLoading: Bool = false

    /// User-friendly error message if loading fails.
    public private(set) var errorMessage: String?

    /// Convenient helper indicating whether the list is currently empty after loading.
    public var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    /// Convenience accessor for the underlying domain assessments in priority order.
    public var assessments: [Assessment] {
        items.map { $0.assessment }
    }

    // MARK: - Initialization
    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase = CalculateAssessmentPriorityUseCase(),
        createAssessmentUseCase: CreateAssessmentUseCase? = nil,
        toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase? = nil,
        createTaskUseCase: CreateTaskUseCase? = nil,
        getSubjectsUseCase: GetSubjectsUseCase? = nil,
        createSubjectUseCase: CreateSubjectUseCase? = nil,
        updateAssessmentProgressUseCase: UpdateAssessmentProgressUseCase? = nil
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
        self.createAssessmentUseCase = createAssessmentUseCase
        self.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase
        self.createTaskUseCase = createTaskUseCase
        self.getSubjectsUseCase = getSubjectsUseCase
        self.createSubjectUseCase = createSubjectUseCase
        self.updateAssessmentProgressUseCase = updateAssessmentProgressUseCase

        self.dataObserver = NotificationCenter.default.addObserver(
            forName: .academicDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.loadAssessments()
            }
        }
    }

    deinit {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Actions
    /// Loads assessments in priority order and fetches available subjects.
    public func loadAssessments(
        relativeTo referenceDate: Date = Date(),
        subjectId: UUID? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            async let subjectsTask = getSubjectsUseCase?.execute() ?? []
            async let fetchedTask = (subjectId != nil)
                ? getPriorityAssessmentsUseCase.execute(forSubjectId: subjectId!, relativeTo: referenceDate)
                : getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)

            let (fetchedSubjects, fetched) = try await (subjectsTask, fetchedTask)
            self.subjects = fetchedSubjects

            self.items = fetched.map { assessment in
                let priority = calculatePriorityUseCase.execute(for: assessment, relativeTo: referenceDate)
                return PrioritisedAssessmentItem(assessment: assessment, priority: priority)
            }
        } catch {
            self.errorMessage = "Unable to load assessments. Please try again."
        }

        isLoading = false
    }

    /// Creates and persists a new assessment, refreshing the list on success.
    public func createAssessment(
        title: String,
        subjectId: UUID,
        dueDate: Date,
        weighting: Double,
        estimatedWorkloadHours: Double,
        progress: Double = 0.0,
        notes: String? = nil,
        breakdownSteps: [String] = []
    ) async throws {
        guard let useCase = createAssessmentUseCase else {
            throw RepositoryError.invalidData(reason: "Assessment creation capability not configured.")
        }

        let assessmentId = UUID()
        let tasks = breakdownSteps.enumerated().map { idx, step in
            AssessmentTask(
                id: UUID(),
                assessmentId: assessmentId,
                title: step,
                isCompleted: false,
                orderIndex: idx
            )
        }

        var assessment = Assessment(
            id: assessmentId,
            subjectId: subjectId,
            title: title,
            dueDate: dueDate,
            weighting: weighting,
            estimatedWorkloadHours: estimatedWorkloadHours,
            progress: progress,
            isCompleted: progress >= 1.0,
            notes: notes,
            tasks: tasks
        )

        AssessmentProgressCalculator.synchronize(&assessment)

        try await useCase.execute(assessment: assessment, forSubjectId: subjectId)
        await loadAssessments()
    }

    /// Toggles completion status of a subtask within an assessment.
    public func toggleTask(taskId: UUID, inAssessmentId assessmentId: UUID) async {
        guard let useCase = toggleTaskCompletionUseCase else { return }
        do {
            _ = try await useCase.toggleAssessmentTask(taskId: taskId, inAssessmentId: assessmentId)
            await loadAssessments()
        } catch {
            self.errorMessage = "Failed to update task state."
        }
    }

    /// Appends a new subtask to an assessment.
    public func addTask(title: String, dueDate: Date? = nil, toAssessmentId assessmentId: UUID) async throws {
        guard let useCase = createTaskUseCase else {
            throw RepositoryError.invalidData(reason: "Task creation capability not configured.")
        }
        _ = try await useCase.addAssessmentTask(title: title, dueDate: dueDate, toAssessmentId: assessmentId)
        await loadAssessments()
    }

    /// Deletes a subtask from an assessment.
    public func deleteTask(taskId: UUID, inAssessmentId assessmentId: UUID) async {
        guard let useCase = createTaskUseCase else { return }
        do {
            _ = try await useCase.deleteAssessmentTask(taskId: taskId, fromAssessmentId: assessmentId)
            await loadAssessments()
        } catch {
            self.errorMessage = "Failed to delete task."
        }
    }

    /// Updates a subtask's title, deadline, or completion state.
    public func updateTask(
        taskId: UUID,
        title: String,
        dueDate: Date? = nil,
        isCompleted: Bool? = nil,
        inAssessmentId assessmentId: UUID
    ) async {
        guard let useCase = createTaskUseCase else { return }
        do {
            _ = try await useCase.updateAssessmentTask(
                taskId: taskId,
                title: title,
                dueDate: dueDate,
                isCompleted: isCompleted,
                inAssessmentId: assessmentId
            )
            await loadAssessments()
        } catch {
            self.errorMessage = "Failed to update task."
        }
    }

    /// Manually updates completion progress for an assessment with zero breakdown tasks.
    public func updateAssessmentProgress(progress: Double, forAssessmentId assessmentId: UUID) async {
        guard let useCase = updateAssessmentProgressUseCase else { return }
        do {
            _ = try await useCase.execute(assessmentId: assessmentId, progress: progress)
            await loadAssessments()
        } catch {
            self.errorMessage = "Failed to update assessment progress."
        }
    }

    /// Creates a new subject if needed.
    public func createSubject(code: String, name: String, colorHex: String? = "#3F51B5") async throws -> UniversitySubject {
        guard let useCase = createSubjectUseCase else {
            throw RepositoryError.invalidData(reason: "Subject creation capability not configured.")
        }
        let subject = UniversitySubject(code: code, name: name, colorHex: colorHex)
        try await useCase.execute(subject: subject)
        self.subjects = (try? await getSubjectsUseCase?.execute()) ?? []
        return subject
    }

    /// Retrieves subject code for a given ID.
    public func subjectCode(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return subjects.first { $0.id == id }?.code
    }

    /// Retrieves subject name for a given ID.
    public func subjectName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return subjects.first { $0.id == id }?.name
    }
}
