//
//  AppDependencyContainer.swift
//  MyUniDay
//
//  Composition root wiring Core Data repositories, Domain Use Cases, and Presentation ViewModels.
//

import Foundation
import CoreData

/// Central composition point constructing the application's dependencies.
///
/// Ensures strict architectural layering:
/// Core Data Repositories → Domain Use Cases → Presentation ViewModels → SwiftUI Views
/// Views never construct or access Core Data repositories or NSManagedObject directly.
@MainActor
public final class AppDependencyContainer {
    /// Shared instance using the standard application persistence controller.
    public static let shared = AppDependencyContainer()

    // MARK: - Repositories
    public let subjectRepository: SubjectRepositoryProtocol
    public let assessmentRepository: AssessmentRepositoryProtocol
    public let classSessionRepository: ClassSessionRepositoryProtocol
    public let preparationItemRepository: PreparationItemRepositoryProtocol
    public let groupProjectRepository: GroupProjectRepositoryProtocol

    // MARK: - Domain Use Cases
    public let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase
    public let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    public let getNextClassUseCase: GetNextClassUseCase
    public let getClassPreparationUseCase: GetClassPreparationUseCase
    public let getAllClassesUseCase: GetAllClassesUseCase
    public let createAssessmentUseCase: CreateAssessmentUseCase
    public let createClassSessionUseCase: CreateClassSessionUseCase
    public let createSubjectUseCase: CreateSubjectUseCase
    public let getSubjectsUseCase: GetSubjectsUseCase
    public let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase
    public let createTaskUseCase: CreateTaskUseCase
    public let calculateAcademicProgressUseCase: CalculateAcademicProgressUseCase
    public let getStudyNowRecommendationUseCase: GetStudyNowRecommendationUseCase
    public let updateAssessmentProgressUseCase: UpdateAssessmentProgressUseCase
    public let updateWidgetSnapshotUseCase: UpdateWidgetSnapshotUseCase
    public let scheduleAssessmentReminderUseCase: ScheduleAssessmentReminderUseCase
    public let getGroupProjectsUseCase: GetGroupProjectsUseCase
    public let saveGroupProjectUseCase: SaveGroupProjectUseCase
    public let deleteGroupProjectUseCase: DeleteGroupProjectUseCase
    public let toggleGroupTaskUseCase: ToggleGroupTaskUseCase
    public let manageGroupDeliverablesUseCase: ManageGroupDeliverablesUseCase
    public let getStudentRemindersUseCase: GetStudentRemindersUseCase
    public let getStudentTasksUseCase: GetStudentTasksUseCase

    private nonisolated(unsafe) var widgetObserver: (any NSObjectProtocol)?

