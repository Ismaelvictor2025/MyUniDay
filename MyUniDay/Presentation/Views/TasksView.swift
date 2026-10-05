//
//  TasksView.swift
//  MyUniDay
//
//  Tasks screen displaying actionable university milestones and class preparation items.
//

import SwiftUI

/// Main Tasks screen providing a focused overview of actionable academic work.
public struct TasksView: View {
    @Bindable public var viewModel: TasksViewModel
    @State private var isShowingAddSheet: Bool = false

    public init(viewModel: TasksViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection

                    filterPicker

                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                    }

                    if viewModel.isLoading && viewModel.allTasks.isEmpty {
                        loadingSection
                    } else if viewModel.filteredTasks.isEmpty {
                        emptySection
                    } else {
                        tasksList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddTaskView(
                    assessments: viewModel.availableAssessments,
                    sessions: viewModel.availableSessions,
                    onSaveAssessmentTask: { title, dueDate, assessmentId in
                        try await viewModel.createAssessmentTask(
                            title: title,
                            dueDate: dueDate,
                            assessmentId: assessmentId
                        )
                    },
                    onSavePreparationItem: { title, notes, sessionId in
                        try await viewModel.createPreparationItem(
                            title: title,
                            notes: notes,
                            sessionId: sessionId
                        )
                    }
                )
            }
            .refreshable {
                await viewModel.loadTasks()
            }
            .task {
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Action Items & Preparation")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.primary)

            Text("\(viewModel.pendingCount) pending • \(viewModel.completedCount) completed")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.activeFilter) {
            ForEach(TaskFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var tasksList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.filteredTasks) { task in
                taskCard(task: task)
            }
        }
    }

    private func taskCard(task: UnifiedTaskItem) -> some View {
        Button {
            Task {
                await viewModel.toggleTask(item: task)
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(task.isCompleted ? .regular : .semibold)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted, color: .secondary)

                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        // Context tag
                        HStack(spacing: 4) {
                            Image(systemName: task.source.iconName)
                                .font(.caption2)
                            Text(task.source.title)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundColor(.indigo)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(Capsule())

                        // Due date if present
                        if let due = task.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(dueDateFormatted(due))
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptySection: some View {
        EmptyStateCard(
            iconName: "checkmark.seal",
            title: viewModel.activeFilter == .pending ? "All caught up!" : "No tasks found",
            subtitle: viewModel.activeFilter == .pending
                ? "You have completed all your action items. Tap '+' to create a new task."
                : "No tasks match the '\(viewModel.activeFilter.rawValue)' filter."
        )
        .padding(.vertical, 24)
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading tasks…")
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
                    await viewModel.loadTasks()
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

    private func dueDateFormatted(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}
