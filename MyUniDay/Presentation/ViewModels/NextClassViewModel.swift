//
//  NextClassViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for the next upcoming class.
//

import Foundation
import Observation

/// ViewModel responsible for providing timetable or dashboard components with the student's next upcoming class.
///
/// Connects `GetNextClassUseCase` to future views while keeping date evaluation testable.
@Observable
@MainActor
public final class NextClassViewModel {
    // MARK: - Dependencies
    private let getNextClassUseCase: GetNextClassUseCase

    // MARK: - Presentation State
    /// The next scheduled class session, or nil if none are upcoming.
    public private(set) var nextClass: ClassSession?

    /// Convenience flag indicating whether an upcoming class session exists.
    public var hasNextClass: Bool {
        nextClass != nil
    }

    /// Indicates whether the class query is currently in progress.
    public private(set) var isLoading: Bool = false

    /// User-friendly error message if loading fails.
    public private(set) var errorMessage: String?

    // MARK: - Initialization
    /// Initializes the ViewModel with a `GetNextClassUseCase`.
    ///
    /// - Parameter getNextClassUseCase: Use case determining the next class session.
    public init(getNextClassUseCase: GetNextClassUseCase) {
        self.getNextClassUseCase = getNextClassUseCase
    }

    // MARK: - Actions
    /// Loads the next upcoming class relative to the specified timestamp.
    ///
    /// - Parameter referenceDate: Reference timestamp for determining upcoming status (defaults to current date).
    public func loadNextClass(relativeTo referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            self.nextClass = try await getNextClassUseCase.execute(relativeTo: referenceDate)
        } catch {
            self.errorMessage = "Unable to load the next class session. Please try again."
        }

        isLoading = false
    }
}
