//
//  WidgetAcademicSnapshot.swift
//  MyUniDay
//
//  Shared, Codable academic snapshot transferred to the WidgetKit extension
//  via the shared App Group container (group.com.vicky.MyUniDay).
//

import Foundation

/// Codable data snapshot consumed by the MyUniDay WidgetKit extension.
public struct WidgetAcademicSnapshot: Codable, Equatable, Sendable {
    // MARK: - Priority Assessment Details (Primary Content)
    public var hasAssessment: Bool
    public var priorityAssessmentTitle: String?
    public var subjectCode: String?
    public var subjectName: String?
    public var priorityLevel: String? // "Critical", "High", "Medium", "Low"
    public var dueDate: Date?
    public var progress: Double // 0.0 to 1.0
    public var remainingTaskCount: Int
    public var totalTaskCount: Int

    // MARK: - Next Class Details (Medium Widget Content)
    public var hasUpcomingClass: Bool
    public var nextClassSubjectCode: String?
    public var nextClassType: String? // "Lecture", "Tutorial", "Workshop", "Lab", "Seminar"
    public var nextClassStartTime: Date?
    public var nextClassEndTime: Date?
    public var nextClassBuilding: String?
    public var nextClassRoom: String?

    // MARK: - Metadata
    public var lastUpdated: Date

    public init(
        hasAssessment: Bool = false,
        priorityAssessmentTitle: String? = nil,
        subjectCode: String? = nil,
        subjectName: String? = nil,
        priorityLevel: String? = nil,
        dueDate: Date? = nil,
        progress: Double = 0.0,
        remainingTaskCount: Int = 0,
        totalTaskCount: Int = 0,
        hasUpcomingClass: Bool = false,
        nextClassSubjectCode: String? = nil,
        nextClassType: String? = nil,
        nextClassStartTime: Date? = nil,
        nextClassEndTime: Date? = nil,
        nextClassBuilding: String? = nil,
        nextClassRoom: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.hasAssessment = hasAssessment
        self.priorityAssessmentTitle = priorityAssessmentTitle
        self.subjectCode = subjectCode
        self.subjectName = subjectName
        self.priorityLevel = priorityLevel
        self.dueDate = dueDate
        self.progress = progress
        self.remainingTaskCount = remainingTaskCount
        self.totalTaskCount = totalTaskCount
        self.hasUpcomingClass = hasUpcomingClass
        self.nextClassSubjectCode = nextClassSubjectCode
        self.nextClassType = nextClassType
        self.nextClassStartTime = nextClassStartTime
        self.nextClassEndTime = nextClassEndTime
        self.nextClassBuilding = nextClassBuilding
        self.nextClassRoom = nextClassRoom
        self.lastUpdated = lastUpdated
    }

    /// Empty state when no assessments and no upcoming classes exist.
    public static var empty: WidgetAcademicSnapshot {
        WidgetAcademicSnapshot(
            hasAssessment: false,
            hasUpcomingClass: false,
            lastUpdated: Date.distantPast
        )
    }

    /// Realistic preview snapshot for Xcode previews and Widget Gallery placeholders.
    public static var previewSample: WidgetAcademicSnapshot {
        WidgetAcademicSnapshot(
            hasAssessment: true,
            priorityAssessmentTitle: "Assignment 2: Polymorphic System",
            subjectCode: "COMP2014",
            subjectName: "Object Oriented Programming",
            priorityLevel: "Critical",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            progress: 0.50,
            remainingTaskCount: 3,
            totalTaskCount: 6,
            hasUpcomingClass: true,
            nextClassSubjectCode: "COMP2014",
            nextClassType: "Workshop",
            nextClassStartTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()),
            nextClassEndTime: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()),
            nextClassBuilding: "Building EA",
            nextClassRoom: "Room 15",
            lastUpdated: Date()
        )
    }

    /// Human-friendly relative due date descriptor.
    public var dueDescription: String {
        guard let due = dueDate else { return "No due date" }
        let calendar = Calendar.current
        if calendar.isDateInToday(due) {
            return "Due Today"
        } else if calendar.isDateInTomorrow(due) {
            return "Due Tomorrow"
        } else if due < Date() {
            return "Overdue"
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: due)).day ?? 0
            if days <= 7 {
                return "Due in \(days) days"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMM"
                return "Due \(formatter.string(from: due))"
            }
        }
    }

    /// Formatted percentage string (e.g. "50% complete" or "67% complete").
    public var progressPercentageString: String {
        "\(Int(round(progress * 100)))% complete"
    }

    /// Formatted tasks description (e.g. "3 tasks remaining" or "1 task remaining").
    public var tasksRemainingDescription: String {
        if remainingTaskCount == 1 {
            return "1 task remaining"
        } else if remainingTaskCount > 1 {
            return "\(remainingTaskCount) tasks remaining"
        } else {
            return "All tasks complete"
        }
    }

    /// Formatted class time window string (e.g. "11:00 AM – 1:00 PM").
    public var classTimeString: String? {
        guard let start = nextClassStartTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if let end = nextClassEndTime {
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        } else {
            return formatter.string(from: start)
        }
    }

    /// Formatted class location string (e.g. "Building EA • Room 15").
    public var classLocationString: String? {
        var parts: [String] = []
        if let b = nextClassBuilding, !b.isEmpty {
            parts.append(b)
        }
        if let r = nextClassRoom, !r.isEmpty {
            parts.append(r)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
