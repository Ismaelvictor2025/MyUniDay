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
    /// - Throws: `ClassSessionCreationError` if building, room, campus is empty, end time < start time, or persistence fails.
    public func execute(classSession: ClassSession, forSubjectId subjectId: UUID) async throws {
        let trimmedBuilding = classSession.building.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBuilding.isEmpty else {
            throw ClassSessionCreationError.emptyBuilding
        }

        let trimmedRoom = classSession.room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoom.isEmpty else {
            throw ClassSessionCreationError.emptyRoom
        }

        let trimmedCampus = classSession.campus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCampus.isEmpty else {
            throw ClassSessionCreationError.emptyCampus
        }

        guard classSession.endDate >= classSession.startDate else {
            throw ClassSessionCreationError.invalidTimeRange
        }

        var validated = classSession
        validated.building = trimmedBuilding
        validated.room = trimmedRoom
        validated.campus = trimmedCampus
        validated.subjectId = subjectId

        do {
            try await classSessionRepository.save(classSession: validated, forSubjectId: subjectId)
            NotificationCenter.default.post(name: .academicDataDidChange, object: nil)
        } catch {
            throw ClassSessionCreationError.persistenceFailed(reason: error.localizedDescription)
        }
    }
}
