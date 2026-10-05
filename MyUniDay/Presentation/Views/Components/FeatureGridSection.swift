//
//  FeatureGridSection.swift
//  MyUniDay
//
//  Polished 4x3 grid of student feature shortcuts with vibrant icons,
//  accessible labels, and interactive touch response.
//

import SwiftUI

/// Feature shortcut destinations available on the Home grid.
public enum HomeFeatureDestination: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Row 1
    case priority = "Priority"
    case assessments = "Assessments"
    case timetable = "Timetable"

    // Row 2
    case tasks = "Tasks"
    case prepare = "Prepare"
    case studyNow = "Study Now"

    // Row 3
    case subjects = "Subjects"
    case groupWork = "Group Work"
    case myProgress = "My Progress"

    // Row 4
    case support = "Support"
    case reminders = "Reminders"
    case more = "More"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .priority: return "flame.fill"
        case .assessments: return "doc.text.fill"
        case .timetable: return "calendar"
        case .tasks: return "checkmark.circle.fill"
        case .prepare: return "backpack.fill"
        case .studyNow: return "brain.head.profile"
        case .subjects: return "book.closed.fill"
        case .groupWork: return "person.2.fill"
        case .myProgress: return "chart.bar.xaxis"
        case .support: return "lifepreserver.fill"
        case .reminders: return "bell.badge.fill"
        case .more: return "gearshape.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .priority: return "Focus Now"
        case .assessments: return "Coursework"
        case .timetable: return "Classes & Labs"
        case .tasks: return "Checklists"
        case .prepare: return "Class Readiness"
        case .studyNow: return "Smart Focus"
        case .subjects: return "Enrolled Units"
        case .groupWork: return "Collaboration"
        case .myProgress: return "Productivity"
        case .support: return "Assistance"
        case .reminders: return "Deadlines"
        case .more: return "Settings & Info"
        }
    }

    public var accentColor: Color {
        switch self {
        case .priority: return .orange
        case .assessments: return .indigo
        case .timetable: return .cyan
        case .tasks: return .green
        case .prepare: return .amber
        case .studyNow: return .purple
        case .subjects: return .blue
        case .groupWork: return .pink
        case .myProgress: return .teal
        case .support: return .red
        case .reminders: return .orange
        case .more: return Color(.systemGray)
        }
    }
}

public struct FeatureGridSection: View {
    public let onSelect: (HomeFeatureDestination) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init(onSelect: @escaping (HomeFeatureDestination) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CAMPUS SERVICES & SHORTCUTS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(HomeFeatureDestination.allCases) { feature in
                    Button {
                        onSelect(feature)
                    } label: {
                        featureCard(feature: feature)
                    }
                    .buttonStyle(FeatureTileButtonStyle())
                    .accessibilityLabel("\(feature.rawValue), \(feature.subtitle)")
                }
            }
        }
    }

    private func featureCard(feature: HomeFeatureDestination) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(feature.accentColor.opacity(0.14))
                    .frame(width: 48, height: 48)

                Image(systemName: feature.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(feature.accentColor)
            }
            .padding(.top, 4)

            VStack(spacing: 2) {
                Text(feature.rawValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(feature.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(feature.accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

/// Custom button style giving natural spring scale press feedback.
private struct FeatureTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
