//
//  GroupWorkView.swift
//  MyUniDay
//
//  A functional local collaborative project-management feature for university group assignments.
//

import SwiftUI

public struct GroupWorkView: View {
    @Bindable public var viewModel: GroupWorkViewModel
    public var container: AppDependencyContainer?

    @State private var isShowingCreateProject = false
    @State private var availableSubjects: [UniversitySubject] = []
    @State private var projectToEdit: GroupProject?
    @State private var projectToDelete: GroupProject?

    public init(viewModel: GroupWorkViewModel, container: AppDependencyContainer? = nil) {
        self.viewModel = viewModel
        self.container = container
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GROUP PROJECTS")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.pink)
                            .tracking(1.2)
                        Text("Local collaborative deliverable management")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Button {
                        isShowingCreateProject = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.small)
                }
                .padding(.horizontal, 4)

                if viewModel.isLoading {
                    ProgressView("Loading group projects...")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if viewModel.projects.isEmpty {
                    emptyState
                } else {
                    projectsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Group Work")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingCreateProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.loadProjects()
            if let container = container {
                availableSubjects = (try? await container.getSubjectsUseCase.execute()) ?? []
            }
        }
        .refreshable {
            await viewModel.loadProjects()
        }
        .sheet(isPresented: $isShowingCreateProject) {
            CreateGroupProjectView(
                subjects: availableSubjects.isEmpty ? viewModel.subjects : availableSubjects,
                onSave: { name, subjectId, dueDate, myRole, members, tasks in
                    try await viewModel.createProject(
                        name: name,
                        subjectId: subjectId,
                        dueDate: dueDate,
                        myRole: myRole,
                        members: members,
                        tasks: tasks
                    )
                }
            )
        }
        .sheet(item: $projectToEdit) { project in
            EditGroupProjectView(
                project: project,
                subjects: availableSubjects.isEmpty ? viewModel.subjects : availableSubjects,
                onSave: { name, subjectId, dueDate, myRole in
                    try await viewModel.updateProject(
                        id: project.id,
                        name: name,
                        subjectId: subjectId,
                        dueDate: dueDate,
                        myRole: myRole
                    )
                }
            )
        }
        .confirmationDialog(
            "Delete \"\(projectToDelete?.name ?? "Project")\"?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                if let project = projectToDelete {
                    Task {
                        await viewModel.deleteProject(id: project.id)
                        projectToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            Text("This will permanently delete this group project and its associated members and tasks.")
        }
    }

    // MARK: - Projects List
    private var projectsList: some View {
        VStack(spacing: 14) {
            ForEach(viewModel.projects) { project in
                projectCard(project: project)
            }
        }
    }

    private func projectCard(project: GroupProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                NavigationLink {
                    GroupProjectDetailView(viewModel: viewModel, projectId: project.id)
                } label: {
                    HStack {
                        if let subjectDesc = viewModel.subjectDescription(for: project.subjectId) {
                            Text(subjectDesc)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.pink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.pink.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("\(project.members.count) members")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                // Project Options Menu
                Menu {
                    Button {
                        projectToEdit = project
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        projectToDelete = project
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }

            // Tappable main card area navigating to detail
            NavigationLink {
                GroupProjectDetailView(viewModel: viewModel, projectId: project.id)
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            Text("Due \(project.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Role: \(project.myRole)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(project.progress * 100))%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule()
                                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(0, min(geo.size.width * CGFloat(project.progress), geo.size.width)))
                            }
                        }
                        .frame(height: 6)

                        Text("\(project.completedTasksCount) of \(project.totalTasksCount) tasks completed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.pink)
                .padding(.top, 24)

            VStack(spacing: 6) {
                Text("No Group Projects Yet")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Organise team assignments, assign deliverables to teammates, and track collective milestones locally.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                isShowingCreateProject = true
            } label: {
                Label("New Group Project", systemImage: "plus")
                    .fontWeight(.bold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
