//
//  CreateClassSessionUseCase.swift
//  MyUniDay
//
//  Domain use case validating and persisting newly scheduled class sessions.
//

import Foundation

/// Validates and persists a scheduled class session associated with a university subject.
public final class CreateClassSessionUseCase: Sendable {
    private let classSessionRepository: ClassSessionRepositoryProtocol

    /// Initializes the use case with a class session repository.
    public init(classSessionRepository: ClassSessionRepositoryProtocol) {
        self.classSessionRepository = classSessionRepository
    }

    /// Validates class scheduling parameters and persists the session.
    ///
    /// - Parameters:
    ///   - classSession: The class session domain model to validate and save.
    ///   - subjectId: The UUID of the parent university subject.
    /// - Throws: `RepositoryError.invalidData` if building, room, campus is empty or end time < start time.
    public func execute(classSession: ClassSession, forSubjectId subjectId: UUID) async throws {
        let trimmedBuilding = classSession.building.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBuilding.isEmpty else {
            throw RepositoryError.invalidData(reason: "Building cannot be empty.")
        }

        let trimmedRoom = classSession.room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoom.isEmpty else {
            throw RepositoryError.invalidData(reason: "Room cannot be empty.")
        }

        let trimmedCampus = classSession.campus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCampus.isEmpty else {
            throw RepositoryError.invalidData(reason: "Campus cannot be empty.")
        }

        guard classSession.endDate >= classSession.startDate else {
            throw RepositoryError.invalidData(reason: "Class end time cannot be earlier than start time.")
        }

        var validated = classSession
        validated.building = trimmedBuilding
        validated.room = trimmedRoom
        validated.campus = trimmedCampus
        validated.subjectId = subjectId

        try await classSessionRepository.save(classSession: validated, forSubjectId: subjectId)
    }
}
