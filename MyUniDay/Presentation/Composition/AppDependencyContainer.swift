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

    private let persistenceController: PersistenceController

    /// Initializes the composition container.
    ///
    /// - Parameter persistenceController: The Core Data persistence controller (defaults to `.shared`).
    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    /// Creates and configures a `DashboardViewModel` with its required Domain Use Cases.
    ///
    /// - Returns: A fully configured `DashboardViewModel` instance.
    public func makeDashboardViewModel() -> DashboardViewModel {
        let viewContext = persistenceController.container.viewContext

        // 1. Data Layer: Repositories
        let assessmentRepository = CoreDataAssessmentRepository(context: viewContext)
        let classSessionRepository = CoreDataClassSessionRepository(context: viewContext)
        let preparationItemRepository = CoreDataPreparationItemRepository(context: viewContext)

        // 2. Domain Layer: Use Cases
        let calculatePriorityUseCase = CalculateAssessmentPriorityUseCase()
        let getPriorityAssessmentsUseCase = GetPriorityAssessmentsUseCase(
            assessmentRepository: assessmentRepository,
            calculatePriorityUseCase: calculatePriorityUseCase
        )
        let getNextClassUseCase = GetNextClassUseCase(classSessionRepository: classSessionRepository)
        let getClassPreparationUseCase = GetClassPreparationUseCase(preparationItemRepository: preparationItemRepository)

        // 3. Presentation Layer: ViewModel
        return DashboardViewModel(
            getPriorityAssessmentsUseCase: getPriorityAssessmentsUseCase,
            getNextClassUseCase: getNextClassUseCase,
            getClassPreparationUseCase: getClassPreparationUseCase,
            calculatePriorityUseCase: calculatePriorityUseCase
        )
    }
}
