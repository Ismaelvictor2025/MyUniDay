//
//  PersistenceController.swift
//  MyUniDay
//
//  Data layer manager for the Core Data persistent stack.
//

import CoreData

/// Encapsulates the Core Data stack setup and management for MyUniDay.
///
/// Keeps Core Data infrastructure cleanly contained within the `Data/CoreData` layer.
public struct PersistenceController {
    /// Shared singleton instance for application runtime.
    public static let shared = PersistenceController()

    /// In-memory persistence controller configured with sample data for SwiftUI previews and testing.
    @MainActor
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Seed a sample subject with associated entities for previews
        let subject = SubjectEntity(context: context)
        let subjectId = UUID()
        subject.id = subjectId
        subject.code = "SWEN30006"
        subject.name = "Software Modelling and Design"
        subject.colorHex = "#2E7D32"

        let assessment = AssessmentEntity(context: context)
        assessment.id = UUID()
        assessment.title = "Software Architecture Milestone"
        assessment.dueDate = Date().addingTimeInterval(86400 * 7)
        assessment.weighting = 25.0
        assessment.estimatedWorkloadHours = 20.0
        assessment.progress = 0.3
        assessment.isCompleted = false
        assessment.subject = subject

        let task = AssessmentTaskEntity(context: context)
        task.id = UUID()
        task.title = "Draft Domain Model Diagram"
        task.isCompleted = true
        task.orderIndex = 0
        task.assessment = assessment

        let session = ClassSessionEntity(context: context)
        session.id = UUID()
        session.classTypeRaw = "Workshop"
        session.startDate = Date().addingTimeInterval(3600 * 2)
        session.endDate = Date().addingTimeInterval(3600 * 4)
        session.campus = "Parkville"
        session.building = "Doug McDonell"
        session.room = "Room 302"
        session.subject = subject

        let prepItem = PreparationItemEntity(context: context)
        prepItem.id = UUID()
        prepItem.title = "Bring iPad with Architecture sketch"
        prepItem.isCompleted = false
        prepItem.orderIndex = 0
        prepItem.classSession = session

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            assertionFailure("Failed to seed preview context: \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    /// The underlying Core Data container.
    public let container: NSPersistentContainer

    /// Initializes a persistence controller.
    ///
    /// - Parameter inMemory: If true, uses an in-memory store instead of disk (useful for tests and previews).
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyUniDay")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, log and handle gracefully.
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
