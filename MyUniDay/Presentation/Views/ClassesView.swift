//
//  ClassesView.swift
//  MyUniDay
//
//  Timetable screen grouping scheduled classes by day and providing class creation.
//

import SwiftUI

/// Main Classes screen providing a structured university timetable view.
public struct ClassesView: View {
    @Bindable public var viewModel: ClassesViewModel
    @State private var isShowingAddSheet: Bool = false

    public init(viewModel: ClassesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                    }

                    if viewModel.isLoading && viewModel.classes.isEmpty {
                        loadingSection
                    } else if viewModel.isEmpty {
                        emptySection
                    } else {
                        timetableContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Classes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Class", systemImage: "plus")
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddClassView(
                    subjects: viewModel.subjects,
                    onSave: { subjectId, type, start, end, campus, building, room in
                        try await viewModel.createClass(
                            subjectId: subjectId,
                            classType: type,
                            startDate: start,
                            endDate: end,
                            campus: campus,
                            building: building,
                            room: room
                        )
                    },
                    onCreateSubject: { code, name in
                        try await viewModel.createSubject(code: code, name: name)
                    }
                )
            }
            .refreshable {
                await viewModel.loadClasses()
            }
            .task {
                await viewModel.loadClasses()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Upcoming Timetable")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.primary)

            Text("\(viewModel.classes.count) scheduled sessions")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var timetableContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(viewModel.groupedClasses) { group in
                VStack(alignment: .leading, spacing: 10) {
                    // Day Header
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.indigo)
                        Text(group.dayTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.leading, 4)

                    // Sessions in this day
                    VStack(spacing: 12) {
                        ForEach(group.sessions) { session in
                            NavigationLink {
                                ClassDetailView(
                                    session: session,
                                    subjectName: viewModel.subjectName(for: session.subjectId),
                                    subjectCode: viewModel.subjectCode(for: session.subjectId),
                                    onTogglePreparationItem: { item in
                                        await viewModel.togglePreparationItem(item: item, inSessionId: session.id)
                                    },
                                    onAddPreparationItem: { title, notes in
                                        try await viewModel.addPreparationItem(title: title, notes: notes, toSessionId: session.id)
                                    }
                                )
                            } label: {
                                classCard(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func classCard(session: ClassSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Class Type Badge + Subject
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: iconForClassType(session.classType))
                        .font(.caption2)
                    Text(session.classType.rawValue)
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .foregroundColor(.indigo)
                .background(Color.indigo.opacity(0.12))
                .clipShape(Capsule())

                if let code = viewModel.subjectCode(for: session.subjectId) {
                    Text(code)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                if !session.preparationItems.isEmpty {
                    prepPill(items: session.preparationItems)
                }
            }

            // Time & Location Details
            HStack(spacing: 18) {
                // Time
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.indigo)
                        Text(timeFormatted(start: session.startDate, end: session.endDate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                Divider()
                    .frame(height: 28)

                // Location
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCATION")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.indigo)
                        Text("\(session.building), \(session.room)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private func prepPill(items: [PreparationItem]) -> some View {
        let completed = items.filter { $0.isCompleted }.count
        let isAllDone = completed == items.count
        return HStack(spacing: 4) {
            Image(systemName: isAllDone ? "checkmark.circle.fill" : "checklist")
                .font(.caption2)
            Text("\(completed) of \(items.count) ready")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(isAllDone ? .green : .secondary)
        .background(isAllDone ? Color.green.opacity(0.12) : Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }

    private var emptySection: some View {
        EmptyStateCard(
            iconName: "calendar.badge.clock",
            title: "No upcoming classes",
            subtitle: "Your timetable is currently empty. Tap '+' to schedule your classes."
        )
        .padding(.vertical, 24)
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading timetable…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
            Spacer()
            Button("Retry") {
                Task {
                    await viewModel.loadClasses()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func timeFormatted(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private func iconForClassType(_ type: ClassType) -> String {
        switch type {
        case .lecture: return "person.wave.2.fill"
        case .tutorial: return "bubble.left.and.bubble.right.fill"
        case .lab: return "desktopcomputer"
        case .workshop: return "wrench.and.screwdriver.fill"
        case .seminar: return "text.book.closed.fill"
        case .studio: return "paintbrush.pointed.fill"
        case .other: return "calendar"
        }
    }
}
