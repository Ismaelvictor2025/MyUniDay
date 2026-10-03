//
//  EmptyStateCard.swift
//  MyUniDay
//
//  Clean, friendly placeholder card for sections without scheduled items.
//

import SwiftUI

/// Reusable card displaying a calm, student-friendly empty state for dashboard sections.
public struct EmptyStateCard: View {
    public let iconName: String
    public let title: String
    public let subtitle: String

    public init(
        iconName: String = "calendar.badge.clock",
        title: String,
        subtitle: String
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        EmptyStateCard(
            iconName: "checkmark.seal",
            title: "All caught up",
            subtitle: "No incomplete assessments due soon."
        )
        EmptyStateCard(
            iconName: "building.2",
            title: "No more classes scheduled",
            subtitle: "You're done for the day."
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
