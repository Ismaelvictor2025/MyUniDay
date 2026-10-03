//
//  PreparationChecklistCard.swift
//  MyUniDay
//
//  Presentation card displaying a responsive checklist of preparation items.
//

import SwiftUI

/// Card displaying preparation requirements for the next class.
///
/// Features visual completion progress ("2 of 3 ready"), clear demarcation between
/// completed and pending items, and responsive interaction without false persistence claims.
public struct PreparationChecklistCard: View {
    public let items: [PreparationItem]
    @State private var completedItemIds: Set<UUID>

    public init(items: [PreparationItem]) {
        self.items = items
        // Initialize local state with currently completed items
        let initialCompleted = Set(items.filter { $0.isCompleted }.map { $0.id })
        _completedItemIds = State(initialValue: initialCompleted)
    }

    private var totalCount: Int {
        items.count
    }

    private var completedCount: Int {
        completedItemIds.count
    }

    private var progressFraction: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalCount)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Progress counter & mini bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: completedCount == totalCount ? "checkmark.seal.fill" : "checklist")
                        .font(.caption)
                        .foregroundColor(.green)

                    Text("\(completedCount) of \(totalCount) ready")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Percentage Pill
                Text("\(Int(progressFraction * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.green)
                        .frame(width: max(0, min(geometry.size.width * CGFloat(progressFraction), geometry.size.width)), height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progressFraction)
                }
            }
            .frame(height: 6)

            Divider()

            // Checklist Items
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    let isChecked = completedItemIds.contains(item.id)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isChecked {
                                completedItemIds.remove(item.id)
                            } else {
                                completedItemIds.insert(item.id)
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(isChecked ? .green : .secondary)
                                .padding(.top, 1)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(isChecked ? .regular : .medium)
                                    .foregroundColor(isChecked ? .secondary : .primary)
                                    .strikethrough(isChecked, color: .secondary.opacity(0.6))

                                if let notes = item.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(isChecked ? "Completed" : "Pending"): \(item.title)")

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 32)
                    }
                }
            }
        }
        .padding(18)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [Color.green.opacity(0.04), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1.5)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    PreparationChecklistCard(
        items: [
            PreparationItem(title: "Laptop & charger", notes: "Charged to at least 80%", isCompleted: true),
            PreparationItem(title: "Xcode project cloned", notes: "Branch: main", isCompleted: true),
            PreparationItem(title: "Assignment questions prepared", notes: "Review Section 3 requirements", isCompleted: false)
        ]
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
