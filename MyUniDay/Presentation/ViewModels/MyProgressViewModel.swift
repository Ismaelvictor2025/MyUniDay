//
//  MyProgressViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for student productivity and completion progress.
//

import Foundation
import Observation

/// ViewModel managing the academic productivity and completion progress report.
@Observable
@MainActor
public final class MyProgressViewModel {
    private let calculateAcademicProgressUseCase: CalculateAcademicProgressUseCase

    public private(set) var report: AcademicProgressReport = .empty
    public private(set) var isLoading: Bool = false
    public private(set) var hasLoadedInitialData: Bool = false
    public private(set) var errorMessage: String?
    private nonisolated(unsafe) var dataObserver: (any NSObjectProtocol)?

    public init(calculateAcademicProgressUseCase: CalculateAcademicProgressUseCase) {
        self.calculateAcademicProgressUseCase = calculateAcademicProgressUseCase

        self.dataObserver = NotificationCenter.default.addObserver(
            forName: .academicDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.loadProgress()
            }
        }
    }

    deinit {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Loads the latest progress report.
    public func loadProgress() async {
        isLoading = true
        errorMessage = nil

        do {
            self.report = try await calculateAcademicProgressUseCase.execute()
        } catch {
            self.errorMessage = "Unable to calculate academic progress."
        }

        hasLoadedInitialData = true
        isLoading = false
    }
}
