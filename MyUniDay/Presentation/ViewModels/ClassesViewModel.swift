//
//  ClassesViewModel.swift
//  MyUniDay
//
//  Presentation ViewModel for timetable and class session management.
//

import Foundation
import Observation

/// Group of class sessions occurring on the same calendar day.
public struct ClassDayGroup: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let sessions: [ClassSession]

    public var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, d MMMM"
            return formatter.string(from: date)
        }
    }
}

/// ViewModel powering the Classes / Timetable screen and class details.
@Observable
@MainActor
public final class ClassesViewModel {
    // MARK: - Dependencies
    private let getAllClassesUseCase: GetAllClassesUseCase
    private let createClassSessionUseCase: CreateClassSessionUseCase?
    private let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase?
    private let createTaskUseCase: CreateTaskUseCase?
    private let getSubjectsUseCase: GetSubjectsUseCase?
    private let createSubjectUseCase: CreateSubjectUseCase?

    // MARK: - Presentation State
    /// Chronologically ordered upcoming class sessions.
    public private(set) var classes: [ClassSession] = []

    /// Available university subjects.
    public private(set) var subjects: [UniversitySubject] = []

    /// Indicates whether class sessions are being loaded.
    public private(set) var isLoading: Bool = false

    /// User-friendly error message if loading fails.
    public private(set) var errorMessage: String?

    /// Sessions grouped by day.
    public var groupedClasses: [ClassDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: classes) { session in
            calendar.startOfDay(for: session.startDate)
        }
        return grouped.keys.sorted().map { date in
            let sortedSessions = (grouped[date] ?? []).sorted { $0.startDate < $1.startDate }
            return ClassDayGroup(date: date, sessions: sortedSessions)
        }
    }

    /// Whether there are no scheduled classes.
    public var isEmpty: Bool {
        classes.isEmpty && !isLoading
    }

    // MARK: - Initialization
    public init(
        getAllClassesUseCase: GetAllClassesUseCase,
        createClassSessionUseCase: CreateClassSessionUseCase? = nil,
        toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase? = nil,
        createTaskUseCase: CreateTaskUseCase? = nil,
        getSubjectsUseCase: GetSubjectsUseCase? = nil,
        createSubjectUseCase: CreateSubjectUseCase? = nil
    ) {
        self.getAllClassesUseCase = getAllClassesUseCase
        self.createClassSessionUseCase = createClassSessionUseCase
        self.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase
        self.createTaskUseCase = createTaskUseCase
        self.getSubjectsUseCase = getSubjectsUseCase
        self.createSubjectUseCase = createSubjectUseCase
    }

    // MARK: - Actions
    /// Loads upcoming class sessions and subjects.
    public func loadClasses(from referenceDate: Date = Date()) async {
        isLoading = true
        errorMessage = nil

        do {
            async let classesTask = getAllClassesUseCase.execute(from: referenceDate)
            async let subjectsTask = getSubjectsUseCase?.execute() ?? []

            let (fetchedClasses, fetchedSubjects) = try await (classesTask, subjectsTask)
            self.classes = fetchedClasses
            self.subjects = fetchedSubjects
        } catch {
            self.errorMessage = "Unable to load timetable. Please try again."
        }

        isLoading = false
    }

    /// Creates and persists a new class session.
    public func createClass(
        subjectId: UUID,
        classType: ClassType,
        startDate: Date,
        endDate: Date,
        campus: String,
        building: String,
        room: String,
        preparationItems: [PreparationItem] = []
    ) async throws {
        guard let useCase = createClassSessionUseCase else {
            throw RepositoryError.invalidData(reason: "Class creation capability not configured.")
        }

        let session = ClassSession(
            subjectId: subjectId,
            classType: classType,
            startDate: startDate,
            endDate: endDate,
            campus: campus,
            building: building,
            room: room,
            preparationItems: preparationItems
        )

        try await useCase.execute(classSession: session, forSubjectId: subjectId)
        await loadClasses()
    }

    /// Toggles completion status of a preparation item.
    public func togglePreparationItem(item: PreparationItem, inSessionId sessionId: UUID) async {
        guard let useCase = toggleTaskCompletionUseCase else { return }
        do {
            _ = try await useCase.togglePreparationItem(item: item, inSessionId: sessionId)
            await loadClasses()
        } catch {
            self.errorMessage = "Failed to update preparation item."
        }
    }

    /// Appends a new preparation item to a class session.
    public func addPreparationItem(title: String, notes: String? = nil, toSessionId sessionId: UUID) async throws {
        guard let useCase = createTaskUseCase else {
            throw RepositoryError.invalidData(reason: "Preparation item creation not configured.")
        }
        _ = try await useCase.addPreparationItem(title: title, notes: notes, toSessionId: sessionId)
        await loadClasses()
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
