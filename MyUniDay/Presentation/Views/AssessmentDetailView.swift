//
//  AssessmentDetailView.swift
//  MyUniDay
//
//  Detail view for viewing and managing an assessment, its subtask checklist,
//  and real-time priority & progress calculations.
//

import SwiftUI

/// Comprehensive management screen detailing an assessment's academic metrics and actionable milestones.
public struct AssessmentDetailView: View {
    public let item: PrioritisedAssessmentItem
    public let subjectName: String?
    public let subjectCode: String?
    public let onToggleTask: ((UUID) async -> Void)?
    public let onAddTask: ((String, Date?) async throws -> Void)?
    public let onDeleteTask: ((UUID) async -> Void)?
    public let onUpdateTask: ((UUID, String) async -> Void)?
    public let onUpdateProgress: ((Double) async -> Void)?

    @State private var currentAssessment: Assessment
    @State private var currentPriority: AssessmentPriority

    @State private var isShowingAddTask: Bool = false
    @State private var newTaskTitle: String = ""
    @State private var newTaskDueDate: Date = Date()
    @State private var hasTaskDueDate: Bool = false
    @State private var isAddingTask: Bool = false

    // Manual progress fallback state (Section 5)
    @State private var isShowingUpdateProgress: Bool = false
    @State private var manualProgressPercentage: Double = 0.0

    // Edit and delete task state
    @State private var editingTask: AssessmentTask?
    @State private var editTaskTitle: String = ""
    @State private var taskPendingDeletion: AssessmentTask?

    private let priorityCalculator = CalculateAssessmentPriorityUseCase()

    public init(
        item: PrioritisedAssessmentItem,
        subjectName: String? = nil,
        subjectCode: String? = nil,
        onToggleTask: ((UUID) async -> Void)? = nil,
        onAddTask: ((String, Date?) async throws -> Void)? = nil,
        onDeleteTask: ((UUID) async -> Void)? = nil,
        onUpdateTask: ((UUID, String) async -> Void)? = nil,
        onUpdateProgress: ((Double) async -> Void)? = nil
    ) {
        self.item = item
        self.subjectName = subjectName
        self.subjectCode = subjectCode
        self.onToggleTask = onToggleTask
        self.onAddTask = onAddTask
        self.onDeleteTask = onDeleteTask
        self.onUpdateTask = onUpdateTask
        self.onUpdateProgress = onUpdateProgress

        _currentAssessment = State(initialValue: item.assessment)
        _currentPriority = State(initialValue: item.priority)
        _manualProgressPercentage = State(initialValue: round(item.assessment.progress * 100))
    }

    private var completedTasksCount: Int {
        currentAssessment.tasks.filter { $0.isCompleted }.count
    }

    private var totalTasksCount: Int {
        currentAssessment.tasks.count
    }

