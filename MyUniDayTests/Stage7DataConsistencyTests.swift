//
//  Stage7DataConsistencyTests.swift
//  MyUniDayTests
//
//  Comprehensive verification suite for cross-system functional consistency:
//  - Assessment breakdown & automatic progress derivation
//  - Priority recalculation from real progress
//  - Study Now smart recommendation without false "All Caught Up" states
//  - My Progress item-based calculation without double counting
//  - Group Work local project management, member assignments, and progress
//  - Persistence round trips
//

import Testing
import Foundation
import CoreData
@testable import MyUniDay

@Suite("Stage 7 Data Consistency & Integration Tests")
@MainActor
struct Stage7DataConsistencyTests {

    private func makeTestContainer() -> AppDependencyContainer {
        #if DEBUG
        return DevelopmentDemoData.makeDemoContainer()
        #else
        return AppDependencyContainer(persistenceController: PersistenceController(inMemory: true))
        #endif
    }

    // MARK: - 1 to 4: Assessment Progress Derivation Tests

    @Test("1. Assessment with 0/4 tasks has 0% progress")
    func testAssessmentZeroOfFourTasksProgress() {
        let tasks = [
            AssessmentTask(title: "Task 1", isCompleted: false, orderIndex: 0),
            AssessmentTask(title: "Task 2", isCompleted: false, orderIndex: 1),
            AssessmentTask(title: "Task 3", isCompleted: false, orderIndex: 2),
            AssessmentTask(title: "Task 4", isCompleted: false, orderIndex: 3)
        ]
        let result = AssessmentProgressCalculator.calculate(tasks: tasks)
        #expect(result.progress == 0.0)
        #expect(result.isCompleted == false)
    }

    @Test("2. Assessment with 1/4 tasks has 25% progress")
    func testAssessmentOneOfFourTasksProgress() {
        let tasks = [
            AssessmentTask(title: "Task 1", isCompleted: true, orderIndex: 0),
            AssessmentTask(title: "Task 2", isCompleted: false, orderIndex: 1),
            AssessmentTask(title: "Task 3", isCompleted: false, orderIndex: 2),
            AssessmentTask(title: "Task 4", isCompleted: false, orderIndex: 3)
        ]
        let result = AssessmentProgressCalculator.calculate(tasks: tasks)
        #expect(abs(result.progress - 0.25) < 0.001)
        #expect(result.isCompleted == false)
    }

    @Test("3. Assessment with 2/4 tasks has 50% progress")
    func testAssessmentTwoOfFourTasksProgress() {
        let tasks = [
            AssessmentTask(title: "Task 1", isCompleted: true, orderIndex: 0),
            AssessmentTask(title: "Task 2", isCompleted: true, orderIndex: 1),
            AssessmentTask(title: "Task 3", isCompleted: false, orderIndex: 2),
            AssessmentTask(title: "Task 4", isCompleted: false, orderIndex: 3)
        ]
        let result = AssessmentProgressCalculator.calculate(tasks: tasks)
        #expect(abs(result.progress - 0.50) < 0.001)
        #expect(result.isCompleted == false)
    }

    @Test("4. Assessment with 4/4 tasks has 100% progress and marks completed")
    func testAssessmentFourOfFourTasksProgress() {
        let tasks = [
            AssessmentTask(title: "Task 1", isCompleted: true, orderIndex: 0),
            AssessmentTask(title: "Task 2", isCompleted: true, orderIndex: 1),
            AssessmentTask(title: "Task 3", isCompleted: true, orderIndex: 2),
            AssessmentTask(title: "Task 4", isCompleted: true, orderIndex: 3)
        ]
        let result = AssessmentProgressCalculator.calculate(tasks: tasks)
        #expect(result.progress >= 1.0)
        #expect(result.isCompleted == true)
    }

    // MARK: - 5: Unchecking Task Reduces Progress

    @Test("5. Unchecking a task reduces progress and synchronizes assessment state")
    func testUncheckingTaskReducesProgress() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let assessmentId = UUID()
        let task1 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Step 1", isCompleted: true, orderIndex: 0)
        let task2 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Step 2", isCompleted: true, orderIndex: 1)

