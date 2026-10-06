//
//  RemindersView.swift
//  MyUniDay
//
//  Aggregates upcoming academic deadlines, classes with incomplete preparation,
//  and urgent tasks based on real student data already stored in the app.
//

import SwiftUI

public struct RemindersView: View {
    @Bindable public var viewModel: RemindersViewModel
    public var container: AppDependencyContainer?

    @State private var isSchedulingReminder: Bool = false
    @State private var reminderStatusMessage: String?
    @State private var showingStatusAlert: Bool = false
    @State private var alertTitle: String = "Assessment Reminder"

    public init(viewModel: RemindersViewModel, container: AppDependencyContainer? = nil) {
        self.viewModel = viewModel
        self.container = container
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACADEMIC REMINDERS")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.orange)
                            .tracking(1.2)
                        Text("Active deadlines, preparation, and urgent tasks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Demo / Test Notification Section (System Extension Demonstration)
                if container != nil {
                    demoTriggerSection
                }

                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(viewModel.selectedCategory == category ? .bold : .medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(viewModel.selectedCategory == category ? Color.orange : Color(.secondarySystemGroupedBackground))
                                    .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if viewModel.isLoading {
                    ProgressView("Checking academic reminders...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.filteredReminders.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredReminders) { item in
                            reminderCard(item: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadReminders()
        }
        .alert(alertTitle, isPresented: $showingStatusAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderStatusMessage ?? "")
        }
    }

    private var demoTriggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.waveform.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("EXTENSION DEMO")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.purple)
                    .tracking(1.0)
            }

            Text("Preview Assessment Reminder Notification")
                .font(.subheadline)
                .fontWeight(.bold)

            Text("Schedules a local notification with custom extension UI in 5 seconds using your highest-priority assessment.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await triggerTestReminder()
                }
            } label: {
                HStack(spacing: 6) {
                    if isSchedulingReminder {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                        Text("Schedule Test Reminder (5s)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isSchedulingReminder)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    private func triggerTestReminder() async {
        isSchedulingReminder = true

        let authResult = await viewModel.requestNotificationAuthorization()
        switch authResult {
        case .success:
            do {
                let payload = try await viewModel.scheduleAssessmentReminder(delaySeconds: 5)
                alertTitle = "Reminder Scheduled"
                reminderStatusMessage = "Notification scheduled for '\(payload.assessmentTitle)' (\(payload.subjectCode)). Go to your Home Screen or lock your simulator now — the custom banner will appear in 5 seconds!"
                showingStatusAlert = true
            } catch {
                alertTitle = "Reminder Unavailable"
                reminderStatusMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to schedule reminder. Please check your assessments and try again."
                showingStatusAlert = true
            }
        case .failure(let error):
            alertTitle = "Notifications Disabled"
            reminderStatusMessage = error.errorDescription ?? "Notifications are disabled. Please enable them in Settings to receive alerts."
            showingStatusAlert = true
        }

        isSchedulingReminder = false
    }

    private func reminderCard(item: StudentReminderItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.iconName)
                .font(.title2)
                .foregroundStyle(item.isUrgent ? .red : .orange)
                .frame(width: 32)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    if item.isUrgent {
                        Text("URGENT")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(item.isUrgent ? .red : .secondary)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.top, 20)

            Text("No Active Reminders")
                .font(.headline)

            Text("You are completely up to date with your coursework and upcoming classes.")
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
