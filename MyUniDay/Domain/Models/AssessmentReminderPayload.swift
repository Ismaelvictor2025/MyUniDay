//
//  AssessmentReminderPayload.swift
//  MyUniDay
//
//  Shared data representation and serialization for custom academic notification reminders.
//

import Foundation

/// Encapsulates the academic context required by the custom Notification Content Extension.
///
/// Designed to be serialized cleanly into `UNNotificationContent.userInfo` and safely parsed
/// by `MyUniDayNotificationContent` without crashes or missing field failures.
public struct AssessmentReminderPayload: Codable, Equatable, Sendable {
    public static let categoryIdentifier = "MYUNIDAY_ASSESSMENT_REMINDER"

    public struct Keys {
        public static let assessmentId = "assessmentId"
        public static let assessmentTitle = "assessmentTitle"
        public static let subjectCode = "subjectCode"
        public static let subjectName = "subjectName"
        public static let priority = "priority"
        public static let dueDate = "dueDate"
        public static let formattedDueDate = "formattedDueDate"
        public static let progress = "progress"
        public static let remainingTaskCount = "remainingTaskCount"
        public static let totalTaskCount = "totalTaskCount"
        public static let formattedProgress = "formattedProgress"
        public static let formattedTasksRemaining = "formattedTasksRemaining"
    }

    public let assessmentId: UUID?
    public let assessmentTitle: String
    public let subjectCode: String
    public let subjectName: String?
    public let priority: String
    public let dueDate: Date?
    public let formattedDueDate: String
    public let progress: Double
    public let remainingTaskCount: Int
    public let totalTaskCount: Int

    public var formattedProgress: String {
        let percent = Int(round(progress * 100))
        return "\(percent)% complete"
    }

    public var formattedTasksRemaining: String {
        if remainingTaskCount <= 0 {
            return "All tasks complete"
        } else if remainingTaskCount == 1 {
            return "1 task remaining"
        } else {
            return "\(remainingTaskCount) tasks remaining"
        }
    }

    public init(
        assessmentId: UUID? = nil,
        assessmentTitle: String,
        subjectCode: String,
        subjectName: String? = nil,
        priority: String,
        dueDate: Date? = nil,
        formattedDueDate: String,
        progress: Double,
        remainingTaskCount: Int,
        totalTaskCount: Int
    ) {
        self.assessmentId = assessmentId
        self.assessmentTitle = assessmentTitle
        self.subjectCode = subjectCode
        self.subjectName = subjectName
        self.priority = priority
        self.dueDate = dueDate
        self.formattedDueDate = formattedDueDate
        self.progress = progress
        self.remainingTaskCount = remainingTaskCount
        self.totalTaskCount = totalTaskCount
    }

    /// Serializes payload into dictionary format suitable for `UNNotificationContent.userInfo`.
    public func toUserInfo() -> [AnyHashable: Any] {
        var dict: [AnyHashable: Any] = [
            Keys.assessmentTitle: assessmentTitle,
            Keys.subjectCode: subjectCode,
            Keys.priority: priority,
            Keys.formattedDueDate: formattedDueDate,
            Keys.progress: progress,
            Keys.remainingTaskCount: remainingTaskCount,
            Keys.totalTaskCount: totalTaskCount,
            Keys.formattedProgress: formattedProgress,
            Keys.formattedTasksRemaining: formattedTasksRemaining
        ]
        if let id = assessmentId {
            dict[Keys.assessmentId] = id.uuidString
        }
        if let name = subjectName {
            dict[Keys.subjectName] = name
        }
        if let date = dueDate {
            dict[Keys.dueDate] = date.timeIntervalSince1970
        }
        return dict
    }

    /// Safely parses notification `userInfo`, providing robust defaults for missing or malformed fields.
    public init(userInfo: [AnyHashable: Any]) {
        self.assessmentTitle = userInfo[Keys.assessmentTitle] as? String ?? "Academic Assessment"
        self.subjectCode = userInfo[Keys.subjectCode] as? String ?? "MYUNIDAY"
        self.subjectName = userInfo[Keys.subjectName] as? String
        self.priority = userInfo[Keys.priority] as? String ?? "High"
        self.formattedDueDate = userInfo[Keys.formattedDueDate] as? String ?? "Due soon"

        // Handle numeric conversion safely (Double vs NSNumber)
        if let p = userInfo[Keys.progress] as? Double {
            self.progress = p
        } else if let pNum = userInfo[Keys.progress] as? NSNumber {
            self.progress = pNum.doubleValue
        } else {
            self.progress = 0.0
        }

        if let r = userInfo[Keys.remainingTaskCount] as? Int {
            self.remainingTaskCount = r
        } else if let rNum = userInfo[Keys.remainingTaskCount] as? NSNumber {
            self.remainingTaskCount = rNum.intValue
        } else {
            self.remainingTaskCount = 0
        }

        if let t = userInfo[Keys.totalTaskCount] as? Int {
            self.totalTaskCount = t
        } else if let tNum = userInfo[Keys.totalTaskCount] as? NSNumber {
            self.totalTaskCount = tNum.intValue
        } else {
            self.totalTaskCount = 0
        }

        if let idStr = userInfo[Keys.assessmentId] as? String, let uuid = UUID(uuidString: idStr) {
            self.assessmentId = uuid
        } else {
            self.assessmentId = nil
        }

        if let timestamp = (userInfo[Keys.dueDate] as? Double) ?? (userInfo[Keys.dueDate] as? NSNumber)?.doubleValue {
            self.dueDate = Date(timeIntervalSince1970: timestamp)
        } else {
            self.dueDate = nil
        }
    }

    public var isFallback: Bool {
        assessmentTitle == "Assessment Reminder" ||
        (subjectCode == "MYUNIDAY" && assessmentTitle == "Academic Assessment")
    }

    public static let placeholder = AssessmentReminderPayload(
        assessmentId: nil,
        assessmentTitle: "Assessment Reminder",
        subjectCode: "MYUNIDAY",
        subjectName: "Academic Overview",
        priority: "High",
        dueDate: nil,
        formattedDueDate: "Due soon",
        progress: 0.0,
        remainingTaskCount: 0,
        totalTaskCount: 0
    )

    /// Preview/Sample payload matching Assignment 2 (COMP2014) for SwiftUI previews and tests.
    public static let previewSample = AssessmentReminderPayload(
        assessmentId: UUID(),
        assessmentTitle: "Assignment 2: Polymorphic System",
        subjectCode: "COMP2014",
        subjectName: "Object Oriented Programming",
        priority: "Critical",
        dueDate: Date().addingTimeInterval(86400),
        formattedDueDate: "Due tomorrow",
        progress: 0.50,
        remainingTaskCount: 3,
        totalTaskCount: 6
    )
}
