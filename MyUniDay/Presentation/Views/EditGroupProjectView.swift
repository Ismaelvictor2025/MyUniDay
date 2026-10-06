//
//  EditGroupProjectView.swift
//  MyUniDay
//
//  Sheet for editing the metadata of an existing group project.
//

import SwiftUI

public struct EditGroupProjectView: View {
    @Environment(\.dismiss) private var dismiss

    public let project: GroupProject
    public let subjects: [UniversitySubject]
    public let onSave: (String, UUID?, Date, String) async throws -> Void

    @State private var projectName: String
    @State private var selectedSubjectId: UUID?
    @State private var dueDate: Date
    @State private var myRole: String

    @State private var isSaving: Bool = false
    @State private var validationError: String?

    public init(
        project: GroupProject,
        subjects: [UniversitySubject],
        onSave: @escaping (String, UUID?, Date, String) async throws -> Void
    ) {
        self.project = project
        self.subjects = subjects
        self.onSave = onSave

        _projectName = State(initialValue: project.name)
        _selectedSubjectId = State(initialValue: project.subjectId)
        _dueDate = State(initialValue: project.dueDate)
        _myRole = State(initialValue: project.myRole)
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
                    TextField("Project Name", text: $projectName)

                    if !subjects.isEmpty {
                        Picker("Subject", selection: $selectedSubjectId) {
                            Text("None").tag(Optional<UUID>(nil))
                            ForEach(subjects) { subject in
                                Text("\(subject.code) — \(subject.name)").tag(Optional(subject.id))
                            }
                        }
                    }

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])

                    TextField("My Role (e.g. Lead, Developer, Research)", text: $myRole)
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.pink)
                        Text("Existing members (\(project.members.count)) and tasks (\(project.tasks.count)) will be preserved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(isSaving || projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving changes...")
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func save() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = "Project name cannot be empty."
            return
        }

        isSaving = true
        validationError = nil

        Task {
            do {
                try await onSave(trimmedName, selectedSubjectId, dueDate, myRole)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                validationError = (error as? LocalizedError)?.errorDescription ?? "Your changes could not be saved. Please check the details and try again."
            }
        }
    }
}