    /// Initializes the composition container with Core Data persistence.
    ///
    /// - Parameter persistenceController: The Core Data persistence controller (defaults to `.shared`).
    public init(persistenceController: PersistenceController = .shared) {
        let viewContext = persistenceController.container.viewContext

        // Repositories
        self.subjectRepository = CoreDataSubjectRepository(context: viewContext)
        self.assessmentRepository = CoreDataAssessmentRepository(context: viewContext)
        self.classSessionRepository = CoreDataClassSessionRepository(context: viewContext)
        self.preparationItemRepository = CoreDataPreparationItemRepository(context: viewContext)
        self.groupProjectRepository = CoreDataGroupProjectRepository(context: viewContext)

        // Use Cases
        let calcPriority = CalculateAssessmentPriorityUseCase()
        self.calculatePriorityUseCase = calcPriority
        let priorityAssessmentsUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: self.assessmentRepository,
            calculatePriorityUseCase: calcPriority
        )
        self.getPriorityAssessmentsUseCase = priorityAssessmentsUseCase
        self.getNextClassUseCase = GetNextClassUseCase(classSessionRepository: self.classSessionRepository)
        self.getClassPreparationUseCase = GetClassPreparationUseCase(preparationItemRepository: self.preparationItemRepository)
        self.getAllClassesUseCase = GetAllClassesUseCase(classSessionRepository: self.classSessionRepository)
        self.createAssessmentUseCase = CreateAssessmentUseCase(assessmentRepository: self.assessmentRepository)
        self.createClassSessionUseCase = CreateClassSessionUseCase(classSessionRepository: self.classSessionRepository)
        self.createSubjectUseCase = CreateSubjectUseCase(subjectRepository: self.subjectRepository)
        let getSubj = GetSubjectsUseCase(subjectRepository: self.subjectRepository)
        self.getSubjectsUseCase = getSubj
        self.toggleTaskCompletionUseCase = ToggleTaskCompletionUseCase(
            assessmentRepository: self.assessmentRepository,
            preparationItemRepository: self.preparationItemRepository
        )
        self.createTaskUseCase = CreateTaskUseCase(
            assessmentRepository: self.assessmentRepository,
            preparationItemRepository: self.preparationItemRepository
        )
        self.calculateAcademicProgressUseCase = CalculateAcademicProgressUseCase(
            assessmentRepository: self.assessmentRepository,
            preparationItemRepository: self.preparationItemRepository,
            subjectRepository: self.subjectRepository
        )
        self.getStudyNowRecommendationUseCase = GetStudyNowRecommendationUseCase(
            getPriorityAssessmentsUseCase: priorityAssessmentsUseCase,
            calculatePriorityUseCase: calcPriority
        )
        self.updateAssessmentProgressUseCase = UpdateAssessmentProgressUseCase(
            assessmentRepository: self.assessmentRepository
        )
        self.updateWidgetSnapshotUseCase = UpdateWidgetSnapshotUseCase(
            getPriorityAssessmentsUseCase: priorityAssessmentsUseCase,
            calculatePriorityUseCase: calcPriority,
            getNextClassUseCase: self.getNextClassUseCase,
            subjectRepository: self.subjectRepository
        )
        self.scheduleAssessmentReminderUseCase = ScheduleAssessmentReminderUseCase(
            getPriorityAssessmentsUseCase: priorityAssessmentsUseCase,
            calculatePriorityUseCase: calcPriority,
            subjectRepository: self.subjectRepository
        )
        self.getGroupProjectsUseCase = GetGroupProjectsUseCase(groupProjectRepository: self.groupProjectRepository)
        self.saveGroupProjectUseCase = SaveGroupProjectUseCase(groupProjectRepository: self.groupProjectRepository)
        self.deleteGroupProjectUseCase = DeleteGroupProjectUseCase(groupProjectRepository: self.groupProjectRepository)
        self.toggleGroupTaskUseCase = ToggleGroupTaskUseCase(groupProjectRepository: self.groupProjectRepository)
        self.manageGroupDeliverablesUseCase = ManageGroupDeliverablesUseCase(groupProjectRepository: self.groupProjectRepository)
        self.getStudentRemindersUseCase = GetStudentRemindersUseCase(
            assessmentRepository: self.assessmentRepository,
            classSessionRepository: self.classSessionRepository,
            preparationItemRepository: self.preparationItemRepository,
            subjectRepository: self.subjectRepository
        )
        self.getStudentTasksUseCase = GetStudentTasksUseCase(
            assessmentRepository: self.assessmentRepository,
            classSessionRepository: self.classSessionRepository,
            subjectRepository: self.subjectRepository
        )

