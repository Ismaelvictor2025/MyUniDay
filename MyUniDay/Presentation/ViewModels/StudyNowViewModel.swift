//
//  StudyNowViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for the "Study Now" smart prioritisation screen.
//

import Foundation
import Observation

/// ViewModel managing the "Study Now" academic focus screen.
@Observable
@MainActor
public final class StudyNowViewModel {
    private let getStudyNowRecommendationUseCase: GetStudyNowRecommendationUseCase
    private let subjectRepository: SubjectRepositoryProtocol?
    private let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase?

    public private(set) var recommendation: StudyRecommendation?
    public private(set) var subject: UniversitySubject?
    public private(set) var isLoading: Bool = false
    public private(set) var hasLoadedInitialData: Bool = false
    public private(set) var errorMessage: String?
    private nonisolated(unsafe) var dataObserver: (any NSObjectProtocol)?

    public init(
        getStudyNowRecommendationUseCase: GetStudyNowRecommendationUseCase,
        subjectRepository: SubjectRepositoryProtocol? = nil,
        toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase? = nil
    ) {
        self.getStudyNowRecommendationUseCase = getStudyNowRecommendationUseCase
        self.subjectRepository = subjectRepository
        self.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase

        self.dataObserver = NotificationCenter.default.addObserver(
            forName: .academicDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.loadRecommendation()
            }
        }
    }

    deinit {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Loads the top recommended assessment to work on now.
    public func loadRecommendation(relativeTo referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            let rec = try await getStudyNowRecommendationUseCase.execute(relativeTo: referenceDate)
            self.recommendation = rec

            if let subjectId = rec?.assessment.subjectId {
                let subjects = (try? await subjectRepository?.fetchSubjects()) ?? []
                self.subject = subjects.first { $0.id == subjectId }
            } else {
                self.subject = nil
            }
        } catch {
            self.errorMessage = "Unable to evaluate study recommendations. Please try again."
        }

        hasLoadedInitialData = true
        isLoading = false
    }

    /// Marks the recommended unfinished step complete and recalculates the recommendation.
    public func markCurrentStepComplete() async {
        guard let rec = recommendation,
              let task = rec.nextPendingTask,
              let toggleUseCase = toggleTaskCompletionUseCase else {
            return
        }

        do {
            _ = try await toggleUseCase.toggleAssessmentTask(taskId: task.id, inAssessmentId: rec.assessment.id)
            await loadRecommendation()
        } catch {
            self.errorMessage = "Failed to complete milestone."
        }
    }
}
