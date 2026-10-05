//
//  DashboardView.swift
//  MyUniDay
//
//  Redesigned Home / Today student experience combining a university command centre
//  with modern productivity shortcuts, animated branding, and next class summary.
//

import SwiftUI

/// The redesigned root Home / Today view for MyUniDay.
public struct DashboardView: View {
    @Bindable public var viewModel: DashboardViewModel
    public var container: AppDependencyContainer?
    public var onSelectTab: ((AppTab) -> Void)?

    #if DEBUG
    public var onSwitchMode: ((Bool) -> Void)?
    public var isDemoMode: Bool = false
    #endif

    @State private var activeQuickAction: QuickActionType?
    @State private var activeDestination: HomeFeatureDestination?
    @State private var selectedNextClass: ClassSession?

    @State private var subjects: [UniversitySubject] = []
    @State private var allAssessments: [Assessment] = []
    @State private var upcomingSessions: [ClassSession] = []

    public init(
        viewModel: DashboardViewModel,
        container: AppDependencyContainer? = nil,
        onSelectTab: ((AppTab) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.container = container
        self.onSelectTab = onSelectTab
    }

    #if DEBUG
    public init(
        viewModel: DashboardViewModel,
        container: AppDependencyContainer? = nil,
        isDemoMode: Bool = false,
        onSwitchMode: ((Bool) -> Void)? = nil,
        onSelectTab: ((AppTab) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.container = container
        self.isDemoMode = isDemoMode
        self.onSwitchMode = onSwitchMode
        self.onSelectTab = onSelectTab
    }
    #endif

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Animated Graduation Cap Brand Header
                    GraduationCapHeaderView()

                    // 2. Concise Next Class Summary Card
                    nextClassSummarySection

                    // 3. Preserved Functional Quick Actions
                    QuickActionsSection { action in
                        Task {
                            await loadQuickActionDependencies()
                            activeQuickAction = action
                        }
                    }

                    // 4. Primary Feature Shortcuts Grid (4x3)
                    FeatureGridSection { feature in
                        handleFeatureSelection(feature)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("MyUniDay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.indigo)
                        Text("MyUniDay")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }

                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Development Mode") {
                            Button {
                                onSwitchMode?(true)
                            } label: {
                                Label("Demo Data (Populated)", systemImage: isDemoMode ? "checkmark.circle.fill" : "circle")
                            }

                            Button {
                                onSwitchMode?(false)
                            } label: {
                                Label("Live Store (Production)", systemImage: !isDemoMode ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isDemoMode ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(isDemoMode ? "Demo" : "Live")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                }
                #endif
            }
            .sheet(item: $activeQuickAction) { action in
                quickActionSheet(for: action)
            }
            .navigationDestination(item: $activeDestination) { destination in
                destinationView(for: destination)
            }
            .navigationDestination(item: $selectedNextClass) { session in
                let subject = viewModel.nextClassSubject ?? session.subjectId.flatMap { viewModel.subjectsById[$0] }
                ClassDetailView(
                    session: session,
                    subjectName: subject?.name,
                    subjectCode: subject?.code,
                    onTogglePreparationItem: { item in
                        guard let container = container else { return }
                        _ = try? await container.toggleTaskCompletionUseCase.togglePreparationItem(
                            item: item,
                            inSessionId: session.id
                        )
                        await viewModel.refresh()
                    }
                )
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
                await loadQuickActionDependencies()
            }
        }
    }

    // MARK: - Next Class Summary Section

    @ViewBuilder
    private var nextClassSummarySection: some View {
        if let session = viewModel.nextClass {
            Button {
                selectedNextClass = session
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.checkmark.fill")
                            Text("NEXT CLASS")
                        }
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.14))
                        .foregroundColor(.indigo)
                        .clipShape(Capsule())

                        Spacer()

                        Text(session.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.indigo)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        let code = viewModel.nextClassSubject?.code ?? session.subjectId.flatMap { viewModel.subjectsById[$0]?.code } ?? "Class"
                        let name = viewModel.nextClassSubject?.name ?? session.subjectId.flatMap { viewModel.subjectsById[$0]?.name } ?? ""

                        Text(code)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        if !name.isEmpty {
                            Text(name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: session.classType.iconName)
                            Text(session.classType.rawValue)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())

                        Text("•")
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                            Text("\(session.building) • \(session.room)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.indigo.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.clock")
                        Text("NEXT CLASS")
                    }
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())

                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.indigo)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Upcoming Classes Today")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("You're all clear! Great time for independent study or coursework.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Navigation Handling

    private func handleFeatureSelection(_ feature: HomeFeatureDestination) {
        if let onSelectTab = onSelectTab {
            switch feature {
            case .assessments:
                onSelectTab(.assessments)
                return
            case .timetable:
                onSelectTab(.classes)
                return
            case .tasks:
                onSelectTab(.tasks)
                return
            default:
                break
            }
        }
        activeDestination = feature
    }

    @ViewBuilder
    private func destinationView(for destination: HomeFeatureDestination) -> some View {
        switch destination {
        case .priority:
            if let container = container {
                PriorityAssessmentsView(viewModel: container.makeAssessmentsViewModel())
            }
        case .assessments:
            if let container = container {
                AssessmentsView(viewModel: container.makeAssessmentsViewModel())
            }
        case .timetable:
            if let container = container {
                ClassesView(viewModel: container.makeClassesViewModel())
            }
        case .tasks:
            if let container = container {
                TasksView(viewModel: container.makeTasksViewModel())
            }
        case .prepare:
            if let container = container {
                PrepareView(container: container)
            }
        case .studyNow:
            if let container = container {
                StudyNowView(viewModel: container.makeStudyNowViewModel(), container: container)
            }
        case .subjects:
            if let container = container {
                SubjectsView(container: container)
            }
        case .groupWork:
            if let container = container {
                GroupWorkView(viewModel: container.makeGroupWorkViewModel(), container: container)
            }
        case .myProgress:
            if let container = container {
                MyProgressView(viewModel: container.makeMyProgressViewModel())
            }
        case .support:
            SupportView()
        case .reminders:
            if let container = container {
                RemindersView(viewModel: container.makeRemindersViewModel())
            }
        case .more:
            #if DEBUG
            MoreView(isDemoMode: isDemoMode, onSwitchMode: onSwitchMode)
            #else
            MoreView()
            #endif
        }
    }

    // MARK: - Quick Action Sheets

    @ViewBuilder
    private func quickActionSheet(for action: QuickActionType) -> some View {
        switch action {
        case .addAssessment:
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
                    await viewModel.refresh()
                    await loadQuickActionDependencies()
                },
                onCreateSubject: { code, name in
                    guard let container = container else {
                        throw RepositoryError.invalidData(reason: "Container unavailable")
                    }
                    let subject = UniversitySubject(code: code, name: name, colorHex: "#3F51B5")
                    try await container.createSubjectUseCase.execute(subject: subject)
                    await loadQuickActionDependencies()
                    return subject
                }
            )

        case .addClass:
            AddClassView(
                subjects: subjects,
                onSave: { subjectId, type, start, end, campus, building, room in
                    guard let container = container else { return }
                    let session = ClassSession(
                        subjectId: subjectId,
                        classType: type,
                        startDate: start,
                        endDate: end,
                        campus: campus,
                        building: building,
                        room: room
                    )
                    try await container.createClassSessionUseCase.execute(classSession: session, forSubjectId: subjectId)
                    await viewModel.refresh()
                    await loadQuickActionDependencies()
                },
                onCreateSubject: { code, name in
                    guard let container = container else {
                        throw RepositoryError.invalidData(reason: "Container unavailable")
                    }
                    let subject = UniversitySubject(code: code, name: name, colorHex: "#3F51B5")
                    try await container.createSubjectUseCase.execute(subject: subject)
                    await loadQuickActionDependencies()
                    return subject
                }
            )

        case .addTask:
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
                    await viewModel.refresh()
                    await loadQuickActionDependencies()
                },
                onSavePreparationItem: { title, notes, sessionId in
                    guard let container = container else { return }
                    _ = try await container.createTaskUseCase.addPreparationItem(
                        title: title,
                        notes: notes,
                        toSessionId: sessionId
                    )
                    await viewModel.refresh()
                    await loadQuickActionDependencies()
                }
            )
        }
    }

    private func loadQuickActionDependencies() async {
        guard let container = container else { return }
        self.subjects = (try? await container.getSubjectsUseCase.execute()) ?? []
        self.allAssessments = (try? await container.assessmentRepository.fetchAllAssessments()) ?? []
        self.upcomingSessions = (try? await container.classSessionRepository.fetchUpcomingClassSessions(from: Date())) ?? []
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Unable to load data")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview("Dashboard - Sample Preview") {
    let container = AppDependencyContainer(persistenceController: .preview)
    DashboardView(viewModel: container.makeDashboardViewModel(), container: container)
}
