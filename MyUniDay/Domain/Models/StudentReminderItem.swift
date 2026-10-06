//
//  StudentReminderItem.swift
//  MyUniDay
//
//  Domain model representing actionable student reminders across coursework, classes, and tasks.
//

import Foundation

/// Categorisation of university reminders.
public enum ReminderCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case assessments = "Assessments"
    case classes = "Classes & Prep"
    case tasks = "Tasks"

    public var id: String { rawValue }
}

/// An individual reminder summarizing an upcoming academic commitment.
public struct StudentReminderItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let detail: String
    public let dueDate: Date?
    public let category: ReminderCategory
    public let isUrgent: Bool
    public let iconName: String

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        detail: String,
        dueDate: Date? = nil,
        category: ReminderCategory,
        isUrgent: Bool,
        iconName: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.dueDate = dueDate
        self.category = category
        self.isUrgent = isUrgent
        self.iconName = iconName
    }
}
