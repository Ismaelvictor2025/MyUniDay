//
//  ClassDetailView.swift
//  MyUniDay
//
//  Detail view for a scheduled class session and its preparation checklist.
//

import SwiftUI

/// View displaying complete timetable details for a class session and its preparation requirements.
public struct ClassDetailView: View {
    public let session: ClassSession
    public let subjectName: String?
    public let subjectCode: String?
    public let onTogglePreparationItem: ((PreparationItem) async -> Void)?
    public let onAddPreparationItem: ((String, String?) async throws -> Void)?

    @State private var isShowingAddItem: Bool = false
    @State private var newItemTitle: String = ""
    @State private var newItemNotes: String = ""
    @State private var isAddingItem: Bool = false

    public init(
        session: ClassSession,
        subjectName: String? = nil,
        subjectCode: String? = nil,
        onTogglePreparationItem: ((PreparationItem) async -> Void)? = nil,
        onAddPreparationItem: ((String, String?) async throws -> Void)? = nil
    ) {
        self.session = session
        self.subjectName = subjectName
        self.subjectCode = subjectCode
        self.onTogglePreparationItem = onTogglePreparationItem
        self.onAddPreparationItem = onAddPreparationItem
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                locationCard

                preparationSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.classType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let code = subjectCode {
                    Text(code)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(Capsule())
                }

                if let name = subjectName {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                classTypeBadge
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dayFormatted)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.indigo)
                    Text(timeRangeFormatted)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.indigo)
                Text("Location Details")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BUILDING")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(session.building)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("ROOM")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(session.room)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("CAMPUS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(session.campus)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "backpack")
                        .foregroundColor(.green)
                    Text("Prepare for this class")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Spacer()

                Button {
                    isShowingAddItem.toggle()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isShowingAddItem {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("What to bring (e.g. Laptop & charger)", text: $newItemTitle)
                        .textFieldStyle(.roundedBorder)

                    TextField("Optional notes (e.g. Bring HDMI adapter)", text: $newItemNotes)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Save Item") {
                            Task {
                                await handleAddItem()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingItem)

                        Button("Cancel") {
                            isShowingAddItem = false
                            newItemTitle = ""
                            newItemNotes = ""
                        }
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            if session.preparationItems.isEmpty {
                VStack(spacing: 6) {
                    Text("No preparation items listed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Add materials or readings required before class.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
            } else {
                VStack(spacing: 1) {
                    ForEach(session.preparationItems) { item in
                        prepRow(item: item)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            }
        }
    }

    private func prepRow(item: PreparationItem) -> some View {
        Button {
            Task {
                await onTogglePreparationItem?(item)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isCompleted ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)

                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func handleAddItem() async {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isAddingItem = true
        do {
            let trimmedNotes = newItemNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onAddPreparationItem?(trimmed, trimmedNotes.isEmpty ? nil : trimmedNotes)
            newItemTitle = ""
            newItemNotes = ""
            isShowingAddItem = false
        } catch {
            // Handled
        }
        isAddingItem = false
    }

    // MARK: - Helpers

    private var classTypeBadge: some View {
        Text(session.classType.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundColor(.indigo)
            .background(Color.indigo.opacity(0.12))
            .clipShape(Capsule())
    }

    private var dayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: session.startDate)
    }

    private var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: session.startDate)) – \(formatter.string(from: session.endDate))"
    }
}
