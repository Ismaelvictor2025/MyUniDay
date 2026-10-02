//
//  UniversitySubject.swift
//  MyUniDay
//
//  Domain model representing an academic subject or course.
//

import Foundation

/// Represents a university subject or course enrolled by a student.
///
/// `UniversitySubject` acts as the root concept connecting academic assessments
/// and scheduled class sessions.
public struct UniversitySubject: Identifiable, Equatable, Hashable, Sendable {
    /// Unique identifier for the subject.
    public let id: UUID

    /// University subject code, e.g. "SWEN30006" or "COMP30022".
    public var code: String

    /// Full descriptive title of the subject, e.g. "Software Modelling and Design".
    public var name: String

    /// Optional hex colour code used for UI differentiation and visual hierarchy.
    public var colorHex: String?

    /// Assessments associated with this subject.
    public var assessments: [Assessment]

    /// Scheduled class sessions associated with this subject.
    public var classSessions: [ClassSession]

    /// Creates a new `UniversitySubject` domain model instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - code: Official subject/course code.
    ///   - name: Subject name.
    ///   - colorHex: Optional hexadecimal colour representation.
    ///   - assessments: Associated assessments (defaults to empty).
    ///   - classSessions: Associated class sessions (defaults to empty).
    public init(
        id: UUID = UUID(),
        code: String,
        name: String,
        colorHex: String? = nil,
        assessments: [Assessment] = [],
        classSessions: [ClassSession] = []
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.colorHex = colorHex
        self.assessments = assessments
        self.classSessions = classSessions
    }
}
