//
//  UnifiedTaskItem.swift
//  MyUniDay
//
//  Presentation model unifying AssessmentTask and PreparationItem for the Tasks screen.
//

import Foundation

/// Defines the source and context of an actionable student task.
public enum UnifiedTaskSource: Equatable, Hashable, Sendable {
    case assessment(assessmentId: UUID, assessmentTitle: String, subjectCode: String?)
    case classSession(sessionId: UUID, classTitle: String, classDate: Date)

    public var title: String {
        switch self {
        case .assessment(_, let title, let code):
            if let code = code, !code.isEmpty {
                return "\(code) • \(title)"
            }
            return title
        case .classSession(_, let title, _):
            return title
        }
    }

    public var iconName: String {
        switch self {
        case .assessment:
            return "doc.text.fill"
        case .classSession:
            return "calendar"
        }
    }
}

/// Presentation item representing an actionable task across assessments or class preparation.
public struct UnifiedTaskItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var dueDate: Date?
    public var source: UnifiedTaskSource
    public var originalAssessmentTask: AssessmentTask?
    public var originalPreparationItem: PreparationItem?

    public init(
        id: UUID,
        title: String,
        notes: String? = nil,
        isCompleted: Bool,
        dueDate: Date? = nil,
        source: UnifiedTaskSource,
        originalAssessmentTask: AssessmentTask? = nil,
        originalPreparationItem: PreparationItem? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.source = source
        self.originalAssessmentTask = originalAssessmentTask
        self.originalPreparationItem = originalPreparationItem
    }
}
