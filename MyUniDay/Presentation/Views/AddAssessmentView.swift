//
//  AddAssessmentView.swift
//  MyUniDay
//
//  Creation sheet for adding a new assessment with optional breakdown milestones.
//

import SwiftUI

/// Sheet allowing the student to input and persist a new academic assessment with breakdown tasks.
public struct AddAssessmentView: View {
    @Environment(\.dismiss) private var dismiss

    public let subjects: [UniversitySubject]
    public let onSave: (String, UUID, Date, Double, Double, Double, String?, [String]) async throws -> Void
    public let onCreateSubject: ((String, String) async throws -> UniversitySubject)?

    @State private var selectedSubjectId: UUID?
    @State private var title: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(86400 * 7)
    @State private var weighting: Double = 20.0
    @State private var estimatedWorkload: Double = 10.0
    @State private var fallbackProgress: Double = 0.0
    @State private var notes: String = ""

    // Breakdown Steps
    @State private var breakdownSteps: [String] = []
    @State private var isAddingStep: Bool = false
    @State private var newStepTitle: String = ""

    // Quick Subject creation inline
    @State private var isShowingNewSubject: Bool = false
    @State private var newSubjectCode: String = ""
    @State private var newSubjectName: String = ""

    @State private var isSaving: Bool = false
    @State private var validationError: String?

    public init(
        subjects: [UniversitySubject],
        onSave: @escaping (String, UUID, Date, Double, Double, Double, String?, [String]) async throws -> Void,
        onCreateSubject: ((String, String) async throws -> UniversitySubject)? = nil
    ) {
        self.subjects = subjects
        self.onSave = onSave
        self.onCreateSubject = onCreateSubject
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

                // 1. Subject Selection
                Section("Subject") {
                    if subjects.isEmpty && !isShowingNewSubject {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No subjects found. Add a subject first.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("+ Add Subject") {
                                isShowingNewSubject = true
                            }
                            .font(.subheadline)
                        }
                    } else if !isShowingNewSubject {
                        Picker("Select Subject", selection: $selectedSubjectId) {
                            ForEach(subjects) { subject in
                                Text("\(subject.code) - \(subject.name)").tag(Optional(subject.id))
                            }
                        }

                        Button("+ Add Another Subject") {
                            isShowingNewSubject = true
                        }
                        .font(.caption)
                    }

                    if isShowingNewSubject {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Subject Code (e.g. COMP2014)", text: $newSubjectCode)
                                .textInputAutocapitalization(.characters)
                            TextField("Subject Name (e.g. Object Oriented Programming)", text: $newSubjectName)

                            HStack {
                                Button("Create Subject") {
                                    Task {
                                        await handleCreateSubject()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newSubjectCode.isEmpty || newSubjectName.isEmpty)

                                Button("Cancel") {
                                    isShowingNewSubject = false
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 2. Assessment Details
                Section("Assessment Information") {
                    TextField("Title (e.g. Assignment 2)", text: $title)

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }

                // 3. Academic Metrics
                Section("Academic Weighting & Effort") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Weighting")
                            Spacer()
                            Text("\(Int(weighting))%")
                                .fontWeight(.bold)
                                .foregroundColor(.indigo)
                        }
                        Slider(value: $weighting, in: 0...100, step: 1)
                    }

                    Stepper("Estimated Workload: \(Int(estimatedWorkload)) hrs", value: $estimatedWorkload, in: 0...100, step: 1)

                    if breakdownSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Current Progress (Manual Fallback)")
                                Spacer()
                                Text("\(Int(fallbackProgress * 100))%")
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            Slider(value: $fallbackProgress, in: 0...1.0, step: 0.05)
                        }
                    } else {
                        HStack {
                            Text("Calculated Progress")
                            Spacer()
                            Text("0% (0 of \(breakdownSteps.count) completed)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 4. BREAK DOWN THIS ASSESSMENT
                Section {
                    ForEach(breakdownSteps.indices, id: \.self) { idx in
                        HStack {
                            Image(systemName: "square")
                                .foregroundColor(.secondary)
                            Text(breakdownSteps[idx])
                                .font(.subheadline)
                            Spacer()
                            Button(role: .destructive) {
                                breakdownSteps.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isAddingStep {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Step title (e.g. Research)", text: $newStepTitle)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Button("Add Step") {
                                    let trimmed = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        breakdownSteps.append(trimmed)
                                        newStepTitle = ""
                                        isAddingStep = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Cancel") {
                                    isAddingStep = false
                                    newStepTitle = ""
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            isAddingStep = true
                        } label: {
                            Label("Add Step", systemImage: "plus")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    // Suggested standard steps
                    if breakdownSteps.isEmpty && !isAddingStep {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("QUICK SUGGESTIONS")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    suggestionPill("Research")
                                    suggestionPill("Plan structure")
                                    suggestionPill("Development")
                                    suggestionPill("Testing")
                                    suggestionPill("Final report")
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("BREAK DOWN THIS ASSESSMENT (\(breakdownSteps.count))")
                } footer: {
                    Text("Breakdown tasks automatically calculate assessment progress and feed into your Study Now recommendations.")
                        .font(.caption2)
                }

                // 5. Notes
                Section("Notes / Instructions") {
                    TextField("Optional criteria, rubric notes, or links", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Assessment")
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

    private func suggestionPill(_ title: String) -> some View {
        Button {
            if !breakdownSteps.contains(title) {
                breakdownSteps.append(title)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill))
            .foregroundColor(.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func handleCreateSubject() async {
        guard let onCreateSubject = onCreateSubject else { return }
        do {
            let created = try await onCreateSubject(newSubjectCode, newSubjectName)
            selectedSubjectId = created.id
            isShowingNewSubject = false
            newSubjectCode = ""
            newSubjectName = ""
        } catch {
            validationError = "Failed to create subject: \(error.localizedDescription)"
        }
    }

    private func handleSave() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationError = "Please enter an assessment title."
            return
        }

        guard let subjectId = selectedSubjectId else {
            validationError = "Please select or create a subject."
            return
        }

        isSaving = true
        validationError = nil

        do {
            try await onSave(
                trimmedTitle,
                subjectId,
                dueDate,
                weighting,
                estimatedWorkload,
                fallbackProgress,
                notes.isEmpty ? nil : notes,
                breakdownSteps
            )
            dismiss()
        } catch {
            validationError = error.localizedDescription
            isSaving = false
        }
    }
}
