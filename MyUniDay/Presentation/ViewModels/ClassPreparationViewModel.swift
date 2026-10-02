//
//  ClassPreparationViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for class preparation checklists.
//

import Foundation
import Observation

/// ViewModel powering the class preparation checklist view.
///
/// Connects `GetClassPreparationUseCase` to future UI, computing presentation-derived metrics
/// such as completed count, remaining count, and overall preparation progress.
@Observable
@MainActor
public final class ClassPreparationViewModel {
    // MARK: - Dependencies
    private let getClassPreparationUseCase: GetClassPreparationUseCase

    // MARK: - Presentation State
    /// Ordered checklist of preparation items.
    public private(set) var items: [PreparationItem] = []

    /// Number of items marked as completed.
    public var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    /// Number of items still pending completion.
    public var remainingCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    /// Preparation completion progress from 0.0 to 1.0 suitable for progress bars.
    /// Returns 0.0 if the checklist is empty.
    public var progress: Double {
        guard !items.isEmpty else { return 0.0 }
        return Double(completedCount) / Double(items.count)
    }

    /// Indicates whether no preparation items exist after loading.
    public var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    /// Indicates whether items are currently being loaded.
    public private(set) var isLoading: Bool = false

    /// User-friendly error message if loading fails.
    public private(set) var errorMessage: String?

    // MARK: - Initialization
    /// Initializes the ViewModel with a `GetClassPreparationUseCase`.
    ///
    /// - Parameter getClassPreparationUseCase: Use case retrieving class preparation items.
    public init(getClassPreparationUseCase: GetClassPreparationUseCase) {
        self.getClassPreparationUseCase = getClassPreparationUseCase
    }

    // MARK: - Actions
    /// Loads preparation items for a specific class session ID.
    ///
    /// - Parameter sessionId: The unique identifier of the class session.
    public func loadPreparation(forSessionId sessionId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            self.items = try await getClassPreparationUseCase.execute(forSessionId: sessionId)
        } catch {
            self.errorMessage = "Unable to load class preparation items. Please try again."
        }

        isLoading = false
    }

    /// Loads preparation items for a specific `ClassSession`.
    ///
    /// - Parameter session: The target `ClassSession`.
    public func loadPreparation(for session: ClassSession) async {
        await loadPreparation(forSessionId: session.id)
    }
}
