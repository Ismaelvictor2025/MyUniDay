//
//  DashboardView.swift
//  MyUniDay
//
//  Primary student dashboard view answering:
//  - What should I prioritise?
//  - Where do I need to be next?
//  - What do I need to prepare?
//

import SwiftUI

/// The root dashboard view for MyUniDay.
///
/// Consumes `DashboardViewModel` to display a modern, structured, and visually engaging
/// overview of upcoming priorities, timetable commitments, and preparation tasks.
public struct DashboardView: View {
    @Bindable public var viewModel: DashboardViewModel
    #if DEBUG
    public var onSwitchMode: ((Bool) -> Void)?
    public var isDemoMode: Bool = false
    #endif

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    #if DEBUG
    public init(
        viewModel: DashboardViewModel,
        isDemoMode: Bool = false,
        onSwitchMode: ((Bool) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.isDemoMode = isDemoMode
        self.onSwitchMode = onSwitchMode
    }
    #endif

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerHeroSection

                    QuickActionsSection()

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    if viewModel.isLoading && viewModel.priorityAssessments.isEmpty && viewModel.nextClass == nil {
                        loadingSection
                    } else {
                        prioritySection
                        nextClassSection
                        preparationSection
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
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
        }
    }

    // MARK: - 1. Header Hero Section

    @ViewBuilder
    private var headerHeroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentDateFormatted)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                        .textCase(.uppercase)

                    Text("Here's your uni day")
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "graduationcap.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(18)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [Color.indigo.opacity(0.12), Color.blue.opacity(0.04), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.indigo.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2. Priority Assessments Section

    @ViewBuilder
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Priority", systemImage: "flame.fill", color: .orange)

            if viewModel.prioritisedAssessments.isEmpty {
                EmptyStateCard(
                    iconName: "checkmark.seal.fill",
                    title: "All caught up",
                    subtitle: "No incomplete assessments due soon."
                )
            } else {
                VStack(spacing: 14) {
                    // Highest priority item rendered as the prominent FOCUS NOW card
                    if let focusItem = viewModel.prioritisedAssessments.first {
                        FocusNowHeroCard(item: focusItem)
                    }

                    // Remaining priority items rendered as standard cards
                    ForEach(Array(viewModel.prioritisedAssessments.dropFirst())) { item in
                        AssessmentPriorityCard(item: item)
                    }
                }
            }
        }
    }

    // MARK: - 3. Next Class Section

    @ViewBuilder
    private var nextClassSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Next Class", systemImage: "clock.badge.checkmark.fill", color: .indigo)

            if let session = viewModel.nextClass {
                NextClassCard(session: session)
            } else {
                EmptyStateCard(
                    iconName: "calendar.badge.clock",
                    title: "No more classes scheduled",
                    subtitle: "You're done with classes for the day."
                )
            }
        }
    }

    // MARK: - 4. Prepare for Class Section

    @ViewBuilder
    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Prepare for Class", systemImage: "checklist", color: .green)

            if viewModel.nextClass == nil {
                EmptyStateCard(
                    iconName: "backpack",
                    title: "No upcoming class",
                    subtitle: "Check back when your next session is scheduled."
                )
            } else if viewModel.nextClassPreparationItems.isEmpty {
                EmptyStateCard(
                    iconName: "checkmark.circle",
                    title: "Nothing to prepare",
                    subtitle: "No required materials or tasks listed for this session."
                )
            } else {
                PreparationChecklistCard(items: viewModel.nextClassPreparationItems)
            }
        }
    }

    // MARK: - 5. Loading & Error States

    @ViewBuilder
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your uni day…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding()
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

    // MARK: - Helper Views & Formatters

    private func sectionHeader(title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundColor(color)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }
}

#Preview("Dashboard - Sample Preview") {
    let container = AppDependencyContainer(persistenceController: .preview)
    DashboardView(viewModel: container.makeDashboardViewModel())
}

#Preview("Dashboard - Empty State") {
    let container = AppDependencyContainer(persistenceController: PersistenceController(inMemory: true))
    DashboardView(viewModel: container.makeDashboardViewModel())
}
