//
//  FocusNowHeroCard.swift
//  MyUniDay
//
//  Prominent hero card showcasing the student's highest priority assessment.
//

import SwiftUI

/// Prominent hero card for the highest-priority academic task.
///
/// Designed to immediately answer "What should I prioritise?" with strong visual hierarchy,
/// progress visualization, and accessible urgency indicators that do not rely on color alone.
public struct FocusNowHeroCard: View {
    public let item: PrioritisedAssessmentItem
    public let subjectCode: String?

    public init(item: PrioritisedAssessmentItem, subjectCode: String? = nil) {
        self.item = item
        self.subjectCode = subjectCode
    }

    private var assessment: Assessment {
        item.assessment
    }

    private var priority: AssessmentPriority {
        item.priority
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Row: Focus Tag & Priority Pill
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("FOCUS NOW")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .tracking(0.5)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .foregroundColor(.white)
                .background(Color.orange)
                .clipShape(Capsule())

                if let code = subjectCode, !code.isEmpty {
                    Text(code)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }

                Spacer()

                priorityBadge
            }

            // Title & Due Date
            VStack(alignment: .leading, spacing: 6) {
                Text(assessment.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(dueDateFormatted, systemImage: "clock.badge.exclamationmark")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(urgencyColor)

                    if assessment.weighting > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(Int(assessment.weighting))% weighting")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Progress Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Current Progress")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(assessment.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [progressTint.opacity(0.8), progressTint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geometry.size.width * CGFloat(assessment.progress), geometry.size.width)), height: 10)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(18)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [Color.orange.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1.5)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus item: \(assessment.title), Priority \(priority.rawValue), \(dueDateFormatted), \(Int(assessment.weighting)) percent weighting, progress \(Int(assessment.progress * 100)) percent")
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
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundColor(badgeForegroundColor)
        .background(badgeBackgroundColor)
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var priorityIcon: String {
        switch priority {
        case .critical: return "exclamationmark.octagon.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "clock.fill"
        case .low: return "checkmark.circle"
        }
    }

    private var badgeForegroundColor: Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .secondary
        }
    }

    private var badgeBackgroundColor: Color {
        switch priority {
        case .critical: return Color.red.opacity(0.12)
        case .high: return Color.orange.opacity(0.12)
        case .medium: return Color.blue.opacity(0.12)
        case .low: return Color(.tertiarySystemFill)
        }
    }

    private var progressTint: Color {
        switch priority {
        case .critical: return .orange
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }

    private var urgencyColor: Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        default: return .primary
        }
    }

    private var dueDateFormatted: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: assessment.dueDate).day ?? 0
        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days > 1 && days <= 7 {
            return "Due in \(days) days"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Due \(formatter.string(from: assessment.dueDate))"
        }
    }
}

#Preview {
    FocusNowHeroCard(
        item: PrioritisedAssessmentItem(
            assessment: Assessment(
                title: "Assignment 2: Polymorphic System",
                dueDate: Date().addingTimeInterval(86400 * 2),
                weighting: 35.0,
                estimatedWorkloadHours: 18.0,
                progress: 0.65,
                isCompleted: false
            ),
            priority: .critical
        ),
        subjectCode: "COMP2014"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
