//
//  CreateGroupProjectView.swift
//  MyUniDay
//
//  Sheet for creating and initializing a new local group project with members and tasks.
//

import SwiftUI

public struct CreateGroupProjectView: View {
    @Environment(\.dismiss) private var dismiss

    public let subjects: [UniversitySubject]
    public let onSave: (String, UUID?, Date, String, [GroupMember], [GroupTask]) async throws -> Void

    @State private var projectName: String = ""
    @State private var selectedSubjectId: UUID?
    @State private var dueDate: Date = Date().addingTimeInterval(86400 * 14)
    @State private var myRole: String = "Lead"

    // Initial Members
    @State private var members: [GroupMember] = []
    @State private var isAddingMember: Bool = false
    @State private var newMemberName: String = ""
    @State private var newMemberRole: String = ""

    // Initial Tasks
    @State private var tasks: [GroupTask] = []
    @State private var isAddingTask: Bool = false
    @State private var newTaskTitle: String = ""
    @State private var newTaskAssignedMemberId: UUID?

    @State private var isSaving: Bool = false
    @State private var validationError: String?

    public init(
        subjects: [UniversitySubject],
        onSave: @escaping (String, UUID?, Date, String, [GroupMember], [GroupTask]) async throws -> Void
    ) {
        self.subjects = subjects
        self.onSave = onSave
        _selectedSubjectId = State(initialValue: subjects.first?.id)
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let error = validationError {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section("Project Details") {
                    TextField("Project Name (e.g. Mobile App Project)", text: $projectName)

                    if !subjects.isEmpty {
                        Picker("Subject", selection: $selectedSubjectId) {
                            Text("None").tag(Optional<UUID>(nil))
                            ForEach(subjects) { subject in
                                Text("\(subject.code) - \(subject.name)").tag(Optional(subject.id))
                            }
                        }
                    }

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])

                    TextField("My Role (e.g. Lead, Developer, Research)", text: $myRole)
                }

                // MEMBERS
                Section {
                    ForEach(members) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .fontWeight(.medium)
                                if let role = member.role, !role.isEmpty {
                                    Text(role)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                members.removeAll { $0.id == member.id }
                                for (idx, task) in tasks.enumerated() where task.assignedMemberId == member.id {
                                    tasks[idx].assignedMemberId = nil
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isAddingMember {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Member Name (e.g. Vicky)", text: $newMemberName)
                            TextField("Role (e.g. Developer)", text: $newMemberRole)

                            HStack {
                                Button("Add") {
                                    let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        let m = GroupMember(
                                            id: UUID(),
                                            name: trimmed,
                                            role: newMemberRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newMemberRole
                                        )
                                        members.append(m)
                                        newMemberName = ""
                                        newMemberRole = ""
                                        isAddingMember = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Cancel") {
                                    isAddingMember = false
                                    newMemberName = ""
                                    newMemberRole = ""
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            isAddingMember = true
                        } label: {
                            Label("Add Member", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("MEMBERS (\(members.count))")
                }

                // TASKS
                Section {
                    ForEach(tasks) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .fontWeight(.medium)
                                if let assignedId = task.assignedMemberId, let m = members.first(where: { $0.id == assignedId }) {
                                    Text("Assigned to: \(m.name)")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                tasks.removeAll { $0.id == task.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isAddingTask {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Task Title (e.g. Build UI)", text: $newTaskTitle)

                            if !members.isEmpty {
                                Picker("Assigned To", selection: $newTaskAssignedMemberId) {
                                    Text("Unassigned").tag(Optional<UUID>(nil))
                                    ForEach(members) { m in
                                        Text(m.name).tag(Optional(m.id))
                                    }
                                }
                            }

                            HStack {
                                Button("Add") {
                                    let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        let t = GroupTask(
                                            id: UUID(),
                                            title: trimmed,
                                            dueDate: dueDate,
                                            assignedMemberId: newTaskAssignedMemberId,
                                            isCompleted: false,
                                            orderIndex: tasks.count
                                        )
                                        tasks.append(t)
                                        newTaskTitle = ""
                                        newTaskAssignedMemberId = nil
                                        isAddingTask = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Cancel") {
                                    isAddingTask = false
                                    newTaskTitle = ""
                                    newTaskAssignedMemberId = nil
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            isAddingTask = true
                        } label: {
                            Label("Add Task", systemImage: "plus")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("TASKS (\(tasks.count))")
                }
            }
            .navigationTitle("New Group Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Project") {
                        Task {
                            await handleSave()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func handleSave() async {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationError = "Please enter a project name."
            return
        }

        isSaving = true
        validationError = nil

        do {
            try await onSave(
                trimmed,
                selectedSubjectId,
                dueDate,
                myRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Lead" : myRole,
                members,
                tasks
            )
            dismiss()
        } catch {
            validationError = error.localizedDescription
            isSaving = false
        }
    }
}
