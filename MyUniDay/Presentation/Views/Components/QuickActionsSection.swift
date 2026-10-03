//
//  QuickActionsSection.swift
//  MyUniDay
//
//  Interactive quick action shortcuts on the dashboard.
//

import SwiftUI

/// Action type representing a shortcut available on the student dashboard.
public enum QuickActionType: String, Identifiable {
    case addAssessment = "Assessment"
    case addTask = "Task"
    case addClass = "Class"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .addAssessment: return "doc.badge.plus"
        case .addTask: return "checkmark.circle.badge.plus"
        case .addClass: return "calendar.badge.plus"
        }
    }

    public var tintColor: Color {
        switch self {
        case .addAssessment: return .orange
        case .addTask: return .blue
        case .addClass: return .indigo
        }
    }

    public var description: String {
        switch self {
        case .addAssessment:
            return "Quick-creation for new assignments and exams will be available in the dedicated Assessments feature stage."
        case .addTask:
            return "Milestone task creation will be integrated directly into your assessment workflows."
        case .addClass:
            return "Timetable class scheduling workflows will be added in the Timetable feature milestone."
        }
    }
}

/// Visual row of shortcuts providing quick entry points for student activities.
///
/// Clearly communicates that persistence creation workflows belong to subsequent stages.
public struct QuickActionsSection: View {
    @State private var selectedAction: QuickActionType?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(.indigo)
                Text("Quick Actions")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                quickActionButton(type: .addAssessment)
                quickActionButton(type: .addTask)
                quickActionButton(type: .addClass)
            }
        }
        .sheet(item: $selectedAction) { action in
            actionDetailSheet(action: action)
        }
    }

    // MARK: - Subviews

    private func quickActionButton(type: QuickActionType) -> some View {
        Button {
            selectedAction = type
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title3)
                    .foregroundColor(type.tintColor)
                    .frame(width: 44, height: 44)
                    .background(type.tintColor.opacity(0.12))
                    .clipShape(Circle())

                Text("+ \(type.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(type.rawValue)")
    }

    private func actionDetailSheet(action: QuickActionType) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: action.iconName)
                    .font(.system(size: 56))
                    .foregroundColor(action.tintColor)
                    .padding(.top, 24)

                Text("Add \(action.rawValue)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(action.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Stage 4 Focus: Dashboard Presentation", systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("Persistence Creation: Upcoming Milestones", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                Spacer()

                Button("Got it") {
                    selectedAction = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        selectedAction = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    QuickActionsSection()
        .padding()
        .background(Color(.systemGroupedBackground))
}
