//
//  AssessmentPriority.swift
//  MyUniDay
//
//  Domain model representing the calculated urgency level of an assessment.
//

import Foundation

/// Represents the calculated urgency and priority classification of an academic assessment.
public enum AssessmentPriority: String, CaseIterable, Comparable, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    /// Internal ranking value for comparative ordering (critical > high > medium > low).
    private var rank: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    public static func < (lhs: AssessmentPriority, rhs: AssessmentPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}