        setupWidgetSyncObserver()
        performInitialWidgetSync()
        Task { [scheduleAssessmentReminderUseCase] in
            await scheduleAssessmentReminderUseCase.registerCategory()
        }
    }

    /// Initializes the composition container with custom/mock repositories (useful for testing and demo mode).
    public init(
        subjectRepository: SubjectRepositoryProtocol,
        assessmentRepository: AssessmentRepositoryProtocol,
        classSessionRepository: ClassSessionRepositoryProtocol,
        preparationItemRepository: PreparationItemRepositoryProtocol,
        groupProjectRepository: GroupProjectRepositoryProtocol? = nil
    ) {
        self.subjectRepository = subjectRepository
        self.assessmentRepository = assessmentRepository
        self.classSessionRepository = classSessionRepository
        self.preparationItemRepository = preparationItemRepository
        self.groupProjectRepository = groupProjectRepository ?? CoreDataGroupProjectRepository()

        let calcPriority = CalculateAssessmentPriorityUseCase()
        self.calculatePriorityUseCase = calcPriority
        let priorityAssessmentsUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: assessmentRepository,
            calculatePriorityUseCase: calcPriority
        )
        self.getPriorityAssessmentsUseCase = priorityAssessmentsUseCase
        self.getNextClassUseCase = GetNextClassUseCase(classSessionRepository: classSessionRepository)
        self.getClassPreparationUseCase = GetClassPreparationUseCase(preparationItemRepository: preparationItemRepository)
        self.getAllClassesUseCase = GetAllClassesUseCase(classSessionRepository: classSessionRepository)
        self.createAssessmentUseCase = CreateAssessmentUseCase(assessmentRepository: assessmentRepository)
        self.createClassSessionUseCase = CreateClassSessionUseCase(classSessionRepository: classSessionRepository)
        self.createSubjectUseCase = CreateSubjectUseCase(subjectRepository: subjectRepository)
        let getSubj = GetSubjectsUseCase(subjectRepository: subjectRepository)
        self.getSubjectsUseCase = getSubj
        self.toggleTaskCompletionUseCase = ToggleTaskCompletionUseCase(
            assessmentRepository: assessmentRepository,
            preparationItemRepository: preparationItemRepository
        )
        self.createTaskUseCase = CreateTaskUseCase(
            assessmentRepository: assessmentRepository,
            preparationItemRepository: preparationItemRepository
        )
        self.calculateAcademicProgressUseCase = CalculateAcademicProgressUseCase(
            assessmentRepository: assessmentRepository,
            preparationItemRepository: preparationItemRepository,
            subjectRepository: subjectRepository
        )
        self.getStudyNowRecommendationUseCase = GetStudyNowRecommendationUseCase(
            getPriorityAssessmentsUseCase: priorityAssessmentsUseCase,
            calculatePriorityUseCase: calcPriority
        )
        self.updateAssessmentProgressUseCase = UpdateAssessmentProgressUseCase(
            assessmentRepository: assessmentRepository
        )
        self.updateWidgetSnapshotUseCase = UpdateWidgetSnapshotUseCase(
            getPriorityAssessmentsUseCase: priorityAssessmentsUseCase,
            calculatePriorityUseCase: calcPriority,
            getNextClassUseCase: self.getNextClassUseCase,
            subjectRepository: self.subjectRepository
        )
        self.scheduleAssessmentReminderUseCase = ScheduleAssessmentReminderUseCase(
            getPriorityAssessmentsUseCase: priorityAssessmentsUseCase,
            calculatePriorityUseCase: calcPriority,
            subjectRepository: subjectRepository
        )
        let gpRepo = self.groupProjectRepository
        self.getGroupProjectsUseCase = GetGroupProjectsUseCase(groupProjectRepository: gpRepo)
        self.saveGroupProjectUseCase = SaveGroupProjectUseCase(groupProjectRepository: gpRepo)
        self.deleteGroupProjectUseCase = DeleteGroupProjectUseCase(groupProjectRepository: gpRepo)
        self.toggleGroupTaskUseCase = ToggleGroupTaskUseCase(groupProjectRepository: gpRepo)
        self.manageGroupDeliverablesUseCase = ManageGroupDeliverablesUseCase(groupProjectRepository: gpRepo)
        self.getStudentRemindersUseCase = GetStudentRemindersUseCase(
            assessmentRepository: assessmentRepository,
            classSessionRepository: classSessionRepository,
            preparationItemRepository: preparationItemRepository,
            subjectRepository: subjectRepository
        )
        self.getStudentTasksUseCase = GetStudentTasksUseCase(
            assessmentRepository: assessmentRepository,
            classSessionRepository: classSessionRepository,
            subjectRepository: subjectRepository
        )

        setupWidgetSyncObserver()
        performInitialWidgetSync()
        Task { [scheduleAssessmentReminderUseCase] in
            await scheduleAssessmentReminderUseCase.registerCategory()
        }
    }

    public func performInitialWidgetSync() {
        Task { @MainActor [weak self] in
            try? await self?.updateWidgetSnapshotUseCase.execute()
        }
    }

    private func setupWidgetSyncObserver() {
        self.widgetObserver = NotificationCenter.default.addObserver(
            forName: .academicDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.updateWidgetSnapshotUseCase.execute()
            }
        }
    }

    deinit {
        if let observer = widgetObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Stored Unified ViewModels (One source of truth per container)
    public private(set) lazy var dashboardViewModel: DashboardViewModel = {
        DashboardViewModel(
            getPriorityAssessmentsUseCase: getPriorityAssessmentsUseCase,
            getNextClassUseCase: getNextClassUseCase,
            getClassPreparationUseCase: getClassPreparationUseCase,
            calculatePriorityUseCase: calculatePriorityUseCase,
            getSubjectsUseCase: getSubjectsUseCase,
            createAssessmentUseCase: createAssessmentUseCase,
            createClassSessionUseCase: createClassSessionUseCase,
            createTaskUseCase: createTaskUseCase,
            createSubjectUseCase: createSubjectUseCase,
            getStudentTasksUseCase: getStudentTasksUseCase
        )
    }()

    public private(set) lazy var assessmentsViewModel: AssessmentsViewModel = {
        AssessmentsViewModel(
            getPriorityAssessmentsUseCase: getPriorityAssessmentsUseCase,
            calculatePriorityUseCase: calculatePriorityUseCase,
            createAssessmentUseCase: createAssessmentUseCase,
            toggleTaskCompletionUseCase: toggleTaskCompletionUseCase,
            createTaskUseCase: createTaskUseCase,
            getSubjectsUseCase: getSubjectsUseCase,
            createSubjectUseCase: createSubjectUseCase,
            updateAssessmentProgressUseCase: updateAssessmentProgressUseCase
        )
    }()

    public private(set) lazy var classesViewModel: ClassesViewModel = {
        ClassesViewModel(
            getAllClassesUseCase: getAllClassesUseCase,
            createClassSessionUseCase: createClassSessionUseCase,
            toggleTaskCompletionUseCase: toggleTaskCompletionUseCase,
            createTaskUseCase: createTaskUseCase,
            getSubjectsUseCase: getSubjectsUseCase,
            createSubjectUseCase: createSubjectUseCase
        )
    }()

    public private(set) lazy var tasksViewModel: TasksViewModel = {
        TasksViewModel(
            getStudentTasksUseCase: getStudentTasksUseCase,
            toggleTaskCompletionUseCase: toggleTaskCompletionUseCase,
            createTaskUseCase: createTaskUseCase
        )
    }()

    public private(set) lazy var studyNowViewModel: StudyNowViewModel = {
        StudyNowViewModel(
            getStudyNowRecommendationUseCase: getStudyNowRecommendationUseCase,
            subjectRepository: subjectRepository,
            toggleTaskCompletionUseCase: toggleTaskCompletionUseCase
        )
    }()

    public private(set) lazy var groupWorkViewModel: GroupWorkViewModel = {
        GroupWorkViewModel(
            getGroupProjectsUseCase: getGroupProjectsUseCase,
            saveGroupProjectUseCase: saveGroupProjectUseCase,
            deleteGroupProjectUseCase: deleteGroupProjectUseCase,
            toggleGroupTaskUseCase: toggleGroupTaskUseCase,
            manageGroupDeliverablesUseCase: manageGroupDeliverablesUseCase,
            getSubjectsUseCase: getSubjectsUseCase
        )
    }()

    public private(set) lazy var myProgressViewModel: MyProgressViewModel = {
        MyProgressViewModel(
            calculateAcademicProgressUseCase: calculateAcademicProgressUseCase
        )
    }()

    public private(set) lazy var remindersViewModel: RemindersViewModel = {
        RemindersViewModel(
            getStudentRemindersUseCase: getStudentRemindersUseCase,
            scheduleAssessmentReminderUseCase: scheduleAssessmentReminderUseCase
        )
    }()

    public private(set) lazy var classPreparationViewModel: ClassPreparationViewModel = {
        ClassPreparationViewModel(
            getClassPreparationUseCase: getClassPreparationUseCase
        )
    }()

    // MARK: - Factory Methods
    /// Creates and configures a `DashboardViewModel`.
    public func makeDashboardViewModel() -> DashboardViewModel {
        dashboardViewModel
    }

    /// Creates and configures an `AssessmentsViewModel`.
    public func makeAssessmentsViewModel() -> AssessmentsViewModel {
        assessmentsViewModel
    }

    /// Creates and configures a `ClassesViewModel`.
    public func makeClassesViewModel() -> ClassesViewModel {
        classesViewModel
    }

    /// Creates and configures a `TasksViewModel`.
    public func makeTasksViewModel() -> TasksViewModel {
        tasksViewModel
    }

    /// Creates and configures a `StudyNowViewModel`.
    public func makeStudyNowViewModel() -> StudyNowViewModel {
        studyNowViewModel
    }

    /// Creates and configures a `GroupWorkViewModel`.
    public func makeGroupWorkViewModel() -> GroupWorkViewModel {
        groupWorkViewModel
    }

    /// Creates and configures a `MyProgressViewModel`.
    public func makeMyProgressViewModel() -> MyProgressViewModel {
        myProgressViewModel
    }

    /// Creates and configures a `RemindersViewModel`.
    public func makeRemindersViewModel() -> RemindersViewModel {
        remindersViewModel
    }

    /// Creates and configures a `ClassPreparationViewModel`.
    public func makeClassPreparationViewModel() -> ClassPreparationViewModel {
        classPreparationViewModel
    }
}
