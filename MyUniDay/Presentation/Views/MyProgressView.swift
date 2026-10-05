//
//  MyProgressView.swift
//  MyUniDay
//
//  Visually summarizes the student's academic productivity and completion progress.
//  Focuses purely on genuine productivity metrics (assessments, tasks, class prep).
//

import SwiftUI

public struct MyProgressView: View {
    @Bindable public var viewModel: MyProgressViewModel

    public init(viewModel: MyProgressViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MY PROGRESS")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.teal)
                            .tracking(1.2)
                        Text("Productivity & Coursework Completion")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                if viewModel.isLoading || !viewModel.hasLoadedInitialData {
                    ProgressView("Calculating academic progress...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    overallCompletionHero(report: viewModel.report)
                    metricsBreakdownGrid(report: viewModel.report)

                    if !viewModel.report.subjectSummaries.isEmpty {
                        subjectBreakdownSection(summaries: viewModel.report.subjectSummaries)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProgress()
        }
    }

    // MARK: - Overall Completion Hero
    private func overallCompletionHero(report: AcademicProgressReport) -> some View {
        let percent = Int(report.overallCompletionRate * 100)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OVERALL COMPLETION")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1)

                    Text("\(percent)%")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Across assessments, milestones & class prep")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Circular Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(report.overallCompletionRate, 0.03), 1.0)))
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: percent >= 80 ? "sparkles" : (percent >= 50 ? "bolt.fill" : "flame.fill"))
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .frame(width: 84, height: 84)
            }

            // Linear Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(min(max(report.overallCompletionRate, 0.05), 1.0)))
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.teal, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.teal.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    // MARK: - Metrics Breakdown Grid
    private func metricsBreakdownGrid(report: AcademicProgressReport) -> some View {
        VStack(spacing: 12) {
            metricCard(
                title: "Assessments",
                completed: report.completedAssessments,
                remaining: report.remainingAssessments,
                rate: report.assessmentCompletionRate,
                icon: "doc.text.fill",
                tint: .indigo
            )

            metricCard(
                title: "Milestone Tasks",
                completed: report.completedTasks,
                remaining: report.remainingTasks,
                rate: report.taskCompletionRate,
                icon: "checkmark.circle.fill",
                tint: .green
            )

            metricCard(
                title: "Class Preparation",
                completed: report.completedPreparationItems,
                remaining: report.remainingPreparationItems,
                rate: report.preparationCompletionRate,
                icon: "backpack.fill",
                tint: .orange
            )
        }
    }

    private func metricCard(
        title: String,
        completed: Int,
        remaining: Int,
        rate: Double,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(tint)

                Spacer()

                Text("\(Int(rate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            // Stats row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("\(completed) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "circle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(remaining) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemGroupedBackground))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(min(max(rate, 0.03), 1.0)))
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Subject Breakdown Section
    private func subjectBreakdownSection(summaries: [SubjectProgressSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBJECT COMPLETION")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1)

            ForEach(summaries) { summary in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(summary.subjectCode)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("• " + summary.subjectName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(summary.progressRate * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("\(summary.completedAssessments) of \(summary.totalAssessments) assessments finished")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemGroupedBackground))
                            Capsule()
                                .fill(Color.teal)
                                .frame(width: geo.size.width * CGFloat(min(max(summary.progressRate, 0.04), 1.0)))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
