//
//  AddClassView.swift
//  MyUniDay
//
//  Creation sheet for scheduling a new class session.
//

import SwiftUI

/// Sheet allowing the student to input and persist a new class session to their timetable.
public struct AddClassView: View {
    @Environment(\.dismiss) private var dismiss

    public let subjects: [UniversitySubject]
    public let onSave: (UUID, ClassType, Date, Date, String, String, String) async throws -> Void
    public let onCreateSubject: ((String, String) async throws -> UniversitySubject)?

    @State private var selectedSubjectId: UUID?
    @State private var classType: ClassType = .workshop
    @State private var classDate: Date = Date()
    @State private var startTime: Date = Date().addingTimeInterval(3600)
    @State private var endTime: Date = Date().addingTimeInterval(7200)
    @State private var campus: String = "City"
    @State private var building: String = ""
    @State private var room: String = ""

    // Quick Subject creation inline
    @State private var isShowingNewSubject: Bool = false
    @State private var newSubjectCode: String = ""
    @State private var newSubjectName: String = ""

    @State private var isSaving: Bool = false
    @State private var validationError: String?

    public init(
        subjects: [UniversitySubject],
        onSave: @escaping (UUID, ClassType, Date, Date, String, String, String) async throws -> Void,
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

                // 2. Class Type & Timing
                Section("Format & Timing") {
                    Picker("Class Type", selection: $classType) {
                        ForEach(ClassType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    DatePicker("Date", selection: $classDate, displayedComponents: .date)

                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                // 3. Location
                Section("Location") {
                    TextField("Campus (e.g. City or Parkville)", text: $campus)
                    TextField("Building (e.g. Building EA)", text: $building)
                    TextField("Room (e.g. Room 15)", text: $room)
                }
            }
            .navigationTitle("New Class")
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

    private func handleCreateSubject() async {
        guard let onCreateSubject = onCreateSubject else { return }
        do {
            let created = try await onCreateSubject(newSubjectCode, newSubjectName)
            selectedSubjectId = created.id
            isShowingNewSubject = false
            newSubjectCode = ""
            newSubjectName = ""
        } catch {
            validationError = (error as? LocalizedError)?.errorDescription ?? "That subject could not be saved. Please check the details and try again."
        }
    }

    private func handleSave() async {
        guard let subjectId = selectedSubjectId else {
            validationError = "Please select or create a subject."
            return
        }

        let trimmedBuilding = building.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBuilding.isEmpty else {
            validationError = "Please enter a building name."
            return
        }

        let trimmedRoom = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoom.isEmpty else {
            validationError = "Please enter a room number."
            return
        }

        let trimmedCampus = campus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCampus.isEmpty else {
            validationError = "Please enter a campus name."
            return
        }

        // Merge date with start/end time components
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: classDate)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        var finalStartComponents = dateComponents
        finalStartComponents.hour = startComponents.hour
        finalStartComponents.minute = startComponents.minute

        var finalEndComponents = dateComponents
        finalEndComponents.hour = endComponents.hour
        finalEndComponents.minute = endComponents.minute

        guard let finalStart = calendar.date(from: finalStartComponents),
              let finalEnd = calendar.date(from: finalEndComponents) else {
            validationError = "Invalid date combination."
            return
        }

        guard finalEnd >= finalStart else {
            validationError = "Class end time cannot be earlier than start time."
            return
        }

        isSaving = true
        validationError = nil

        do {
            try await onSave(
                subjectId,
                classType,
                finalStart,
                finalEnd,
                trimmedCampus,
                trimmedBuilding,
                trimmedRoom
            )
            dismiss()
        } catch {
            validationError = (error as? LocalizedError)?.errorDescription ?? "That class could not be saved. Please check the details and try again."
            isSaving = false
        }
    }
}
