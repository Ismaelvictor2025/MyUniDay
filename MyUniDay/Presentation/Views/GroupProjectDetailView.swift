//
//  GroupProjectDetailView.swift
//  MyUniDay
//
//  Detail view for managing a collaborative group project, members, and task assignments.
//

import SwiftUI

public struct GroupProjectDetailView: View {
    @Bindable public var viewModel: GroupWorkViewModel
    public let projectId: UUID
    @Environment(\.dismiss) private var dismiss

    // Project edit & delete states
    @State private var isShowingEditProject = false
    @State private var isShowingDeleteConfirmation = false

    // Member sheet states
    @State private var isShowingAddMember = false
    @State private var newMemberName = ""
    @State private var newMemberRole = ""
    @State private var editingMember: GroupMember?

    // Task sheet states
    @State private var isShowingAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskAssignedMemberId: UUID?
    @State private var hasDueDate = false
    @State private var newTaskDueDate = Date()
    @State private var editingTask: GroupTask?

    public init(viewModel: GroupWorkViewModel, projectId: UUID) {
        self.viewModel = viewModel
        self.projectId = projectId
    }

    private var project: GroupProject? {
        viewModel.projects.first { $0.id == projectId }
    }

    public var body: some View {
        Group {
            if let project = project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard(project: project)
                        membersSection(project: project)
                        tasksSection(project: project)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Project Not Found")
                        .font(.headline)
                    Text("This group project may have been removed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(project?.name ?? "Group Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let project = project {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isShowingEditProject = true
                        } label: {
                            Label("Edit Project", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("Delete Project", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditProject) {
            if let project = project {
                EditGroupProjectView(
                    project: project,
                    subjects: viewModel.subjects,
                    onSave: { name, subjectId, dueDate, myRole in
                        try await viewModel.updateProject(
                            id: project.id,
                            name: name,
                            subjectId: subjectId,
                            dueDate: dueDate,
                            myRole: myRole
                        )
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete \"\(project?.name ?? "Project")\"?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                if let project = project {
                    Task {
                        await viewModel.deleteProject(id: project.id)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this group project and its associated members and tasks.")
        }
        .sheet(isPresented: $isShowingAddMember) {
            addMemberSheet
        }
        .sheet(item: $editingMember) { member in
            editMemberSheet(member: member)
        }
        .sheet(isPresented: $isShowingAddTask) {
            addTaskSheet
        }
        .sheet(item: $editingTask) { task in
            editTaskSheet(task: task)
        }
    }

    // MARK: - Header Card
    private func headerCard(project: GroupProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if let subjectDesc = viewModel.subjectDescription(for: project.subjectId) {
                    Text(subjectDesc)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.pink.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                Text("Role: \(project.myRole)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(project.name)
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.pink)
                Text("Due \(project.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Project Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(project.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width * CGFloat(project.progress), geo.size.width)))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(project.completedTasksCount) of \(project.totalTasksCount) tasks completed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(project.members.count) members")
                        .font(.caption2)
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

    // MARK: - Members Section
    private func membersSection(project: GroupProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Team Members (\(project.members.count))", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    newMemberName = ""
                    newMemberRole = ""
                    isShowingAddMember = true
                } label: {
                    Label("Add Member", systemImage: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if project.members.isEmpty {
                Text("No team members added yet. Tap '+ Add Member' to coordinate your team.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(project.members) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.purple.opacity(0.15))
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if let role = member.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Menu {
                                Button("Edit Member") {
                                    editingMember = member
                                }
                                Button("Remove Member", role: .destructive) {
                                    Task {
                                        try? await viewModel.deleteMember(memberId: member.id, inProjectId: project.id)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Tasks Section
    private func tasksSection(project: GroupProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Group Tasks (\(project.tasks.count))", systemImage: "checklist")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    newTaskTitle = ""
                    newTaskAssignedMemberId = project.members.first?.id
                    hasDueDate = false
                    isShowingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if project.tasks.isEmpty {
                VStack(spacing: 6) {
                    Text("No tasks added yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Break down project deliverables and assign them to members.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(project.tasks) { task in
                        taskRow(task: task, project: project)
                    }
                }
            }
        }
    }

    private func taskRow(task: GroupTask, project: GroupProject) -> some View {
        let assignedMember = project.members.first { $0.id == task.assignedMemberId }

        return HStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.toggleTask(taskId: task.id, inProjectId: project.id)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let member = assignedMember {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(member.name)
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        Text("Unassigned")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let due = task.dueDate {
                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Menu {
                Button("Edit Task") {
                    editingTask = task
                }
                Menu("Assign Member") {
                    Button("Unassigned") {
                        Task {
                            try? await viewModel.updateTask(
                                taskId: task.id,
                                title: task.title,
                                dueDate: task.dueDate,
                                assignedMemberId: nil,
                                inProjectId: project.id
                            )
                        }
                    }
                    ForEach(project.members) { m in
                        Button(m.name) {
                            Task {
                                try? await viewModel.updateTask(
                                    taskId: task.id,
                                    title: task.title,
                                    dueDate: task.dueDate,
                                    assignedMemberId: m.id,
                                    inProjectId: project.id
                                )
                            }
                        }
                    }
                }
                Button("Delete Task", role: .destructive) {
                    Task {
                        try? await viewModel.deleteTask(taskId: task.id, inProjectId: project.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Sheets
    private var addMemberSheet: some View {
        NavigationStack {
            Form {
                Section("Member Info") {
                    TextField("Name (e.g. Vicky)", text: $newMemberName)
                    TextField("Role (e.g. Developer, Research, Presentation)", text: $newMemberRole)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingAddMember = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            guard let pId = project?.id else { return }
                            try? await viewModel.addMember(name: newMemberName, role: newMemberRole, toProjectId: pId)
                            isShowingAddMember = false
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func editMemberSheet(member: GroupMember) -> some View {
        MemberEditorView(member: member) { updatedName, updatedRole in
            guard let pId = project?.id else { return }
            try? await viewModel.updateMember(memberId: member.id, name: updatedName, role: updatedRole, inProjectId: pId)
        }
    }

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task Title") {
                    TextField("Task Title (e.g. Create UI Prototype)", text: $newTaskTitle)
                }

                Section("Assignment") {
                    Picker("Assigned To", selection: $newTaskAssignedMemberId) {
                        Text("None (Unassigned)").tag(Optional<UUID>(nil))
                        if let members = project?.members {
                            ForEach(members) { m in
                                Text(m.name + (m.role != nil ? " (\(m.role!))" : "")).tag(Optional(m.id))
                            }
                        }
                    }
                }

                Section("Deadline") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: $newTaskDueDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Add Group Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingAddTask = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            guard let pId = project?.id else { return }
                            let due = hasDueDate ? newTaskDueDate : nil
                            try? await viewModel.addTask(
                                title: newTaskTitle,
                                dueDate: due,
                                assignedMemberId: newTaskAssignedMemberId,
                                toProjectId: pId
                            )
                            isShowingAddTask = false
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func editTaskSheet(task: GroupTask) -> some View {
        TaskEditorView(task: task, members: project?.members ?? []) { updatedTitle, updatedDue, updatedMemberId in
            guard let pId = project?.id else { return }
            try? await viewModel.updateTask(
                taskId: task.id,
                title: updatedTitle,
                dueDate: updatedDue,
                assignedMemberId: updatedMemberId,
                inProjectId: pId
            )
        }
    }
}

// Helper sheet views
private struct MemberEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let member: GroupMember
    let onSave: (String, String?) async -> Void

    @State private var name: String
    @State private var role: String

    init(member: GroupMember, onSave: @escaping (String, String?) async -> Void) {
        self.member = member
        self.onSave = onSave
        _name = State(initialValue: member.name)
        _role = State(initialValue: member.role ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Member Info") {
                    TextField("Name", text: $name)
                    TextField("Role", text: $role)
                }
            }
            .navigationTitle("Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(name, role.isEmpty ? nil : role)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let task: GroupTask
    let members: [GroupMember]
    let onSave: (String, Date?, UUID?) async -> Void

    @State private var title: String
    @State private var assignedMemberId: UUID?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: GroupTask, members: [GroupMember], onSave: @escaping (String, Date?, UUID?) async -> Void) {
        self.task = task
        self.members = members
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _assignedMemberId = State(initialValue: task.assignedMemberId)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                }

                Section("Assigned Member") {
                    Picker("Assigned To", selection: $assignedMemberId) {
                        Text("None (Unassigned)").tag(Optional<UUID>(nil))
                        ForEach(members) { m in
                            Text(m.name + (m.role != nil ? " (\(m.role!))" : "")).tag(Optional(m.id))
                        }
                    }
                }

                Section("Deadline") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(title, hasDueDate ? dueDate : nil, assignedMemberId)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
