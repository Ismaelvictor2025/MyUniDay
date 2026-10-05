//
//  SubjectsView.swift
//  MyUniDay
//
//  Displays enrolled university subjects with coursework and schedule summaries.
//

import SwiftUI

public struct SubjectsView: View {
    public var container: AppDependencyContainer

    @State private var subjects: [UniversitySubject] = []
    @State private var assessments: [Assessment] = []
    @State private var classes: [ClassSession] = []
    @State private var isLoading: Bool = false
    @State private var showAddSubjectSheet: Bool = false

    // New subject form state
    @State private var newCode: String = ""
    @State private var newName: String = ""
    @State private var newColorHex: String = "#3F51B5"
    @State private var formError: String?

    public init(container: AppDependencyContainer) {
        self.container = container
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ENROLLED SUBJECTS")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.blue)
                            .tracking(1.2)
                        Text("Your academic units & coursework commitments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                if isLoading {
                    ProgressView("Loading subjects...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if subjects.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        ForEach(subjects) { subject in
                            subjectCard(subject: subject)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Subjects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSubjectSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showAddSubjectSheet) {
            addSubjectSheet
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            async let subjs = container.getSubjectsUseCase.execute()
            async let assts = container.assessmentRepository.fetchAllAssessments()
            async let cls = container.classSessionRepository.fetchAllClassSessions()

            let (s, a, c) = try await (subjs, assts, cls)
            self.subjects = s
            self.assessments = a
            self.classes = c
        } catch {
            // gracefully handled
        }
        isLoading = false
    }

    private func subjectCard(subject: UniversitySubject) -> some View {
        let subjectAssessments = assessments.filter { $0.subjectId == subject.id }
        let subjectClasses = classes.filter { $0.subjectId == subject.id }
        let incompleteAssessments = subjectAssessments.filter { !$0.isCompleted }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(subject.code)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("\(subjectClasses.count) sessions")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text(subject.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Divider()

            HStack(spacing: 16) {
                Label("\(subjectAssessments.count) Assessments", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !incompleteAssessments.isEmpty {
                    Label("\(incompleteAssessments.count) Pending", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Label("Up to date", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .padding(.top, 20)

            Text("No Subjects Enrolled")
                .font(.headline)

            Text("Add your subjects to organise coursework, timetables, and assessments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button("Add First Subject") {
                showAddSubjectSheet = true
            }
            .fontWeight(.semibold)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var addSubjectSheet: some View {
        NavigationStack {
            Form {
                Section("Subject Details") {
                    TextField("Code (e.g. COMP2014)", text: $newCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                    TextField("Name (e.g. Object Oriented Programming)", text: $newName)
                }

                if let err = formError {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddSubjectSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let trimmedCode = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedCode.isEmpty, !trimmedName.isEmpty else {
                                formError = "Please enter both subject code and name."
                                return
                            }
                            do {
                                let newSubject = UniversitySubject(
                                    code: trimmedCode,
                                    name: trimmedName,
                                    colorHex: newColorHex
                                )
                                try await container.createSubjectUseCase.execute(subject: newSubject)
                                newCode = ""
                                newName = ""
                                formError = nil
                                showAddSubjectSheet = false
                                await loadData()
                            } catch {
                                formError = "Unable to save subject."
                            }
                        }
                    }
                    .disabled(newCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
