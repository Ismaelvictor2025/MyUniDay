//
//  MainTabView.swift
//  MyUniDay
//
//  Root navigation TabView housing the 4 primary application areas:
//  1. Today (Dashboard)
//  2. Assessments
//  3. Classes (Timetable)
//  4. Tasks (Action Items & Prep)
//

import SwiftUI

/// Main application navigation tabs.
public enum AppTab: Hashable, Sendable {
    case today
    case assessments
    case classes
    case tasks
}

/// Root multi-screen container view providing tabbed navigation across MyUniDay.
public struct MainTabView: View {
    public let container: AppDependencyContainer

    #if DEBUG
    public var isDemoMode: Bool = false
    public var onSwitchMode: ((Bool) -> Void)?
    #endif

    @State private var selectedTab: AppTab = .today
    @State private var dashboardViewModel: DashboardViewModel
    @State private var assessmentsViewModel: AssessmentsViewModel
    @State private var classesViewModel: ClassesViewModel
    @State private var tasksViewModel: TasksViewModel

    #if DEBUG
    public init(
        container: AppDependencyContainer,
        isDemoMode: Bool = false,
        onSwitchMode: ((Bool) -> Void)? = nil
    ) {
        self.container = container
        self.isDemoMode = isDemoMode
        self.onSwitchMode = onSwitchMode

        _dashboardViewModel = State(initialValue: container.makeDashboardViewModel())
        _assessmentsViewModel = State(initialValue: container.makeAssessmentsViewModel())
        _classesViewModel = State(initialValue: container.makeClassesViewModel())
        _tasksViewModel = State(initialValue: container.makeTasksViewModel())
    }
    #else
    public init(container: AppDependencyContainer) {
        self.container = container

        _dashboardViewModel = State(initialValue: container.makeDashboardViewModel())
        _assessmentsViewModel = State(initialValue: container.makeAssessmentsViewModel())
        _classesViewModel = State(initialValue: container.makeClassesViewModel())
        _tasksViewModel = State(initialValue: container.makeTasksViewModel())
    }
    #endif

    public var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Today (Dashboard)
            Group {
                #if DEBUG
                DashboardView(
                    viewModel: dashboardViewModel,
                    container: container,
                    isDemoMode: isDemoMode,
                    onSwitchMode: onSwitchMode,
                    onSelectTab: { tab in
                        selectedTab = tab
                    }
                )
                #else
                DashboardView(
                    viewModel: dashboardViewModel,
                    container: container,
                    onSelectTab: { tab in
                        selectedTab = tab
                    }
                )
                #endif
            }
            .tabItem {
                Label("Today", systemImage: "house.fill")
            }
            .tag(AppTab.today)

            // 2. Assessments
            AssessmentsView(viewModel: assessmentsViewModel)
                .tabItem {
                    Label("Assessments", systemImage: "doc.text.fill")
                }
                .tag(AppTab.assessments)

            // 3. Classes
            ClassesView(viewModel: classesViewModel)
                .tabItem {
                    Label("Classes", systemImage: "calendar")
                }
                .tag(AppTab.classes)

            // 4. Tasks
            TasksView(viewModel: tasksViewModel)
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.circle.fill")
                }
                .tag(AppTab.tasks)
        }
        .tint(.indigo)
        .onChange(of: selectedTab) { _, newTab in
            Task {
                switch newTab {
                case .today:
                    await dashboardViewModel.loadDashboard()
                case .assessments:
                    await assessmentsViewModel.loadAssessments()
                case .classes:
                    await classesViewModel.loadClasses()
                case .tasks:
                    await tasksViewModel.loadTasks()
                }
            }
        }
    }
}

#Preview {
    MainTabView(container: AppDependencyContainer(persistenceController: .preview))
}
