//
//  StudyNowView.swift
//  MyUniDay
//
//  Answers the student's question: "WHAT SHOULD I DO NOW?"
//  Uses deterministic smart prioritisation from existing assessment priority data.
//

import SwiftUI

public struct StudyNowView: View {
    @Bindable public var viewModel: StudyNowViewModel
    public var container: AppDependencyContainer?

    @State private var selectedItem: PrioritisedAssessmentItem?

    // Quick action sheet states
    @State private var isShowingAddAssessment = false
    @State private var isShowingAddTask = false

    // Quick action data
    @State private var subjects: [UniversitySubject] = []
    @State private var allAssessments: [Assessment] = []
    @State private var upcomingSessions: [ClassSession] = []

    public init(viewModel: StudyNowViewModel, container: AppDependencyContainer? = nil) {
        self.viewModel = viewModel
        self.container = container
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WHAT SHOULD I DO NOW?")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.purple)
                            .tracking(1.2)
                        Text("Deterministic Smart Recommendation")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Quick Actions menu
                    Menu {
                        Button {
                            isShowingAddAssessment = true
                        } label: {
                            Label("Add Assessment", systemImage: "doc.badge.plus")
                        }

                        Button {
                            isShowingAddTask = true
                        } label: {
                            Label("Add Task", systemImage: "checkmark.circle.badge.plus")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Quick Action")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.12))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)

                if viewModel.isLoading || !viewModel.hasLoadedInitialData {
                    ProgressView("Analyzing workload priorities...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let rec = viewModel.recommendation {
                    recommendationCard(rec: rec)
                    focusBreakdownCard(rec: rec)
                    tipsCard
                } else {
                    emptyStateCard
                }

                // Quick Action Bar
                quickActionBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Study Now")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRecommendation()
            await loadQuickActionDependencies()
        }
        .refreshable {
            await viewModel.loadRecommendation()
            await loadQuickActionDependencies()
        }
        .navigationDestination(item: $selectedItem) { item in
            AssessmentDetailView(
                item: item,
                subjectName: viewModel.subject?.name,
                subjectCode: viewModel.subject?.code,
                onToggleTask: { taskId in
                    guard let container = container else { return }
                    _ = try? await container.toggleTaskCompletionUseCase.toggleAssessmentTask(taskId: taskId, inAssessmentId: item.assessment.id)
                    await viewModel.loadRecommendation()
                },
                onAddTask: { title, dueDate in
                    guard let container = container else { return }
                    _ = try? await container.createTaskUseCase.addAssessmentTask(title: title, dueDate: dueDate, toAssessmentId: item.assessment.id)
                    await viewModel.loadRecommendation()
                },
                onDeleteTask: { taskId in
                    guard let container = container else { return }
                    _ = try? await container.createTaskUseCase.deleteAssessmentTask(taskId: taskId, fromAssessmentId: item.assessment.id)
                    await viewModel.loadRecommendation()
                },
                onUpdateTask: { taskId, title in
                    guard let container = container else { return }
                    _ = try? await container.createTaskUseCase.updateAssessmentTask(taskId: taskId, title: title, inAssessmentId: item.assessment.id)
                    await viewModel.loadRecommendation()
                },
                onUpdateProgress: { newProgress in
                    guard let container = container else { return }
                    _ = try? await container.updateAssessmentProgressUseCase.execute(assessmentId: item.assessment.id, progress: newProgress)
                    await viewModel.loadRecommendation()
                }
            )
        }
        .sheet(isPresented: $isShowingAddAssessment) {
            AddAssessmentView(
                subjects: subjects,
                onSave: { title, subjectId, dueDate, weighting, workload, progress, notes, breakdownSteps in
                    guard let container = container else { return }
                    let assessmentId = UUID()
                    let tasks = breakdownSteps.enumerated().map { idx, step in
                        AssessmentTask(
                            id: UUID(),
                            assessmentId: assessmentId,
                            title: step,
                            isCompleted: false,
                            orderIndex: idx
                        )
                    }
                    var assessment = Assessment(
                        id: assessmentId,
                        subjectId: subjectId,
                        title: title,
                        dueDate: dueDate,
                        weighting: weighting,
                        estimatedWorkloadHours: workload,
                        progress: progress,
                        isCompleted: progress >= 1.0,
                        notes: notes,
                        tasks: tasks
                    )
                    AssessmentProgressCalculator.synchronize(&assessment)
                    try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)
                    await viewModel.loadRecommendation()
                    await loadQuickActionDependencies()
                },
                onCreateSubject: { code, name in
                    guard let container = container else {
                        throw RepositoryError.invalidData(reason: "Container unavailable")
                    }
                    let s = UniversitySubject(code: code, name: name, colorHex: "#3F51B5")
                    try await container.createSubjectUseCase.execute(subject: s)
                    await loadQuickActionDependencies()
                    return s
                }
            )
        }
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskView(
                assessments: allAssessments,
                sessions: upcomingSessions,
                onSaveAssessmentTask: { title, dueDate, assessmentId in
                    guard let container = container else { return }
                    _ = try await container.createTaskUseCase.addAssessmentTask(
                        title: title,
                        dueDate: dueDate,
                        toAssessmentId: assessmentId
                    )
                    await viewModel.loadRecommendation()
                    await loadQuickActionDependencies()
                },
                onSavePreparationItem: { title, notes, sessionId in
                    guard let container = container else { return }
                    _ = try await container.createTaskUseCase.addPreparationItem(
                        title: title,
                        notes: notes,
                        toSessionId: sessionId
                    )
                    await viewModel.loadRecommendation()
                    await loadQuickActionDependencies()
                }
            )
        }
    }

