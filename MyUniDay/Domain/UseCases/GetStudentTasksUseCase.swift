//
//  GetStudentTasksUseCase.swift
//  MyUniDay
//
//  Domain Use Case aggregating actionable task sources across assessments and class sessions.
//

import Foundation

/// Errors that can occur when aggregating student tasks.
public enum StudentTasksError: LocalizedError, Equatable, Sendable {
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .persistenceFailed:
            return "Unable to load student tasks right now. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        "Pull down to refresh or check your coursework and timetable."
    }
}

/// Structured collection of academic resources providing actionable tasks.
public struct StudentTasksOverview: Sendable {
    public let assessments: [Assessment]
    public let sessions: [ClassSession]
    public let subjects: [UniversitySubject]
    public let subjectsById: [UUID: UniversitySubject]

    public init(
        assessments: [Assessment],
        sessions: [ClassSession],
        subjects: [UniversitySubject]
    ) {
        self.assessments = assessments
        self.sessions = sessions
        self.subjects = subjects
        var map: [UUID: UniversitySubject] = [:]
        for s in subjects { map[s.id] = s }
        self.subjectsById = map
    }
}

/// Gathers actionable task sources from assessments and class sessions.
public final class GetStudentTasksUseCase: Sendable {
    private let assessmentRepository: AssessmentRepositoryProtocol
    private let classSessionRepository: ClassSessionRepositoryProtocol
    private let subjectRepository: SubjectRepositoryProtocol?

    public init(
        assessmentRepository: AssessmentRepositoryProtocol,
        classSessionRepository: ClassSessionRepositoryProtocol,
        subjectRepository: SubjectRepositoryProtocol? = nil
    ) {
        self.assessmentRepository = assessmentRepository
        self.classSessionRepository = classSessionRepository
        self.subjectRepository = subjectRepository
    }

    /// Fetches all coursework assessments, scheduled class sessions, and enrolled subjects.
    public func execute() async throws -> StudentTasksOverview {
        do {
            async let subjectsTask = subjectRepository?.fetchSubjects() ?? []
            async let assessmentsTask = assessmentRepository.fetchAllAssessments()
            async let sessionsTask = classSessionRepository.fetchUpcomingClassSessions(from: .distantPast)

            let (subjects, assessments, sessions) = try await (subjectsTask, assessmentsTask, sessionsTask)

            return StudentTasksOverview(
                assessments: assessments,
                sessions: sessions,
                subjects: subjects
            )
        } catch {
            throw StudentTasksError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
