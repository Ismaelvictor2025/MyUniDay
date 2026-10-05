//
//  AddTaskView.swift
//  MyUniDay
//
//  Creation sheet for adding an assessment milestone or class preparation requirement.
//

import SwiftUI

/// Mode determining what parent entity the new task belongs to.
public enum TaskTargetType: String, CaseIterable, Identifiable {
    case assessmentTask = "Assessment Milestone"
    case classPreparation = "Class Preparation"

    public var id: String { rawValue }
}

/// Sheet allowing the student to input and persist a new subtask or preparation item.
public struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss

    public let assessments: [Assessment]
    public let sessions: [ClassSession]

    public let onSaveAssessmentTask: (String, Date?, UUID) async throws -> Void
    public let onSavePreparationItem: (String, String?, UUID) async throws -> Void

    @State private var targetType: TaskTargetType
    @State private var selectedAssessmentId: UUID?
    @State private var selectedSessionId: UUID?

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date().addingTimeInterval(86400 * 3)
    @State private var notes: String = ""

    @State private var isSaving: Bool = false
    @State private var validationError: String?

    public init(
        assessments: [Assessment],
        sessions: [ClassSession],
        initialTarget: TaskTargetType = .assessmentTask,
        preselectedAssessmentId: UUID? = nil,
        preselectedSessionId: UUID? = nil,
        onSaveAssessmentTask: @escaping (String, Date?, UUID) async throws -> Void,
        onSavePreparationItem: @escaping (String, String?, UUID) async throws -> Void
    ) {
        self.assessments = assessments
        self.sessions = sessions
        self.onSaveAssessmentTask = onSaveAssessmentTask
        self.onSavePreparationItem = onSavePreparationItem

        _targetType = State(initialValue: initialTarget)
        _selectedAssessmentId = State(initialValue: preselectedAssessmentId ?? assessments.first?.id)
        _selectedSessionId = State(initialValue: preselectedSessionId ?? sessions.first?.id)
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

                // 1. Task Type Selector
                Section {
                    Picker("Task Category", selection: $targetType) {
                        ForEach(TaskTargetType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 2. Parent Association
                if targetType == .assessmentTask {
                    Section("Parent Assessment") {
                        if assessments.isEmpty {
                            Text("No assessments found. Create an assessment first.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Assessment", selection: $selectedAssessmentId) {
                                ForEach(assessments) { assessment in
                                    Text(assessment.title).tag(Optional(assessment.id))
                                }
                            }
                        }
                    }
                } else {
                    Section("Target Class Session") {
                        if sessions.isEmpty {
                            Text("No upcoming classes found. Schedule a class first.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Class", selection: $selectedSessionId) {
                                ForEach(sessions) { session in
                                    Text("\(session.classType.rawValue) - \(session.building) \(session.room)")
                                        .tag(Optional(session.id))
                                }
                            }
                        }
                    }
                }

                // 3. Task Information
                Section("Task Details") {
                    TextField(
                        targetType == .assessmentTask ? "Milestone (e.g. Implement parser)" : "Requirement (e.g. Bring iPad)",
                        text: $title
                    )

                    if targetType == .assessmentTask {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        }
                    } else {
                        TextField("Optional notes (e.g. Fully charged)", text: $notes)
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationError = "Please enter a task title."
            return
        }

        isSaving = true
        validationError = nil

        do {
            if targetType == .assessmentTask {
                guard let assessmentId = selectedAssessmentId else {
                    validationError = "Please select a parent assessment."
                    isSaving = false
                    return
                }
                try await onSaveAssessmentTask(trimmedTitle, hasDueDate ? dueDate : nil, assessmentId)
            } else {
                guard let sessionId = selectedSessionId else {
                    validationError = "Please select a target class session."
                    isSaving = false
                    return
                }
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                try await onSavePreparationItem(trimmedTitle, trimmedNotes.isEmpty ? nil : trimmedNotes, sessionId)
            }
            dismiss()
        } catch {
            validationError = error.localizedDescription
            isSaving = false
        }
    }
}
