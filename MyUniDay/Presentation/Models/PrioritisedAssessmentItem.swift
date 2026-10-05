//
//  PrioritisedAssessmentItem.swift
//  MyUniDay
//
//  Presentation model pairing a Domain Assessment with its calculated AssessmentPriority.
//

import Foundation
import SwiftUI

/// Presentation wrapper pairing an `Assessment` domain model with its computed `AssessmentPriority`.
///
/// Avoids duplicating domain assessment properties while providing the presentation layer
/// with precomputed, UI-ready priority information.
public struct PrioritisedAssessmentItem: Identifiable, Equatable, Hashable, Sendable {
    /// Identifier delegating directly to the underlying assessment ID.
    public var id: UUID { assessment.id }

    /// The underlying domain assessment.
    public let assessment: Assessment

    /// The computed priority tier for this assessment.
    public let priority: AssessmentPriority

    /// Initializes a new prioritised assessment presentation item.
    ///
    /// - Parameters:
    ///   - assessment: The domain assessment model.
    ///   - priority: The computed assessment priority.
    public init(assessment: Assessment, priority: AssessmentPriority) {
        self.assessment = assessment
        self.priority = priority
    }
}

public extension AssessmentPriority {
    var iconName: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "clock.fill"
        case .low: return "checkmark.circle"
        }
    }

    var badgeColor: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}
