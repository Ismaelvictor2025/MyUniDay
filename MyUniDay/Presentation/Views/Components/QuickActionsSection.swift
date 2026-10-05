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
}

/// Visual row of shortcuts providing quick entry points for student activities.
public struct QuickActionsSection: View {
    public var onSelectAction: ((QuickActionType) -> Void)?
    @State private var fallbackAction: QuickActionType?

    public init(onSelectAction: ((QuickActionType) -> Void)? = nil) {
        self.onSelectAction = onSelectAction
    }

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
    }

    // MARK: - Subviews

    private func quickActionButton(type: QuickActionType) -> some View {
        Button {
            if let onSelectAction = onSelectAction {
                onSelectAction(type)
            } else {
                fallbackAction = type
            }
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
}

#Preview {
    QuickActionsSection()
        .padding()
        .background(Color(.systemGroupedBackground))
}