    // MARK: - Recommendation Card
    private func recommendationCard(rec: StudyRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("WHAT SHOULD I DO NOW?")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: rec.priority.iconName)
                    Text("\(rec.priority.rawValue.uppercased()) PRIORITY")
                }
                .font(.caption2)
                .fontWeight(.heavy)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
                .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let subj = viewModel.subject {
                    Text(subj.code + " — " + subj.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(rec.assessment.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                let days = max(0, Int(ceil(rec.assessment.dueDate.timeIntervalSinceNow / 86400)))
                let dueText = days == 0 ? "Due today" : (days == 1 ? "Due in 1 day" : "Due in \(days) days")
                Text("\(dueText) • \(Int(rec.assessment.progress * 100))% complete • \(Int(rec.assessment.weighting))% weighting")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Completion Progress")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("\(Int(rec.assessment.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(min(max(rec.assessment.progress, 0.05), 1.0)))
                    }
                }
                .frame(height: 8)
            }

            Divider().overlay(Color.white.opacity(0.25))

            // NEXT STEP SECTION
            VStack(alignment: .leading, spacing: 10) {
                Text("NEXT STEP")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(1)

                if let task = rec.nextPendingTask {
                    HStack(spacing: 10) {
                        Image(systemName: "square")
                            .font(.title3)
                            .foregroundStyle(.white)

                        Text(task.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Buttons: Mark Step Complete + View Assessment
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.markCurrentStepComplete()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark Step Complete")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .foregroundColor(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            selectedItem = PrioritisedAssessmentItem(assessment: rec.assessment, priority: rec.priority)
                        } label: {
                            HStack {
                                Text("View Assessment")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    // No pending breakdown task
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.recommendedActionTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text(rec.recommendedActionDetail)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Button {
                        selectedItem = PrioritisedAssessmentItem(assessment: rec.assessment, priority: rec.priority)
                    } label: {
                        HStack {
                            Text("View Assessment")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.purple.opacity(0.25), radius: 10, x: 0, y: 5)
    }

    // MARK: - Focus Breakdown Card
    private func focusBreakdownCard(rec: StudyRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Workload Breakdown", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                metricTile(
                    title: "Est. Remaining",
                    value: String(format: "%.1f hrs", rec.remainingHours),
                    icon: "hourglass",
                    color: .orange
                )
                metricTile(
                    title: "Total Workload",
                    value: "\(Int(rec.assessment.estimatedWorkloadHours)) hrs",
                    icon: "chart.bar.doc.horizontal",
                    color: .blue
                )
                metricTile(
                    title: "Weighting",
                    value: "\(Int(rec.assessment.weighting))%",
                    icon: "percent",
                    color: .purple
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Study Tips Card
    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recommended Study Strategy", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.orange)

            Text("Tackle your recommended milestone first. Breaking high-priority coursework into actionable 25-minute sprints ensures continuous measurable progress.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Action Bar
    private var quickActionBar: some View {
        HStack(spacing: 12) {
            Button {
                isShowingAddAssessment = true
            } label: {
                Label("Add Assessment", systemImage: "doc.badge.plus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.indigo)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            Button {
                isShowingAddTask = true
            } label: {
                Label("Add Task", systemImage: "checkmark.circle.badge.plus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State Card
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(.green)
                .padding(.top, 24)

            VStack(spacing: 6) {
                Text("All Caught Up!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You have no pending incomplete coursework. Tap below to create an assessment or task.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                Button {
                    isShowingAddAssessment = true
                } label: {
                    Label("Add Assessment", systemImage: "plus")
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Button {
                    isShowingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func loadQuickActionDependencies() async {
        guard let container = container else { return }
        self.subjects = (try? await container.getSubjectsUseCase.execute()) ?? []
        self.allAssessments = (try? await container.assessmentRepository.fetchAllAssessments()) ?? []
        self.upcomingSessions = (try? await container.classSessionRepository.fetchUpcomingClassSessions(from: Date())) ?? []
    }
}
