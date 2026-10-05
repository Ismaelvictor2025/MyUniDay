//
//  PriorityAssessmentsView.swift
//  MyUniDay
//
//  Dedicated screen displaying the student's prioritised assessments and "Focus Now" recommendations.
//

import SwiftUI

public struct PriorityAssessmentsView: View {
    @Bindable public var viewModel: AssessmentsViewModel
    @State private var selectedItem: PrioritisedAssessmentItem?

    public init(viewModel: AssessmentsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACADEMIC PRIORITIES")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.orange)
                            .tracking(1.2)
                        Text("Ranked by due date, weighting & workload")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Priority Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterPill(title: "All", priority: nil)
                        filterPill(title: "Critical", priority: .critical)
                        filterPill(title: "High", priority: .high)
                        filterPill(title: "Medium", priority: .medium)
                        filterPill(title: "Low", priority: .low)
                    }
                    .padding(.horizontal, 4)
                }

                if viewModel.isLoading {
                    ProgressView("Updating priorities...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.filteredItems.isEmpty {
                    emptyState
                } else {
                    // Focus Now Hero Card if available
                    if viewModel.selectedPriorityFilter == nil, let hero = viewModel.filteredItems.first {
                        focusNowHero(item: hero)
                    }

                    // Assessment list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALL PRIORITISED ITEMS (\(viewModel.filteredItems.count))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        ForEach(viewModel.filteredItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                priorityCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Priority")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAssessments()
        }
        .navigationDestination(item: $selectedItem) { item in
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
                }
            )
        }
    }

    private func filterPill(title: String, priority: AssessmentPriority?) -> some View {
        let isSelected = viewModel.selectedPriorityFilter == priority
        return Button {
            viewModel.selectedPriorityFilter = priority
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color(.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private func focusNowHero(item: PrioritisedAssessmentItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("FOCUS NOW")
                }
                .font(.caption2)
                .fontWeight(.heavy)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.25))
                .clipShape(Capsule())
                .foregroundColor(.white)

                Spacer()

                Text(item.priority.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let code = viewModel.subjectCode(for: item.assessment.subjectId) {
                    let name = viewModel.subjectName(for: item.assessment.subjectId) ?? ""
                    Text(code + (name.isEmpty ? "" : " • \(name)"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(item.assessment.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                let days = max(0, Int(ceil(item.assessment.dueDate.timeIntervalSinceNow / 86400)))
                let dueText = days == 0 ? "Due today" : (days == 1 ? "Due tomorrow" : "Due in \(days) days")
                Text("\(dueText) • \(Int(item.assessment.weighting))% weighting")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.3))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(min(max(item.assessment.progress, 0.05), 1.0)))
                }
            }
            .frame(height: 6)

            Button {
                selectedItem = item
            } label: {
                HStack {
                    Text("Open Details")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white)
                .foregroundColor(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.orange.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    private func priorityCard(item: PrioritisedAssessmentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: item.priority.iconName)
                    Text(item.priority.rawValue.uppercased())
                }
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(item.priority.badgeColor.opacity(0.15))
                .foregroundColor(item.priority.badgeColor)
                .clipShape(Capsule())

                Spacer()

                Text("\(Int(item.assessment.weighting))% weighting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let code = viewModel.subjectCode(for: item.assessment.subjectId) {
                    Text(code)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)
                }

                Text(item.assessment.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                let days = max(0, Int(ceil(item.assessment.dueDate.timeIntervalSinceNow / 86400)))
                let dueText = days == 0 ? "Due today" : (days == 1 ? "Due tomorrow" : "Due in \(days) days")
                Text("\(dueText) • Progress \(Int(item.assessment.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemGroupedBackground))
                    Capsule()
                        .fill(item.priority.badgeColor)
                        .frame(width: geo.size.width * CGFloat(min(max(item.assessment.progress, 0.03), 1.0)))
                }
            }
            .frame(height: 5)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .padding(.top, 20)

            Text("No Incomplete Assessments")
                .font(.headline)

            Text("You have no pending coursework matching this priority filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
