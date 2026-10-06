//
//  GetNextClassUseCase.swift
//  MyUniDay
//
//  Use case that determines the student's next upcoming class session.
//

import Foundation

/// Retrieves class sessions through `ClassSessionRepositoryProtocol` and identifies
/// the immediate next upcoming class relative to a supplied reference date.
public final class GetNextClassUseCase: Sendable {
    private let classSessionRepository: ClassSessionRepositoryProtocol

    /// Initializes the use case with a class session repository.
    ///
    /// - Parameter classSessionRepository: The persistence repository conforming to `ClassSessionRepositoryProtocol`.
    public init(classSessionRepository: ClassSessionRepositoryProtocol) {
        self.classSessionRepository = classSessionRepository
    }

    /// Determines the student's next upcoming class session.
    ///
    /// - Parameter referenceDate: The reference timestamp to evaluate upcoming classes against (defaults to current date).
    /// - Returns: The earliest upcoming `ClassSession` starting at or after `referenceDate`, or `nil` if none are scheduled.
    public func execute(relativeTo referenceDate: Date = Date()) async throws -> ClassSession? {
        do {
            let upcomingSessions = try await classSessionRepository.fetchUpcomingClassSessions(from: referenceDate)

            // Strict filter: ensure the session starts at or after the reference timestamp
            let futureSessions = upcomingSessions.filter { $0.startDate >= referenceDate }

            // Return the earliest upcoming class
            return futureSessions.min(by: { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                if lhs.endDate != rhs.endDate {
                    return lhs.endDate < rhs.endDate
                }
                return lhs.room < rhs.room
            })
        } catch {
            throw NextClassError.scheduleUnavailable(reason: error.localizedDescription)
        }
    }
}
