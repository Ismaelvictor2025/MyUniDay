//
//  PrepareView.swift
//  MyUniDay
//
//  Dedicated screen presenting class preparation checklists for upcoming classes.
//

import SwiftUI

public struct PrepareView: View {
    public var container: AppDependencyContainer
    @State private var upcomingSessions: [ClassSession] = []
    @State private var selectedSessionIndex: Int = 0
    @State private var subjectsById: [UUID: UniversitySubject] = [:]
    @State private var isLoading: Bool = false

    public init(container: AppDependencyContainer) {
        self.container = container
    }

    private var activeSession: ClassSession? {
        guard !upcomingSessions.isEmpty, selectedSessionIndex < upcomingSessions.count else { return nil }
        return upcomingSessions[selectedSessionIndex]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "backpack.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.amber, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CLASS PREPARATION")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.amber)
                            .tracking(1.2)
                        Text("What to bring & review before class")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                if isLoading {
                    ProgressView("Loading upcoming class preparation...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if upcomingSessions.isEmpty {
                    emptyState
                } else {
                    // Class selector pills if multiple upcoming classes
                    if upcomingSessions.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(upcomingSessions.enumerated()), id: \.element.id) { index, session in
                                    let code = session.subjectId.flatMap { subjectsById[$0]?.code } ?? "Class"
                                    Button {
                                        selectedSessionIndex = index
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: session.classType.iconName)
                                            Text("\(code) \(session.classType.rawValue)")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(selectedSessionIndex == index ? .bold : .medium)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedSessionIndex == index ? Color.amber : Color(.secondarySystemGroupedBackground))
                                        .foregroundColor(selectedSessionIndex == index ? .white : .primary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    if let session = activeSession {
                        sessionHeaderCard(session: session)
                        prepChecklistCard(session: session)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Prepare")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            let subjects = try await container.getSubjectsUseCase.execute()
            var map: [UUID: UniversitySubject] = [:]
            for s in subjects { map[s.id] = s }
            self.subjectsById = map

            let sessions = try await container.classSessionRepository.fetchUpcomingClassSessions(from: Date())
            self.upcomingSessions = sessions
            if selectedSessionIndex >= sessions.count {
                selectedSessionIndex = 0
            }
        } catch {
            // gracefully fallback
        }
        isLoading = false
    }

    private func sessionHeaderCard(session: ClassSession) -> some View {
        let code = session.subjectId.flatMap { subjectsById[$0]?.code } ?? "University Class"
        let name = session.subjectId.flatMap { subjectsById[$0]?.name } ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.classType.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
                    .foregroundColor(.white)

                Spacer()

                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(code)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if !name.isEmpty {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text("\(session.building) • \(session.room) (\(session.campus) Campus)")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.amber, Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.amber.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    private func prepChecklistCard(session: ClassSession) -> some View {
        let completed = session.preparationItems.filter { $0.isCompleted }.count
        let total = session.preparationItems.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Preparation Checklist", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(completed)/\(total) Ready")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(completed == total && total > 0 ? Color.green.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                    .foregroundColor(completed == total && total > 0 ? .green : .secondary)
                    .clipShape(Capsule())
            }

            if session.preparationItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("No specific preparation required for this session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                VStack(spacing: 8) {
                    ForEach(session.preparationItems) { item in
                        Button {
                            Task {
                                _ = try? await container.toggleTaskCompletionUseCase.togglePreparationItem(
                                    item: item,
                                    inSessionId: session.id
                                )
                                await loadData()
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundColor(item.isCompleted ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .strikethrough(item.isCompleted, color: .secondary)
                                        .foregroundStyle(item.isCompleted ? .secondary : .primary)

                                    if let notes = item.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "backpack")
                .font(.system(size: 44))
                .foregroundStyle(.amber)
                .padding(.top, 20)

            Text("No Upcoming Classes")
                .font(.headline)

            Text("You don't have any classes scheduled in the immediate future to prepare for.")
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
