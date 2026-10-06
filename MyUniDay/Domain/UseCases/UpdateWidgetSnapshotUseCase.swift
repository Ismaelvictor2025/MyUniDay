//
//  UpdateWidgetSnapshotUseCase.swift
//  MyUniDay
//
//  Gathers the highest-priority assessment and immediate next class from the
//  authoritative Domain Use Cases, writes the snapshot to the App Group, and
//  notifies WidgetCenter to reload timelines.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Coordinates gathering current coursework and schedule state, persisting the
/// shared widget snapshot, and requesting WidgetKit timeline reloads.
public final class UpdateWidgetSnapshotUseCase: Sendable {
    private let getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase
    private let calculatePriorityUseCase: CalculateAssessmentPriorityUseCase
    private let getNextClassUseCase: GetNextClassUseCase
    private let subjectRepository: SubjectRepositoryProtocol
    private let snapshotStore: WidgetSnapshotStore

    public init(
        getPriorityAssessmentsUseCase: GetPriorityAssessmentsUseCase,
        calculatePriorityUseCase: CalculateAssessmentPriorityUseCase,
        getNextClassUseCase: GetNextClassUseCase,
        subjectRepository: SubjectRepositoryProtocol,
        snapshotStore: WidgetSnapshotStore = .shared
    ) {
        self.getPriorityAssessmentsUseCase = getPriorityAssessmentsUseCase
        self.calculatePriorityUseCase = calculatePriorityUseCase
        self.getNextClassUseCase = getNextClassUseCase
        self.subjectRepository = subjectRepository
        self.snapshotStore = snapshotStore
    }

    /// Generates the latest snapshot, saves it to App Group storage, and triggers a WidgetKit reload.
    @discardableResult
    public func execute(relativeTo referenceDate: Date = Date()) async throws -> WidgetAcademicSnapshot {
        #if DEBUG
        print("[WidgetSync] snapshot refresh requested at \(referenceDate)")
        #endif

        // 1. Fetch highest-priority incomplete assessment
        let priorityAssessments = try await getPriorityAssessmentsUseCase.execute(relativeTo: referenceDate)
        let topAssessment = priorityAssessments.first

        #if DEBUG
        print("[WidgetSync] number of assessments received: \(priorityAssessments.count)")
        if let top = topAssessment {
            print("[WidgetSync] selected priority assessment title: '\(top.title)'")
            print("[WidgetSync] selected progress value: \(String(format: "%.0f%%", top.progress * 100))")
            let incompleteCount = top.tasks.filter { !$0.isCompleted }.count
            print("[WidgetSync] remaining task count: \(incompleteCount) (total: \(top.tasks.count))")
        } else {
            print("[WidgetSync] selected priority assessment title: none")
            print("[WidgetSync] selected progress value: 0%")
            print("[WidgetSync] remaining task count: 0")
        }
        #endif

        // 2. Fetch next upcoming class
        let nextClass = try await getNextClassUseCase.execute(relativeTo: referenceDate)

        #if DEBUG
        if let session = nextClass {
            print("[WidgetSync] next class selected: '\(session.classType.rawValue)' at \(session.startDate)")
        } else {
            print("[WidgetSync] next class selected (or none): none")
        }
        #endif

        // 3. Resolve subjects
        let subjects = (try? await subjectRepository.fetchSubjects()) ?? []
        let subjectsById = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })

        var snapshot = WidgetAcademicSnapshot(lastUpdated: referenceDate)

        if let assessment = topAssessment {
            snapshot.hasAssessment = true
            snapshot.priorityAssessmentTitle = assessment.title
            if let subjectId = assessment.subjectId, let subject = subjectsById[subjectId] {
                snapshot.subjectCode = subject.code
                snapshot.subjectName = subject.name
            }
            let priority = calculatePriorityUseCase.execute(for: assessment, relativeTo: referenceDate)
            snapshot.priorityLevel = priority.rawValue
            snapshot.dueDate = assessment.dueDate
            snapshot.progress = assessment.progress

            let incompleteTasks = assessment.tasks.filter { !$0.isCompleted }
            snapshot.remainingTaskCount = incompleteTasks.count
            snapshot.totalTaskCount = assessment.tasks.count
        }

        if let session = nextClass {
            snapshot.hasUpcomingClass = true
            if let subjectId = session.subjectId, let subject = subjectsById[subjectId] {
                snapshot.nextClassSubjectCode = subject.code
            }
            snapshot.nextClassType = session.classType.rawValue
            snapshot.nextClassStartTime = session.startDate
            snapshot.nextClassEndTime = session.endDate
            snapshot.nextClassBuilding = session.building
            snapshot.nextClassRoom = session.room
        }

        // Save to App Group storage
        let writeSuccess = snapshotStore.save(snapshot: snapshot)

        #if DEBUG
        if writeSuccess {
            print("[WidgetSync] App Group snapshot write success to \(snapshotStore.appGroupIdentifier)")
        } else {
            print("[WidgetSync] App Group snapshot write failure to \(snapshotStore.appGroupIdentifier)")
        }
        #endif

        // Request WidgetKit reload
        #if canImport(WidgetKit)
        #if DEBUG
        print("[WidgetSync] Widget reload requested via WidgetCenter.shared.reloadAllTimelines()")
        #endif
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        return snapshot
    }
}