        var assessment = Assessment(
            id: assessmentId,
            subjectId: subjectId,
            title: "Testing Uncheck",
            dueDate: Date().addingTimeInterval(86400 * 5),
            weighting: 20.0,
            estimatedWorkloadHours: 10.0,
            progress: 1.0,
            isCompleted: true,
            tasks: [task1, task2]
        )
        AssessmentProgressCalculator.synchronize(&assessment)
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        // Toggle task2 to incomplete
        let updated = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(taskId: task2.id, inAssessmentId: assessmentId)
        #expect(abs(updated.progress - 0.50) < 0.001)
        #expect(updated.isCompleted == false)

        // Verify persisted state
        let fetched = try await container.assessmentRepository.fetchAssessment(by: assessmentId)
        #expect(abs(try #require(fetched?.progress) - 0.50) < 0.001)
        #expect(fetched?.isCompleted == false)
    }

    // MARK: - 6: Completing a Task Affects Priority Input

    @Test("6. Completing a task affects the priority input and recalculation")
    func testCompletingTaskAffectsPriority() {
        let calc = CalculateAssessmentPriorityUseCase()
        let now = Date()
        let dueDate = now.addingTimeInterval(86400 * 3) // 3 days away

        var assessmentIncomplete = Assessment(
            title: "Urgent Coursework",
            dueDate: dueDate,
            weighting: 40.0,
            estimatedWorkloadHours: 20.0,
            progress: 0.0,
            isCompleted: false
        )
        let initialPriority = calc.execute(for: assessmentIncomplete, relativeTo: now)

        // Now advance progress to 90% (e.g. 9/10 subtasks complete)
        assessmentIncomplete.progress = 0.90
        let advancedPriority = calc.execute(for: assessmentIncomplete, relativeTo: now)

        // Higher progress lowers remaining workload and urgency
        #expect(initialPriority >= advancedPriority)
    }

    // MARK: - 7 & 8: Study Now Incomplete Assessment Recommendation

    @Test("7. Study Now never reports All Caught Up when an eligible incomplete assessment exists")
    func testStudyNowRecommendsWhenIncompleteExists() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        // Add a brand new incomplete assessment
        let assessmentId = UUID()
        let step1 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Milestone A", isCompleted: false, orderIndex: 0)
        let assessment = Assessment(
            id: assessmentId,
            subjectId: subjectId,
            title: "Active Urgent Assessment",
            dueDate: Date().addingTimeInterval(86400 * 1), // Due in 1 day
            weighting: 30.0,
            estimatedWorkloadHours: 10.0,
            progress: 0.0,
            isCompleted: false,
            tasks: [step1]
        )
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        let recommendation = try await container.getStudyNowRecommendationUseCase.execute()
        #expect(recommendation != nil)
        #expect(recommendation?.assessment.isCompleted == false)
    }

    @Test("8. Study Now recommends top incomplete assessment using existing priority logic")
    func testStudyNowRecommendsTopPriorityAssessment() async throws {
        let container = makeTestContainer()
        let rec = try await container.getStudyNowRecommendationUseCase.execute()
        let recommendation = try #require(rec)

        #expect(recommendation.assessment.isCompleted == false)
        #expect(recommendation.priority == .critical || recommendation.priority == .high)
        #expect(recommendation.recommendedActionTitle.isEmpty == false)
    }

    // MARK: - 9 & 10: My Progress Calculation & No Double Counting

    @Test("9. My Progress uses actual persisted completion data without returning 0% when work exists")
    func testMyProgressUsesActualData() async throws {
        let container = makeTestContainer()
        let report = try await container.calculateAcademicProgressUseCase.execute()

        #expect(report.totalAssessments > 0)
        #expect(report.totalTasks > 0)
        #expect(report.completedTasks > 0)
        #expect(report.overallCompletionRate > 0.0)
    }

    @Test("10. Overall progress does not double-count an assessment and its breakdown")
    func testOverallProgressNoDoubleCounting() async throws {
        let container = makeTestContainer()
        let assessments = try await container.assessmentRepository.fetchAllAssessments()
        let prepItems = try await container.preparationItemRepository.fetchAllPreparationItems()

        var expectedTotal = 0
        var expectedCompleted = 0

        for a in assessments {
            if a.tasks.isEmpty {
                expectedTotal += 1
                if a.isCompleted || a.progress >= 0.999 {
                    expectedCompleted += 1
                }
            } else {
                expectedTotal += a.tasks.count
                expectedCompleted += a.tasks.filter { $0.isCompleted }.count
            }
        }
        expectedTotal += prepItems.count
        expectedCompleted += prepItems.filter { $0.isCompleted }.count

        let expectedRate = expectedTotal > 0 ? Double(expectedCompleted) / Double(expectedTotal) : 0.0

        let report = try await container.calculateAcademicProgressUseCase.execute()
        #expect(abs(report.overallCompletionRate - expectedRate) < 0.0001)
    }

    // MARK: - 11 to 13: Group Project Management & Progress Tests

    @Test("11. Group project progress is derived from group-task completion")
    func testGroupProjectProgressDerivedFromTasks() {
        let member = GroupMember(name: "Vicky", role: "Dev")
        let task1 = GroupTask(title: "Task A", assignedMemberId: member.id, isCompleted: true, orderIndex: 0)
        let task2 = GroupTask(title: "Task B", assignedMemberId: member.id, isCompleted: true, orderIndex: 1)
        let task3 = GroupTask(title: "Task C", assignedMemberId: member.id, isCompleted: false, orderIndex: 2)

        let project = GroupProject(
            name: "Team Work",
            dueDate: Date().addingTimeInterval(86400 * 10),
            members: [member],
            tasks: [task1, task2, task3]
        )

        // 2 out of 3 = 66.67%
        #expect(abs(project.progress - (2.0 / 3.0)) < 0.001)
        #expect(project.completedTasksCount == 2)
        #expect(project.totalTasksCount == 3)
    }

    @Test("12. Group task retains its assigned member")
    func testGroupTaskRetainsAssignedMember() async throws {
        let container = makeTestContainer()
        let member = GroupMember(id: UUID(), name: "Sarah", role: "Researcher")
        let task = GroupTask(id: UUID(), title: "Research Topic", assignedMemberId: member.id, isCompleted: false)

        let project = GroupProject(
            name: "Research Project",
            dueDate: Date().addingTimeInterval(86400 * 7),
            members: [member],
            tasks: [task]
        )

        try await container.groupProjectRepository.save(project: project)

        let fetched = try await container.groupProjectRepository.fetchProject(by: project.id)
        let loadedProject = try #require(fetched)
        let loadedTask = try #require(loadedProject.tasks.first { $0.id == task.id })

        #expect(loadedTask.assignedMemberId == member.id)
    }

    @Test("13. Editing and reassigning a group task works correctly")
    func testEditingAndReassigningGroupTask() async throws {
        let container = makeTestContainer()
        let memberA = GroupMember(id: UUID(), name: "Member A", role: "Role A")
        let memberB = GroupMember(id: UUID(), name: "Member B", role: "Role B")
        let task = GroupTask(id: UUID(), title: "Initial Title", assignedMemberId: memberA.id, isCompleted: false)

        let project = GroupProject(
            name: "Collab Project",
            dueDate: Date().addingTimeInterval(86400 * 7),
            members: [memberA, memberB],
            tasks: [task]
        )
        try await container.groupProjectRepository.save(project: project)

        let vm = container.makeGroupWorkViewModel()
        await vm.loadProjects()

        // Reassign to Member B and update title
        try await vm.updateTask(
            taskId: task.id,
            title: "Updated Title",
            dueDate: nil,
            assignedMemberId: memberB.id,
            isCompleted: true,
            inProjectId: project.id
        )

        let updatedProject = try #require(vm.projects.first { $0.id == project.id })
        let updatedTask = try #require(updatedProject.tasks.first { $0.id == task.id })

        #expect(updatedTask.title == "Updated Title")
        #expect(updatedTask.assignedMemberId == memberB.id)
        #expect(updatedTask.isCompleted == true)
        #expect(updatedProject.progress == 1.0)
    }

    // MARK: - 14: Completion State Persistence Round Trips

    @Test("14. Completion state persists through repository round trips")
    func testCompletionStatePersistsAcrossRoundTrips() async throws {
        let container = makeTestContainer()
        let subjects = try await container.getSubjectsUseCase.execute()
        let subjectId = try #require(subjects.first?.id)

        let assessmentId = UUID()
        let task = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Persistent Task", isCompleted: false, orderIndex: 0)
        let assessment = Assessment(
            id: assessmentId,
            subjectId: subjectId,
            title: "Persistence Verification",
            dueDate: Date().addingTimeInterval(86400 * 3),
            weighting: 15.0,
            estimatedWorkloadHours: 5.0,
            progress: 0.0,
            isCompleted: false,
            tasks: [task]
        )
        try await container.createAssessmentUseCase.execute(assessment: assessment, forSubjectId: subjectId)

        // Toggle task
        _ = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(taskId: task.id, inAssessmentId: assessmentId)

        // Fetch freshly from repository
        let reloaded = try await container.assessmentRepository.fetchAssessment(by: assessmentId)
        let finalAssessment = try #require(reloaded)

        #expect(finalAssessment.progress == 1.0)
        #expect(finalAssessment.isCompleted == true)
        #expect(finalAssessment.tasks.first?.isCompleted == true)
    }

    // MARK: - Section 20 Scenarios

    @Test("Section 20: Manual functional verification flow (A through F)")
    func testSection20ManualScenarioAThroughF() async throws {
        let container = makeTestContainer()
        let comp2014 = UniversitySubject(code: "COMP2014", name: "Object Oriented Programming")
        try await container.createSubjectUseCase.execute(subject: comp2014)

        // A & B: Create Assignment 2 with 4 breakdown tasks: Research, Design, Implementation, Testing
        let assessmentId = UUID()
        let t1 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Research", isCompleted: false, orderIndex: 0)
        let t2 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Design", isCompleted: false, orderIndex: 1)
        let t3 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Implementation", isCompleted: false, orderIndex: 2)
        let t4 = AssessmentTask(id: UUID(), assessmentId: assessmentId, title: "Testing", isCompleted: false, orderIndex: 3)

        var assignment2 = Assessment(
            id: assessmentId,
            subjectId: comp2014.id,
            title: "COMP2014 — Assignment 2",
            dueDate: Date().addingTimeInterval(86400 * 3),
            weighting: 30.0,
            estimatedWorkloadHours: 12.0,
            progress: 0.0,
            isCompleted: false,
            tasks: [t1, t2, t3, t4]
        )
        AssessmentProgressCalculator.synchronize(&assignment2)
        try await container.createAssessmentUseCase.execute(assessment: assignment2, forSubjectId: comp2014.id)

        // C: Verify progress = 0%
        var current = try #require(try await container.assessmentRepository.fetchAssessment(by: assessmentId))
        #expect(current.progress == 0.0)

        // D: Complete Research -> Verify progress = 25%
        current = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(taskId: t1.id, inAssessmentId: assessmentId)
        #expect(abs(current.progress - 0.25) < 0.001)

        // E: Complete Design -> Verify progress = 50%
        current = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(taskId: t2.id, inAssessmentId: assessmentId)
        #expect(abs(current.progress - 0.50) < 0.001)

        // F: Verify across all layers:
        // 1. Tasks ViewModel
        let tasksVM = container.makeTasksViewModel()
        await tasksVM.loadTasks()
        let matchingTasks = tasksVM.allTasks.filter { task in
            if case .assessment(let aId, _, _) = task.source {
                return aId == assessmentId
            }
            return false
        }
        #expect(matchingTasks.count == 4)
        #expect(matchingTasks.filter { $0.isCompleted }.count == 2)

        // 2. Priority
        let priorityVM = container.makeAssessmentsViewModel()
        await priorityVM.loadAssessments()
        let priorityItem = try #require(priorityVM.items.first { $0.assessment.id == assessmentId })
        #expect(abs(priorityItem.assessment.progress - 0.50) < 0.001)

        // 3. Study Now
        let studyVM = container.makeStudyNowViewModel()
        await studyVM.loadRecommendation()
        if let rec = studyVM.recommendation, rec.assessment.id == assessmentId {
            #expect(abs(rec.assessment.progress - 0.50) < 0.001)
            #expect(rec.nextPendingTask?.title == "Implementation")
        }

        // 4. My Progress
        let progressReport = try await container.calculateAcademicProgressUseCase.execute()
        #expect(progressReport.completedTasks >= 2)
        #expect(progressReport.overallCompletionRate > 0.0)
    }

    @Test("Section 20: Group Work functional verification scenario")
    func testSection20GroupWorkScenario() async throws {
        let container = makeTestContainer()
        let vm = container.makeGroupWorkViewModel()

        let vicky = GroupMember(id: UUID(), name: "Vicky", role: "Developer")
        let sarah = GroupMember(id: UUID(), name: "Sarah", role: "Research")
        let john = GroupMember(id: UUID(), name: "John", role: "Presentation")

        let tBuildUI = GroupTask(id: UUID(), title: "Build UI", assignedMemberId: vicky.id, isCompleted: false, orderIndex: 0)
        let tResearch = GroupTask(id: UUID(), title: "Research", assignedMemberId: sarah.id, isCompleted: false, orderIndex: 1)
        let tSlides = GroupTask(id: UUID(), title: "Slides", assignedMemberId: john.id, isCompleted: false, orderIndex: 2)

        let projectId = UUID()
        let project = GroupProject(
            id: projectId,
            name: "Mobile App Project",
            dueDate: Date().addingTimeInterval(86400 * 14),
            myRole: "Lead",
            members: [vicky, sarah, john],
            tasks: [tBuildUI, tResearch, tSlides]
        )
        try await container.groupProjectRepository.save(project: project)

        // Complete Research
        await vm.loadProjects()
        await vm.toggleTask(taskId: tResearch.id, inProjectId: projectId)

        // Verify group progress = 33% and Sarah remains assigned to Research
        let updated = try #require(vm.projects.first { $0.id == projectId })
        #expect(abs(updated.progress - (1.0 / 3.0)) < 0.001)
        let researchTask = try #require(updated.tasks.first { $0.id == tResearch.id })
        #expect(researchTask.isCompleted == true)
        #expect(researchTask.assignedMemberId == sarah.id)
    }

    // MARK: - Section 18: Exact Bug Scenario from Screenshots

    @Test("Section 18: Exact Bug Scenario from Screenshots - 3/6 (50%) -> 4/6 (67%) -> uncheck back to 50%")
    func testSection18ExactScenarioFromScreenshots() async throws {
        let container = makeTestContainer()

        // 1. Initial State from Demo Data:
        // Assessment A (Assignment 2): 6 tasks, 3 complete = 50%
        // Assessment B (Database Project): 4 tasks, 1 complete = 25%
        // Assessment C (Calculus Problem Set 3): 0 tasks, 0%
        let allAssessments = try await container.assessmentRepository.fetchAllAssessments()
        let assignmentA = try #require(allAssessments.first { $0.title.contains("Assignment 2") })
        let task4 = try #require(assignmentA.tasks.first { $0.title.contains("Implement models") })
        let task5 = try #require(assignmentA.tasks.first { $0.title.contains("Build user interface") })

        // Verify Assessment A progress = 50%
        #expect(abs(assignmentA.progress - 0.50) < 0.001)

        // Verify Assessment counts: 0 completed, 3 remaining
        let initialReport = try await container.calculateAcademicProgressUseCase.execute()
        #expect(initialReport.completedAssessments == 0)
        #expect(initialReport.remainingAssessments == 3)
        #expect(initialReport.totalAssessments == 3)

        // Verify Assessment A task counts: 3 completed, 3 remaining
        let completedInA = assignmentA.tasks.filter { $0.isCompleted }.count
        let remainingInA = assignmentA.tasks.filter { !$0.isCompleted }.count
        #expect(completedInA == 3)
        #expect(remainingInA == 3)

        // Verify aggregate milestone task counts across all assessments: 4 completed, 6 remaining
        #expect(initialReport.completedTasks == 4)
        #expect(initialReport.remainingTasks == 6)
        #expect(initialReport.totalTasks == 10)
        #expect(abs(initialReport.taskCompletionRate - 0.40) < 0.001)

        // 2. Complete Assessment A task #4 ("Implement models & hierarchy")
        let updatedA = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(
            taskId: task4.id,
            inAssessmentId: assignmentA.id
        )

        // Verify Assessment A = approximately 67% (4/6 = 0.6667)
        #expect(abs(updatedA.progress - (4.0 / 6.0)) < 0.001)
        #expect(Int(round(updatedA.progress * 100)) == 67)

        // Verify aggregate task counts: completed increases by 1, remaining decreases by 1
        let updatedReport = try await container.calculateAcademicProgressUseCase.execute()
        #expect(updatedReport.completedTasks == 5)
        #expect(updatedReport.remainingTasks == 5)
        #expect(updatedReport.overallCompletionRate > initialReport.overallCompletionRate)

        // Verify Study Now sees the updated assessment and recommends task #5
        let studyRec = try await container.getStudyNowRecommendationUseCase.execute()
        let rec = try #require(studyRec)
        #expect(rec.assessment.id == assignmentA.id)
        #expect(abs(rec.assessment.progress - (4.0 / 6.0)) < 0.001)
        #expect(rec.nextPendingTask?.id == task5.id)

        // Verify Priority calculation receives the updated progress
        let priority = container.calculatePriorityUseCase.execute(for: updatedA, relativeTo: Date())
        #expect(priority == .critical || priority == .high)

        // 3. Uncheck task #4 (returns to 50%)
        let revertedA = try await container.toggleTaskCompletionUseCase.toggleAssessmentTask(
            taskId: task4.id,
            inAssessmentId: assignmentA.id
        )
        #expect(abs(revertedA.progress - 0.50) < 0.001)
        #expect(Int(round(revertedA.progress * 100)) == 50)

        let revertedReport = try await container.calculateAcademicProgressUseCase.execute()
        #expect(revertedReport.completedTasks == 4)
        #expect(revertedReport.remainingTasks == 6)
        #expect(abs(revertedReport.overallCompletionRate - initialReport.overallCompletionRate) < 0.0001)

        let revertedStudyRec = try await container.getStudyNowRecommendationUseCase.execute()
        let revRec = try #require(revertedStudyRec)
        #expect(revRec.nextPendingTask?.id == task4.id)
    }

    @Test("Section 5: Manual progress update works for assessment without tasks")
    func testManualProgressFallbackWhenNoTasks() async throws {
        let container = makeTestContainer()
        let allAssessments = try await container.assessmentRepository.fetchAllAssessments()
        let calculus = try #require(allAssessments.first { $0.title.contains("Calculus") })
        #expect(calculus.tasks.isEmpty)
        #expect(calculus.progress == 0.0)

        // Manually update progress to 60%
        let updated = try await container.updateAssessmentProgressUseCase.execute(
            assessmentId: calculus.id,
            progress: 0.60
        )
        #expect(abs(updated.progress - 0.60) < 0.001)

        let report = try await container.calculateAcademicProgressUseCase.execute()
        #expect(report.overallCompletionRate > 0.0)
    }

    // MARK: - Section 8: Group Project Edit & Delete Management Tests

    @Test("Edit project name and metadata preserves members, tasks, and completion state")
    func testEditProjectPreservesMembersTasksAndProgress() async throws {
        let container = makeTestContainer()
        let vm = container.makeGroupWorkViewModel()
        await vm.loadProjects()

        let initialProject = try #require(vm.projects.first)
        let initialMemberCount = initialProject.members.count
        let initialTaskCount = initialProject.tasks.count
        let initialCompletedCount = initialProject.completedTasksCount
        let initialProgress = initialProject.progress
        let initialId = initialProject.id

        let newDueDate = Date().addingTimeInterval(86400 * 30)
        let newName = "MyUniDay Group Assignment"
        let newRole = "Coordinator"

        // Perform edit
        try await vm.updateProject(
            id: initialId,
            name: newName,
            subjectId: initialProject.subjectId,
            dueDate: newDueDate,
            myRole: newRole
        )

        // Verify project is updated in ViewModel
        let updatedProject = try #require(vm.projects.first { $0.id == initialId })
        #expect(updatedProject.name == newName)
        #expect(updatedProject.myRole == newRole)
        #expect(abs(updatedProject.dueDate.timeIntervalSince(newDueDate)) < 1.0)

        // Verify relationships and completion state are fully preserved
        #expect(updatedProject.members.count == initialMemberCount)
        #expect(updatedProject.tasks.count == initialTaskCount)
        #expect(updatedProject.completedTasksCount == initialCompletedCount)
        #expect(abs(updatedProject.progress - initialProgress) < 0.001)

        // Verify direct repository fetch also reflects updated state
        let repoFetched = try await container.groupProjectRepository.fetchProject(by: initialId)
        let directProject = try #require(repoFetched)
        #expect(directProject.name == newName)
        #expect(directProject.myRole == newRole)
        #expect(directProject.members.count == initialMemberCount)
        #expect(directProject.tasks.count == initialTaskCount)
    }

    @Test("Deleting a project removes it and does not affect another project")
    func testDeleteProjectDoesNotAffectOtherProjects() async throws {
        let container = makeTestContainer()
        let vm = container.makeGroupWorkViewModel()
        await vm.loadProjects()

        // Create a second project to simulate having duplicate/multiple projects
        let project2DueDate = Date().addingTimeInterval(86400 * 20)
        try await vm.createProject(
            name: "Duplicate Mobile App Project",
            dueDate: project2DueDate,
            myRole: "Developer"
        )

        #expect(vm.projects.count >= 2)
        let projectToDelete = try #require(vm.projects.first { $0.name == "Duplicate Mobile App Project" })
        let projectToKeep = try #require(vm.projects.first { $0.id != projectToDelete.id })
        let keepId = projectToKeep.id
        let keepName = projectToKeep.name

        // Delete the duplicate project
        await vm.deleteProject(id: projectToDelete.id)

        // Verify the deleted project is gone
        #expect(!vm.projects.contains { $0.id == projectToDelete.id })
        let directFetchDeleted = try await container.groupProjectRepository.fetchProject(by: projectToDelete.id)
        #expect(directFetchDeleted == nil)

        // Verify the kept project still exists and was untouched
        let remaining = try #require(vm.projects.first { $0.id == keepId })
        #expect(remaining.name == keepName)
        let directFetchKept = try await container.groupProjectRepository.fetchProject(by: keepId)
        #expect(directFetchKept != nil)
    }

    @Test("CoreDataGroupProjectRepository cascade cleanup removes associated members and tasks")
    func testCoreDataRepositoryCascadeCleanup() async throws {
        let inMemoryController = PersistenceController(inMemory: true)
        let repo = CoreDataGroupProjectRepository(context: inMemoryController.container.viewContext)

        let memberA = GroupMember(id: UUID(), name: "Member Alpha", role: "Dev")
        let taskA = GroupTask(id: UUID(), title: "Task Alpha", assignedMemberId: memberA.id, isCompleted: true)
        let project = GroupProject(
            name: "CoreData Cascade Test Project",
            dueDate: Date().addingTimeInterval(86400 * 10),
            myRole: "Lead",
            members: [memberA],
            tasks: [taskA]
        )

        try await repo.save(project: project)

        // Confirm saved
        let fetched = try await repo.fetchProject(by: project.id)
        #expect(fetched != nil)
        #expect(fetched?.members.count == 1)
        #expect(fetched?.tasks.count == 1)

        // Delete project
        try await repo.deleteProject(by: project.id)

        // Confirm deleted
        let afterDelete = try await repo.fetchProject(by: project.id)
        #expect(afterDelete == nil)

        // Verify no orphaned members or tasks exist in the Core Data context
        try await inMemoryController.container.viewContext.perform {
            let memberReq: NSFetchRequest<GroupMemberEntity> = GroupMemberEntity.fetchRequest()
            memberReq.predicate = NSPredicate(format: "id == %@", memberA.id as CVarArg)
            let members = try inMemoryController.container.viewContext.fetch(memberReq)
            #expect(members.isEmpty)

            let taskReq: NSFetchRequest<GroupTaskEntity> = GroupTaskEntity.fetchRequest()
            taskReq.predicate = NSPredicate(format: "id == %@", taskA.id as CVarArg)
            let tasks = try inMemoryController.container.viewContext.fetch(taskReq)
            #expect(tasks.isEmpty)
        }
    }
}
