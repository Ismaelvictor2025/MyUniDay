//
//  AssessmentPriorityCard.swift
//  MyUniDay
//
//  Presentation card displaying an assessment with its precomputed priority tier.
//

import SwiftUI

/// Card displaying an assessment's details, progress, and urgency classification.
///
/// Communicates priority through both text badges and symbols, adhering to accessibility standards
/// by never conveying urgency through color alone.
public struct AssessmentPriorityCard: View {
    public let item: PrioritisedAssessmentItem

    public init(item: PrioritisedAssessmentItem) {
        self.item = item
    }

    private var assessment: Assessment {
        item.assessment
    }

    private var priority: AssessmentPriority {
        item.priority
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title and Priority Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assessment.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(dueDateFormatted, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if assessment.weighting > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(Int(assessment.weighting))% weighting")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                priorityBadge
            }

            // Progress Section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(assessment.progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: min(1.0, max(0.0, assessment.progress)))
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assessment.title), Priority: \(priority.rawValue), \(dueDateFormatted), \(Int(assessment.weighting)) percent weighting, Progress \(Int(assessment.progress * 100)) percent")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon)
                .font(.caption2)
            Text(priority.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(badgeForegroundColor)
        .background(badgeBackgroundColor)
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var priorityIcon: String {
        switch priority {
        case .critical:
            return "exclamationmark.octagon.fill"
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "clock.fill"
        case .low:
            return "checkmark.circle"
        }
    }

    private var badgeForegroundColor: Color {
        switch priority {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .blue
        case .low:
            return .secondary
        }
    }

    private var badgeBackgroundColor: Color {
        switch priority {
        case .critical:
            return Color.red.opacity(0.12)
        case .high:
            return Color.orange.opacity(0.12)
        case .medium:
            return Color.blue.opacity(0.12)
        case .low:
            return Color(.tertiarySystemFill)
        }
    }

    private var progressTint: Color {
        switch priority {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .blue
        case .low:
            return .secondary
        }
    }

    private var dueDateFormatted: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(assessment.dueDate) {
            formatter.dateFormat = "'Today,' h:mm a"
        } else if calendar.isDateInTomorrow(assessment.dueDate) {
            formatter.dateFormat = "'Tomorrow,' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return "Due \(formatter.string(from: assessment.dueDate))"
    }
}

#Preview {
    VStack(spacing: 12) {
        AssessmentPriorityCard(
            item: PrioritisedAssessmentItem(
                assessment: Assessment(
                    title: "Mobile Architecture Milestone",
                    dueDate: Date().addingTimeInterval(86400 * 2),
                    weighting: 35.0,
                    estimatedWorkloadHours: 20.0,
                    progress: 0.2,
                    isCompleted: false
                ),
                priority: .critical
            )
        )
        AssessmentPriorityCard(
            item: PrioritisedAssessmentItem(
                assessment: Assessment(
                    title: "Weekly Quiz 4",
                    dueDate: Date().addingTimeInterval(86400 * 6),
                    weighting: 5.0,
                    estimatedWorkloadHours: 2.0,
                    progress: 0.6,
                    isCompleted: false
                ),
                priority: .medium
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
