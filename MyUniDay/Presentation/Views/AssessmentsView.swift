//
//  AssessmentsView.swift
//  MyUniDay
//
//  Assessments list screen featuring priority filtering, progress tracking, and creation workflow.
//

import SwiftUI

/// Main Assessments screen displaying all student assessments categorized by priority.
public struct AssessmentsView: View {
    @Bindable public var viewModel: AssessmentsViewModel
    @State private var isShowingAddSheet: Bool = false

    public init(viewModel: AssessmentsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection

                    filterSection

                    if let error = viewModel.errorMessage {
                        errorBanner(message: error)
                    }

                    if viewModel.isLoading && viewModel.items.isEmpty {
                        loadingSection
                    } else if viewModel.filteredItems.isEmpty {
                        emptySection
                    } else {
                        assessmentList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Assessments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Assessment", systemImage: "plus")
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddAssessmentView(
                    subjects: viewModel.subjects,
                    onSave: { title, subjectId, dueDate, weighting, workload, progress, notes, breakdownSteps in
                        try await viewModel.createAssessment(
                            title: title,
                            subjectId: subjectId,
                            dueDate: dueDate,
                            weighting: weighting,
                            estimatedWorkloadHours: workload,
                            progress: progress,
                            notes: notes,
                            breakdownSteps: breakdownSteps
                        )
                    },
                    onCreateSubject: { code, name in
                        try await viewModel.createSubject(code: code, name: name)
                    }
                )
            }
            .refreshable {
                await viewModel.loadAssessments()
            }
            .task {
                await viewModel.loadAssessments()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assessments & Exams")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.primary)

            Text("\(viewModel.items.count) active assignments and exams")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(title: "All", priority: nil)

                filterPill(title: "Critical", priority: .critical)

                filterPill(title: "High", priority: .high)

                filterPill(title: "Medium", priority: .medium)

                filterPill(title: "Low", priority: .low)
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(title: String, priority: AssessmentPriority?) -> some View {
        let isSelected = viewModel.selectedPriorityFilter == priority
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                viewModel.selectedPriorityFilter = priority
            }
        } label: {
            HStack(spacing: 5) {
                if let priority = priority {
                    Circle()
                        .fill(pillColor(for: priority))
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.indigo : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var assessmentList: some View {
        VStack(spacing: 14) {
            ForEach(viewModel.filteredItems) { item in
                NavigationLink {
                    AssessmentDetailView(
                        item: item,
                        subjectName: viewModel.subjectName(for: item.assessment.subjectId),
                        subjectCode: viewModel.subjectCode(for: item.assessment.subjectId),
                        onToggleTask: { taskId in
                            await viewModel.toggleTask(taskId: taskId, inAssessmentId: item.assessment.id)
                        },
                        onAddTask: { title, due in
                            try await viewModel.addTask(title: title, dueDate: due, toAssessmentId: item.assessment.id)
                        },
                        onDeleteTask: { taskId in
                            await viewModel.deleteTask(taskId: taskId, inAssessmentId: item.assessment.id)
                        },
                        onUpdateTask: { taskId, title in
                            await viewModel.updateTask(taskId: taskId, title: title, inAssessmentId: item.assessment.id)
                        },
                        onUpdateProgress: { newProgress in
                            await viewModel.updateAssessmentProgress(progress: newProgress, forAssessmentId: item.assessment.id)
                        }
                    )
                } label: {
                    assessmentCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func assessmentCard(item: PrioritisedAssessmentItem) -> some View {
        let assessment = item.assessment
        let priority = item.priority

        return VStack(alignment: .leading, spacing: 12) {
            // Header Row: Subject, Priority
            HStack {
                if let code = viewModel.subjectCode(for: assessment.subjectId) {
                    Text(code)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: priority.iconName)
                        .font(.caption2)
                    Text(priority.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundColor(pillColor(for: priority))
                .background(pillColor(for: priority).opacity(0.12))
                .clipShape(Capsule())
            }

            // Title
            Text(assessment.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Due Date & Weighting
            HStack(spacing: 12) {
                Label(dueDateFormatted(assessment.dueDate), systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundColor(priority == .critical ? .red : .secondary)

                if assessment.weighting > 0 {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(Int(assessment.weighting))% weighting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(assessment.progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 6)

                        Capsule()
                            .fill(pillColor(for: priority))
                            .frame(width: max(0, min(geo.size.width * CGFloat(assessment.progress), geo.size.width)), height: 6)
                    }
                }
                .frame(height: 6)
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

    private var emptySection: some View {
        EmptyStateCard(
            iconName: "doc.text.magnifyingglass",
            title: "No assessments found",
            subtitle: viewModel.selectedPriorityFilter == nil
                ? "You have no assessments registered. Tap '+' to create your first assessment."
                : "No assessments match the selected '\(viewModel.selectedPriorityFilter?.rawValue ?? "")' priority filter."
        )
        .padding(.vertical, 24)
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading assessments…")
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
                    await viewModel.loadAssessments()
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

    private func pillColor(for priority: AssessmentPriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .secondary
        }
    }

    private func dueDateFormatted(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days > 1 && days <= 7 {
            return "Due in \(days) days"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Due \(formatter.string(from: date))"
        }
    }
}
