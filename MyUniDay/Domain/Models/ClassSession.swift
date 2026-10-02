//
//  ClassSession.swift
//  MyUniDay
//
//  Domain model representing a scheduled university class session.
//

import Foundation

/// Defines the instructional format or type of a university class session.
public enum ClassType: String, CaseIterable, Codable, Sendable {
    case lecture = "Lecture"
    case tutorial = "Tutorial"
    case lab = "Lab"
    case workshop = "Workshop"
    case seminar = "Seminar"
    case studio = "Studio"
    case other = "Other"
}

/// Represents a scheduled timetable event for a subject (e.g. a lecture, tutorial, or lab).
///
/// Contains precise scheduling and location details to answer "Where do I need to be?"
/// and "When do I need to be there?".
public struct ClassSession: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the class session.
    public let id: UUID

    /// Optional reference to the parent subject's identifier.
    public var subjectId: UUID?

    /// The format of the class (e.g. Lecture, Lab, Tutorial).
    public var classType: ClassType

    /// Starting date and time for the session.
    public var startDate: Date

    /// Ending date and time for the session.
    public var endDate: Date

    /// University campus name, e.g. "Parkville" or "City Campus".
    public var campus: String

    /// Building name or number, e.g. "Doug McDonell Building".
    public var building: String

    /// Room or theatre code, e.g. "Room 302" or "Theatre A".
    public var room: String

    /// Checklist of materials or tasks required before attending this class.
    public var preparationItems: [PreparationItem]

    /// Creates a new `ClassSession` domain model instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - subjectId: Optional parent subject ID.
    ///   - classType: The format of the session.
    ///   - startDate: Scheduled start timestamp.
    ///   - endDate: Scheduled end timestamp.
    ///   - campus: Campus name.
    ///   - building: Building name or identifier.
    ///   - room: Room designation.
    ///   - preparationItems: Preparation requirements (defaults to empty).
    public init(
        id: UUID = UUID(),
        subjectId: UUID? = nil,
        classType: ClassType,
        startDate: Date,
        endDate: Date,
        campus: String,
        building: String,
        room: String,
        preparationItems: [PreparationItem] = []
    ) {
        self.id = id
        self.subjectId = subjectId
        self.classType = classType
        self.startDate = startDate
        self.endDate = endDate
        self.campus = campus
        self.building = building
        self.room = room
        self.preparationItems = preparationItems
    }
}