    private var dueDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: currentAssessment.dueDate)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                metricsGrid

                if let notes = currentAssessment.notes, !notes.isEmpty {
                    notesCard(notes: notes)
                }

                tasksSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(currentAssessment.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item) { _, newItem in
            currentAssessment = newItem.assessment
            currentPriority = newItem.priority
        }
        .sheet(item: $editingTask) { task in
            editTaskSheet(task: task)
        }
        .sheet(isPresented: $isShowingUpdateProgress) {
            updateProgressSheet
        }
        .alert(
            "Delete Milestone?",
            isPresented: Binding(
                get: { taskPendingDeletion != nil },
                set: { if !$0 { taskPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let task = taskPendingDeletion {
                    taskPendingDeletion = nil
                    handleDeleteTask(taskId: task.id)
                }
            }
            Button("Cancel", role: .cancel) {
                taskPendingDeletion = nil
            }
        } message: {
            Text("Are you sure you want to delete '\(taskPendingDeletion?.title ?? "")'? Assessment progress will be recalculated immediately.")
        }
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

                priorityBadge
            }

            Text(currentAssessment.title)
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(currentPriority == .critical ? .red : .indigo)
                Text("Due \(dueDateFormatted)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            // Progress Bar & Manual Fallback (Section 5)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(round(currentAssessment.progress * 100)))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 8)

                        Capsule()
                            .fill(currentPriority == .critical ? Color.orange : Color.indigo)
                            .frame(width: max(0, min(geo.size.width * CGFloat(currentAssessment.progress), geo.size.width)), height: 8)
                    }
                }
                .frame(height: 8)

                if currentAssessment.tasks.isEmpty {
                    HStack {
                        Button {
                            manualProgressPercentage = round(currentAssessment.progress * 100)
                            isShowingUpdateProgress = true
                        } label: {
                            Label("Update Progress", systemImage: "slider.horizontal.3")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()
                    }
                    .padding(.top, 4)
                } else {
                    Text("Progress is calculated automatically from your completed tasks.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
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

    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: currentPriority.iconName)
            Text(currentPriority.rawValue.uppercased())
        }
        .font(.caption2)
        .fontWeight(.heavy)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(currentPriority.badgeColor.opacity(0.15))
        .foregroundColor(currentPriority.badgeColor)
        .clipShape(Capsule())
    }

    private var metricsGrid: some View {
        HStack(spacing: 12) {
            metricTile(
                title: "Weighting",
                value: "\(Int(currentAssessment.weighting))%",
                icon: "percent",
                color: .orange
            )

            metricTile(
                title: "Workload",
                value: "\(Int(currentAssessment.estimatedWorkloadHours)) hrs",
                icon: "clock.fill",
                color: .blue
            )

            metricTile(
                title: "Milestones",
                value: "\(completedTasksCount) of \(totalTasksCount)",
                icon: "checklist",
                color: .green
            )
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                Text("Instructions & Notes")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            Text(notes)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .foregroundColor(.indigo)
                    Text("Milestones & Tasks")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Spacer()

                Button {
                    isShowingAddTask.toggle()
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isShowingAddTask {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("New milestone title", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Set milestone deadline", isOn: $hasTaskDueDate)
                        .font(.caption)

                    if hasTaskDueDate {
                        DatePicker("Milestone Date", selection: $newTaskDueDate, displayedComponents: [.date])
                            .font(.caption)
                    }

                    HStack {
                        Button("Save") {
                            Task {
                                await handleAddTask()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingTask)

                        Button("Cancel") {
                            isShowingAddTask = false
                            newTaskTitle = ""
                            hasTaskDueDate = false
                        }
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            if currentAssessment.tasks.isEmpty {
                VStack(spacing: 8) {
                    Text("No subtasks added yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Break this assessment down into manageable steps.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
            } else {
                VStack(spacing: 1) {
                    ForEach(currentAssessment.tasks) { task in
                        taskRow(task: task)
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

    private func taskRow(task: AssessmentTask) -> some View {
        HStack(spacing: 12) {
            Button {
                handleToggleTask(taskId: task.id)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                if let due = task.dueDate {
                    Text("Target: \(taskDateFormatted(due))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Menu {
                Button("Edit Task") {
                    editTaskTitle = task.title
                    editingTask = task
                }

                Button("Delete Task", role: .destructive) {
                    taskPendingDeletion = task
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .padding(14)
    }

    private func taskDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Actions with Immediate Local Update + Persistence

    private func handleToggleTask(taskId: UUID) {
        guard let idx = currentAssessment.tasks.firstIndex(where: { $0.id == taskId }) else { return }

        // 1. Immediate UI update
        currentAssessment.tasks[idx].isCompleted.toggle()
        AssessmentProgressCalculator.synchronize(&currentAssessment)
        currentPriority = priorityCalculator.execute(for: currentAssessment, relativeTo: Date())

        // 2. Persist in background
        Task {
            await onToggleTask?(taskId)
        }
    }

    private func handleAddTask() async {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isAddingTask = true
        let targetDue = hasTaskDueDate ? newTaskDueDate : nil

        let newTask = AssessmentTask(
            id: UUID(),
            assessmentId: currentAssessment.id,
            title: trimmed,
            isCompleted: false,
            dueDate: targetDue,
            orderIndex: currentAssessment.tasks.count
        )

        // 1. Immediate UI update
        currentAssessment.tasks.append(newTask)
        AssessmentProgressCalculator.synchronize(&currentAssessment)
        currentPriority = priorityCalculator.execute(for: currentAssessment, relativeTo: Date())

        newTaskTitle = ""
        isShowingAddTask = false
        hasTaskDueDate = false

        // 2. Persist
        do {
            try await onAddTask?(trimmed, targetDue)
        } catch {
            // Revert on error if needed
        }
        isAddingTask = false
    }

    private func handleDeleteTask(taskId: UUID) {
        // 1. Immediate UI update
        currentAssessment.tasks.removeAll { $0.id == taskId }
        for (idx, _) in currentAssessment.tasks.enumerated() {
            currentAssessment.tasks[idx].orderIndex = idx
        }
        AssessmentProgressCalculator.synchronize(&currentAssessment)
        currentPriority = priorityCalculator.execute(for: currentAssessment, relativeTo: Date())

        // 2. Persist
        Task {
            await onDeleteTask?(taskId)
        }
    }

    private func editTaskSheet(task: AssessmentTask) -> some View {
        NavigationStack {
            Form {
                Section("Milestone Title") {
                    TextField("Title", text: $editTaskTitle)
                }
            }
            .navigationTitle("Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingTask = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = editTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty, let idx = currentAssessment.tasks.firstIndex(where: { $0.id == task.id }) {
                            currentAssessment.tasks[idx].title = trimmed
                            let taskId = task.id
                            editingTask = nil
                            Task {
                                await onUpdateTask?(taskId, trimmed)
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(editTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Manual Progress Fallback Sheet (Section 5)
    private var updateProgressSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("CURRENT PROGRESS")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.indigo)
                        .tracking(1.2)

                    Text("\(Int(manualProgressPercentage))%")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    Slider(value: $manualProgressPercentage, in: 0...100, step: 5)
                        .tint(.indigo)

                    HStack {
                        Text("0%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("50%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 8) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { preset in
                        Button("\(preset)%") {
                            manualProgressPercentage = Double(preset)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Spacer()

                Button("Save Progress") {
                    let newProgress = manualProgressPercentage / 100.0
                    currentAssessment.progress = newProgress
                    currentAssessment.isCompleted = newProgress >= 0.999
                    currentPriority = priorityCalculator.execute(for: currentAssessment, relativeTo: Date())
                    isShowingUpdateProgress = false
                    Task {
                        await onUpdateProgress?(newProgress)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isShowingUpdateProgress = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
