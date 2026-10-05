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

    public init(viewModel: RemindersViewModel) {
        self.viewModel = viewModel
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
