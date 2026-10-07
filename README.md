# MyUniDay

## 1. Overview

MyUniDay is an iOS university student organisation application designed to consolidate academic priorities, assessments, timetable information, class preparation, tasks, group work, academic progress, reminders and study recommendations into a single, cohesive interface.

The core value proposition of the system is:

> "Know what to do, where to be, what to bring and what to prioritise — all in one place."

The application is built independently as a university student productivity system and does not claim official affiliation with or endorsement by any specific educational institution.

---

## 2. Problem / Domain Context

University students frequently manage academic responsibilities across fragmented platforms, including learning management systems, timetable calendars, personal notes, disparate task apps, and group chat channels. This decentralised approach produces cognitive overload and uncertainty around daily priorities.

Specifically, student information fragmentation makes it difficult to determine:

- Which assessment is most urgent and requires immediate study.
- What class is next on the schedule and where it takes place.
- What preparation materials or prerequisites must be completed before entering class.
- How much assessment work remains across milestone tasks.
- Which specific academic task should be worked on at the present moment.

MyUniDay resolves this fragmentation by establishing a single student-focused academic workflow. It couples course timetables directly with required preparation items, links assessment milestones directly to overall coursework progress, deterministically scores deadlines by urgency and weighting, and exposes actionable recommendations on demand.

---

## 3. Core Features

MyUniDay implements the following core academic features:

- **Today Dashboard**: A consolidated home screen surfacing the next scheduled class, preparation checklist items, urgent assessments, active study recommendations, and today's task list.
- **Assessment Tracking**: Detailed tracking of enrolled course deliverables, including due dates, percentage weighting, estimated workload hours, completion progress, and contextual notes.
- **Deterministic Assessment Priority Calculation**: An automated multi-factor scoring model that categorises coursework into Low, Medium, High, or Critical urgency based on time imminence, weighting, and remaining workload.
- **Assessment Milestones and Tasks**: Sub-task milestone breakdown for individual assessments, enabling incremental completion tracking.
- **Automatic Progress Synchronisation**: Automatic calculation of parent assessment completion derived from completed milestone tasks.
- **Timetable and Classes**: Scheduled class session tracking displaying course code, session type, start and end times, campus, building, and room location.
- **Class Preparation**: Linked checklists for upcoming lectures, tutorials, and practicals, allowing students to verify readings, problem sets, and required tools before class.
- **Unified Tasks**: Consolidated academic task management combining standalone tasks, assessment milestone items, and class preparation checklists in one view.
- **Study Now Recommendation**: An algorithmic decision engine evaluating due dates, weighting, and workload to suggest the highest-leverage coursework candidate to focus on immediately.
- **My Progress**: Academic progress tracking reporting overall completion ratios, total workload hours, completed assessment weightings, and milestone counts.
- **Subjects**: Course management supporting subject codes, official course titles, custom tint colours, and linked coursework/session aggregations.
- **Group Work**: Collaborative project coordination tracking group deliverables, team member roles, and task ownership assignments.
- **Reminders**: Centralised view of impending deadlines, overdue coursework, and immediate class preparation requirements, featuring a direct scheduling trigger for testing rich local notifications.
- **WidgetKit Extension**: Glanceable Lock Screen and Home Screen widgets displaying urgent deadlines and upcoming classes.
- **Notification Content Extension**: A rich interactive notification interface rendering priority badges, progress bars, milestone breakdowns, and due status directly on the notification banner.

---

## 4. Architecture

MyUniDay is architected following Clean Architecture and Domain-Driven Design principles, ensuring strict separation of concerns, testability, and independence from external persistence frameworks.

```
+--------------------------------------------------------------+
|                        SwiftUI Views                         |
|                   (Student-Facing UI Only)                   |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|                         ViewModels                           |
|       (Presentation State & Interaction Coordination)         |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|                         Use Cases                            |
|             (Domain Rules & Business Operations)             |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|                    Repository Protocols                      |
|            (Abstraction Over Data Persistence)               |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|            Core Data Repository Implementations              |
|        (CoreDataSubjectRepository, Assessment, etc.)         |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|                     Core Data Persistent                     |
|                      Store (SQLite / MOM)                    |
+--------------------------------------------------------------+
```

### Architectural Layer Responsibilities

- **Views**: Declarative SwiftUI views responsible solely for rendering UI elements, collecting user interactions, and observing state published by ViewModels. Views contain no business logic or database queries.
- **ViewModels**: Observable objects coordinating presentation state, managing loading and error states, and invoking domain use cases. They transform domain structures into presentation-ready properties.
- **Use Cases**: Single-responsibility domain operations executing business rules and workflows (e.g. `CalculateAssessmentPriorityUseCase`, `GetPriorityAssessmentsUseCase`, `ScheduleAssessmentReminderUseCase`). Use cases depend only on repository protocols and pure domain models.
- **Repository Protocols**: Boundary abstractions defining async data contract operations. They decouple the business layer from persistence mechanisms, enabling in-memory substitution during unit testing.
- **Core Data Repositories**: Concrete implementations executing managed object context operations, fetch requests, predicates, and bidirectional model mapping.
- **Domain Models**: Immutable Swift value types (`Subject`, `Assessment`, `AssessmentTask`, `ClassSession`, `PreparationItem`, `GroupProject`, `GroupMember`, `GroupTask`) entirely independent of `NSManagedObject`.

### Error Handling

The application utilises typed domain errors defined in `DomainErrors.swift` (such as `AssessmentCreationError`, `PriorityAssessmentError`, `ClassSessionCreationError`, `TaskManagementError`, `AssessmentProgressUpdateError`, and `GroupProjectError`). Each error conforms to `LocalizedError` providing student-friendly descriptions and actionable recovery suggestions rather than exposing technical database exceptions to the presentation layer.

---

## 5. Domain Layer and Business Rules

### Assessment Priority Algorithm

Assessment urgency is computed deterministically through `CalculateAssessmentPriorityUseCase` by evaluating four distinct criteria:

1. **Completion Status**:
   Assessments marked as completed (`isCompleted == true` or `progress >= 1.0`) are never urgent and automatically receive a composite score of 0 and a `.low` priority.

2. **Due Date Imminence (Up to 50 points)**:
   - Overdue (`daysRemaining <= 0`): 50 points
   - Due within 2 days (`daysRemaining <= 2`): 40 points
   - Due within 7 days (`daysRemaining <= 7`): 25 points
   - Due within 14 days (`daysRemaining <= 14`): 15 points
   - Due after 14 days: 5 points

3. **Grade Weighting (Up to 25 points)**:
   - Heavily weighted (`weighting >= 30.0%`): 25 points
   - Moderately weighted (`weighting >= 15.0%`): 15 points
   - Minor weighting (`weighting < 15.0%`): 5 points

4. **Remaining Workload (Up to 25 points)**:
   Calculated as `estimatedWorkloadHours * max(0.0, 1.0 - progress)`:
   - High remaining effort (`remainingHours >= 15.0`): 25 points
   - Moderate remaining effort (`remainingHours >= 8.0`): 15 points
   - Low remaining effort (`remainingHours >= 3.0`): 10 points
   - Minimal remaining effort (`remainingHours < 3.0`): 5 points

#### Composite Score Thresholds

- **Critical**: Composite Score >= 75
- **High**: Composite Score 50 to 74
- **Medium**: Composite Score 30 to 49
- **Low**: Composite Score < 30

#### Deterministic Tie-Breaking

When ordering assessments in `GetPriorityAssessmentsUseCase`, ties are resolved deterministically using the following cascading criteria:

1. **Priority Level**: Higher priority ranked first (`.critical > .high > .medium > .low`).
2. **Due Date**: Earlier deadline ranked first (`lhs.dueDate < rhs.dueDate`).
3. **Weighting**: Higher grade contribution percentage ranked first (`lhs.weighting > rhs.weighting`).
4. **Title**: Alphabetical ascending comparison by title (`lhs.title.localizedCompare(rhs.title) == .orderedAscending`).

### Additional Domain Business Rules

- **Exclusion of Completed Coursework**: Completed assessments are strictly filtered out from urgent priority lists, the "Study Now" recommendation candidate pool, and notification reminder scheduling.
- **Automatic Milestone Synchronisation**: When an assessment possesses child milestone tasks (`AssessmentTask`), its completion progress is derived strictly as `completedTasksCount / totalTasksCount`. The assessment is marked `isCompleted = true` if and only if all child tasks are completed.
- **Manual Progress Restrictions**: Manual progress updates via `UpdateAssessmentProgressUseCase` are permitted only on standalone assessments with zero child tasks. Invoking manual progress updates when milestone tasks exist throws `AssessmentProgressUpdateError.manualOverrideForbidden`.
- **Validation Rules**: Empty course codes, empty titles, invalid weightings (< 0% or > 100%), negative workload hours, and inverted class time ranges throw typed domain errors.

---

## 6. Persistence — Core Data

Core Data was selected as the persistence framework for the following reasons:

- **Native Platform Framework**: Deep integration with Apple platforms and Swift concurrency without external third-party dependencies.
- **Relational Integrity**: Built-in support for entity relationships, bidirectional foreign keys, and cascading delete rules.
- **Offline Academic Access**: High-performance local SQLite storage guaranteeing uninterrupted offline access across campus environments.
- **Predicate Filtering**: Expressive `NSPredicate` query capabilities for targeted filtering on SQLite stores.
- **Thread Safety**: Robust context concurrency management via `perform` blocks on background and view contexts.

### Managed Object Entities and Relationships

The Core Data schema (`MyUniDay.xcdatamodel`) defines 8 entities:

1. **`SubjectEntity`**: Enrolled course subject (code, name, colorHex, id).
   - Relationship: One-to-many with `AssessmentEntity` (Cascade deletion).
   - Relationship: One-to-many with `ClassSessionEntity` (Cascade deletion).
2. **`AssessmentEntity`**: Assessment item (title, dueDate, estimatedWorkloadHours, isCompleted, notes, progress, weighting, id).
   - Relationship: Many-to-one with `SubjectEntity` (Nullify deletion).
   - Relationship: One-to-many with `AssessmentTaskEntity` (Cascade deletion).
3. **`AssessmentTaskEntity`**: Milestone item for an assessment (title, dueDate, isCompleted, orderIndex, id).
   - Relationship: Many-to-one with `AssessmentEntity` (Nullify deletion).
4. **`ClassSessionEntity`**: Timetabled class session (building, campus, classTypeRaw, startDate, endDate, room, id).
   - Relationship: Many-to-one with `SubjectEntity` (Nullify deletion).
   - Relationship: One-to-many with `PreparationItemEntity` (Cascade deletion).
5. **`PreparationItemEntity`**: Preparation checklist item for a class (title, notes, isCompleted, orderIndex, id).
   - Relationship: Many-to-one with `ClassSessionEntity` (Nullify deletion).
6. **`GroupProjectEntity`**: Group assignment (name, dueDate, myRole, progress, subjectId, id).
   - Relationship: One-to-many with `GroupMemberEntity` (Cascade deletion).
   - Relationship: One-to-many with `GroupTaskEntity` (Cascade deletion).
7. **`GroupMemberEntity`**: Team member (name, role, id).
   - Relationship: Many-to-one with `GroupProjectEntity` (Nullify deletion).
   - Relationship: One-to-many with `GroupTaskEntity` (Nullify deletion).
8. **`GroupTaskEntity`**: Deliverable task within a group project (title, dueDate, isCompleted, orderIndex, id).
   - Relationship: Many-to-one with `GroupProjectEntity` (Nullify deletion).
   - Relationship: Many-to-one with `GroupMemberEntity` (Nullify deletion).

### Representative Predicate Query

To efficiently query incomplete assessments due within a target window without loading unnecessary records into memory, `CoreDataAssessmentRepository` executes an `NSFetchRequest` utilising the following predicate:

```swift
let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
request.predicate = NSPredicate(
    format: "isCompleted == NO AND dueDate >= %@ AND dueDate <= %@",
    startDate as NSDate,
    endDate as NSDate
)
request.sortDescriptors = [NSSortDescriptor(keyPath: \AssessmentEntity.dueDate, ascending: true)]
```

Views and ViewModels do not directly access `NSManagedObjectContext`, `NSFetchRequest`, or `NSManagedObject` subclasses. All persistence access is strictly encapsulated within repository classes conforming to domain protocols.

---

## 7. Repository Pattern

The domain layer defines five repository abstractions:

- **`SubjectRepositoryProtocol`**: Operations to fetch, save, and delete university subjects.
- **`AssessmentRepositoryProtocol`**: Operations to fetch all assessments, query assessments by subject ID, fetch date-bounded incomplete assessments, save assessments, and delete assessments.
- **`ClassSessionRepositoryProtocol`**: Operations to fetch class sessions, retrieve upcoming classes after a timestamp, query classes for a subject, save sessions, and delete sessions.
- **`PreparationItemRepositoryProtocol`**: Operations to fetch, toggle, add, and remove class preparation items.
- **`GroupProjectRepositoryProtocol`**: Operations to fetch group projects, save projects, delete projects, and manage group deliverables.

### Benefits for Testability

By isolating data access behind Swift protocols, the application's Use Cases and ViewModels remain completely decoupled from Core Data. During unit testing, repositories are substituted with in-memory mock repositories (`MockSubjectRepository`, `MockAssessmentRepository`, `MockClassSessionRepository`, etc.). This enables fast, deterministic tests that execute without disk I/O side effects or Core Data stack initialisation overhead.

---

## 8. iOS System Extension 1 — WidgetKit

### Specification

- **Target**: `MyUniDayWidget`
- **App Group**: `group.com.vicky.MyUniDay`
- **Supported Families**: `.systemSmall`, `.systemMedium`

### Displayed Academic Information

- **Small Widget (`.systemSmall`)**:
  - Academic app branding.
  - Priority badge (Critical, High, Medium, Low).
  - Subject code and assessment title.
  - Due date urgency label.
  - Visual gradient progress bar with numerical percentage.
  - Remaining milestone count.
  - Empty state displaying "All Caught Up!" when no pending coursework exists.
- **Medium Widget (`.systemMedium`)**:
  - Two-column split interface.
  - Left column: Detailed assessment card with priority badge, subject code, title, due status, progress bar, and remaining tasks.
  - Right column: Next upcoming class card displaying subject code, session type, formatted time interval, building, and room location.
  - Dynamic empty states when classes or assessments are not scheduled.

### Data Flow

```
Core Data Persistent Store
       |
       v
Repository & Domain Use Cases (Priority & Next Class)
       |
       v
UpdateWidgetSnapshotUseCase
       |
       v
WidgetAcademicSnapshot (Codable Data Contract)
       |
       v
Shared App Group Container (group.com.vicky.MyUniDay)
       |
       v
WidgetSnapshotStore (UserDefaults App Group suite)
       |
       v
AcademicTimelineProvider (getTimeline / getSnapshot)
       |
       v
MyUniDayWidgetEntryView (SmallWidgetView / MediumWidgetView)
```

Whenever academic records change in the main app (e.g. creating an assessment, toggling a task, or updating progress), the app executes `UpdateWidgetSnapshotUseCase` and invokes `WidgetCenter.shared.reloadAllTimelines()` to ensure home screen widgets update promptly.

### Design Justification

University students frequently transition across campus between lecture halls and study spaces. The WidgetKit extension provides immediate, glanceable situational awareness directly on the Lock Screen or Home Screen, informing students where they need to be and what deadline demands attention without requiring them to launch and navigate the full application.

---

## 9. iOS System Extension 2 — Notification Content Extension

### Specification

- **Target**: `MyUniDayNotificationContent`
- **Category Identifier**: `MYUNIDAY_ASSESSMENT_REMINDER`

### Rich Notification Interface

When an assessment reminder triggers, expanding the notification presents a custom SwiftUI interface (`NotificationContentView`) embedded in a `UNNotificationContentExtension` hosting controller:

- Distinctive subject code pill and course title.
- Prominent urgency badge matching the domain priority calculation (Critical, High, Medium, Low).
- Assessment title with multi-line presentation.
- Due status label (e.g. "Overdue", "Due today", "Due in 3 days").
- Milestones completed ratio (e.g. "2 of 4 milestones done").
- Gradient progress bar reflecting coursework completion percentage.

### Data Flow

```
Domain Repositories & Assessment Prioritisation
       |
       v
ScheduleAssessmentReminderUseCase
       |
       v
AssessmentReminderPayload (Serialized Dictionary)
       |
       v
UNMutableNotificationContent (userInfo + categoryIdentifier)
       |
       v
System Notification Center (MYUNIDAY_ASSESSMENT_REMINDER)
       |
       v
NotificationViewController (UNNotificationContentExtension)
       |
       v
NotificationContentView (Custom SwiftUI Interface)
```

### Resiliency and Error Handling

- **Permission Handling**: Handled via `requestAuthorization()`; if denied by the student, `NotificationReminderError.permissionDenied` is thrown and translated into an instructional message directing the user to iOS Settings.
- **Malformed Payload Handling**: If `userInfo` is missing required keys, `AssessmentReminderPayload` safely initializes a designated fallback model (`isFallback = true`), rendering an informative placeholder banner directing the student to open the app, preventing empty views or extension crashes.

### Design Justification

Standard push and local notifications present plain text headlines that lack academic context. The Notification Content Extension allows students to evaluate due dates, remaining milestone volume, and priority status directly from the lock banner, enabling informed decisions on whether to act immediately without switching app contexts.

---

## 10. Testing

### Test Suite Results

- **Total Tests**: 121
- **Passed**: 121
- **Failed**: 0
- **Duration**: ~20.5 seconds on iOS Simulator

### Test Coverage Areas

1. **Domain Use Cases**:
   - `CalculateAssessmentPriorityUseCase`: Boundary scoring across time imminence, weightings, and workloads.
   - `GetPriorityAssessmentsUseCase`: Deterministic ordering, multi-factor tie-breaking, and exclusion of completed coursework.
   - `UpdateAssessmentProgressUseCase`: Progress clamping, completion synchronisation, and restriction of manual overrides when child tasks exist.
   - `GetNextClassUseCase`: Selection of the nearest future session and exclusion of past sessions.
   - `GetClassPreparationUseCase`: Checklist ordering and item retrieval.
   - `GetStudyNowRecommendationUseCase`: Selection of top-priority incomplete coursework.
   - `GetStudentRemindersUseCase`: Aggregation of urgent coursework, overdue items, and class prep.
   - `ManageGroupDeliverablesUseCase` & `ToggleGroupTaskUseCase`: Member assignment and task updates.
2. **Typed Domain Errors**:
   - Validation failure tests for empty codes, inverted class time ranges, and negative workload hours.
   - Verification of user-facing `errorDescription` and `recoverySuggestion` localized properties.
3. **Presentation ViewModels**:
   - `DashboardViewModel`: Data coordination, loading, empty states, and refresh handling.
   - `AssessmentsViewModel`: Priority sorting and subject filtering.
   - `ClassesViewModel`: Day-of-week grouping and session creation.
   - `TasksViewModel`: Toggle handling and filtering across task types.
4. **Core Data Repository Integration**:
   - In-memory Core Data persistence tests verifying CRUD operations.
   - Cascade deletion verification across subjects, assessments, classes, and group projects.
   - Date-bounded `NSPredicate` fetch execution.
5. **Extension Integration**:
   - `WidgetAcademicSnapshot`: JSON round-trip serialization, payload formatting, and store persistence.
   - `AssessmentReminderPayload`: UserInfo round-trip conversion, category identifier match, and fallback handling.

All Use Case and ViewModel unit tests utilise isolated in-memory mock repositories conforming to domain protocols, ensuring fast and isolated verification.

---

## 11. Project Structure

```
MyUniDay/
├── App/
│   ├── MyUniDayApp.swift
│   └── ContentView.swift
├── Assets.xcassets/
├── Data/
│   ├── CoreData/
│   │   ├── PersistenceController.swift
│   │   ├── CoreDataMappers.swift
│   │   └── Repositories/
│   │       ├── CoreDataSubjectRepository.swift
│   │       ├── CoreDataAssessmentRepository.swift
│   │       ├── CoreDataClassSessionRepository.swift
│   │       ├── CoreDataPreparationItemRepository.swift
│   │       └── CoreDataGroupProjectRepository.swift
│   └── Widget/
│       └── WidgetSnapshotStore.swift
├── Domain/
│   ├── Errors/
│   │   └── DomainErrors.swift
│   ├── Models/
│   │   ├── UniversitySubject.swift
│   │   ├── Assessment.swift
│   │   ├── AssessmentTask.swift
│   │   ├── AssessmentPriority.swift
│   │   ├── AssessmentProgressCalculator.swift
│   │   ├── ClassSession.swift
│   │   ├── PreparationItem.swift
│   │   ├── GroupProject.swift
│   │   ├── GroupMember.swift
│   │   ├── GroupTask.swift
│   │   ├── StudentReminderItem.swift
│   │   ├── WidgetAcademicSnapshot.swift
│   │   ├── AssessmentReminderPayload.swift
│   │   └── AcademicDataNotifications.swift
│   ├── Repositories/
│   │   ├── SubjectRepositoryProtocol.swift
│   │   ├── AssessmentRepositoryProtocol.swift
│   │   ├── ClassSessionRepositoryProtocol.swift
│   │   ├── PreparationItemRepositoryProtocol.swift
│   │   ├── GroupProjectRepositoryProtocol.swift
│   │   └── RepositoryError.swift
│   ├── Services/
│   │   └── NotificationSchedulingService.swift
│   └── UseCases/
│       ├── CalculateAssessmentPriorityUseCase.swift
│       ├── GetPriorityAssessmentsUseCase.swift
│       ├── UpdateAssessmentProgressUseCase.swift
│       ├── CreateAssessmentUseCase.swift
│       ├── GetSubjectsUseCase.swift
│       ├── CreateSubjectUseCase.swift
│       ├── GetAllClassesUseCase.swift
│       ├── GetNextClassUseCase.swift
│       ├── CreateClassSessionUseCase.swift
│       ├── GetClassPreparationUseCase.swift
│       ├── GetStudentTasksUseCase.swift
│       ├── CreateTaskUseCase.swift
│       ├── ToggleTaskCompletionUseCase.swift
│       ├── GetStudyNowRecommendationUseCase.swift
│       ├── CalculateAcademicProgressUseCase.swift
│       ├── GetStudentRemindersUseCase.swift
│       ├── GetGroupProjectsUseCase.swift
│       ├── SaveGroupProjectUseCase.swift
│       ├── DeleteGroupProjectUseCase.swift
│       ├── ManageGroupDeliverablesUseCase.swift
│       ├── ToggleGroupTaskUseCase.swift
│       ├── ScheduleAssessmentReminderUseCase.swift
│       └── UpdateWidgetSnapshotUseCase.swift
├── Presentation/
│   ├── Composition/
│   │   └── AppDependencyContainer.swift
│   ├── Models/
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift
│   │   ├── AssessmentsViewModel.swift
│   │   ├── ClassesViewModel.swift
│   │   ├── TasksViewModel.swift
│   │   ├── GroupWorkViewModel.swift
│   │   └── RemindersViewModel.swift
│   └── Views/
│       ├── MainTabView.swift
│       ├── DashboardView.swift
│       ├── AssessmentsView.swift
│       ├── AssessmentDetailView.swift
│       ├── AddAssessmentView.swift
│       ├── PriorityAssessmentsView.swift
│       ├── ClassesView.swift
│       ├── ClassDetailView.swift
│       ├── AddClassView.swift
│       ├── PrepareView.swift
│       ├── TasksView.swift
│       ├── AddTaskView.swift
│       ├── StudyNowView.swift
│       ├── MyProgressView.swift
│       ├── SubjectsView.swift
│       ├── GroupWorkView.swift
│       ├── CreateGroupProjectView.swift
│       ├── EditGroupProjectView.swift
│       ├── GroupProjectDetailView.swift
│       ├── RemindersView.swift
│       ├── MoreView.swift
│       ├── SupportView.swift
│       └── Components/
├── MyUniDay.xcdatamodeld/
│   └── MyUniDay.xcdatamodel/
├── MyUniDay.entitlements
├── MyUniDayWidget/
│   ├── MyUniDayWidget.swift
│   ├── WidgetAcademicSnapshot.swift
│   ├── WidgetSnapshotStore.swift
│   └── MyUniDayWidget.entitlements
├── MyUniDayWidget-Info.plist
├── MyUniDayNotificationContent/
│   ├── NotificationViewController.swift
│   ├── NotificationContentView.swift
│   └── AssessmentReminderPayload.swift
├── MyUniDayNotificationContent-Info.plist
├── MyUniDayTests/
└── MyUniDayUITests/
```

---

## 12. Setup / Running the Project

### Prerequisites

- macOS running Sonoma or later.
- Xcode 16.0 or later with iOS 18+ SDK.
- iOS Simulator (iPhone 16 / iPhone 17 running iOS 18+) or physical iOS device.

### Running the Application

1. Clone the repository to your local development machine:
   ```bash
   git clone <repository-url>
   cd MyUniDay
   ```
2. Open `MyUniDay.xcodeproj` in Xcode:
   ```bash
   open MyUniDay.xcodeproj
   ```
3. Select the `MyUniDay` scheme in the Xcode toolbar.
4. Select an iOS Simulator destination (e.g. `iPhone 17`).
5. Build and run the project (`Cmd + R`).
6. When prompted on first launch, grant notification permissions to allow deadline reminders.

### Testing the WidgetKit Extension

1. Build and run the application to ensure initial sample or student data is loaded.
2. Return to the Simulator Home Screen (`Cmd + Shift + H`).
3. Long-press on an empty area of the Home Screen to enter jiggle mode.
4. Tap the `+` button in the top corner to open the Widget Gallery.
5. Search for `MyUniDay` and select the widget.
6. Choose either the `.systemSmall` or `.systemMedium` widget family and tap **Add Widget**.
7. The widget displays the current highest-priority deadline and upcoming class information read from the App Group.

*Note*: The WidgetKit extension and the main application share data via the App Group `group.com.vicky.MyUniDay`. When running on a physical device, this capability requires an active Apple Developer signing team with App Group entitlements configured.

### Testing the Notification Content Extension

1. In the running application, navigate to the **Reminders** tab (or via the More menu).
2. Locate the **Rich Notification Testing** section.
3. Tap **Schedule Test Reminder (5s)**.
4. Immediately lock the device or swipe to the Home Screen so the notification appears while the app is backgrounded.
5. When the notification banner arrives after 5 seconds, long-press or pull down on the banner.
6. The custom `MyUniDayNotificationContent` interface expands, displaying the subject code, priority level, countdown, milestone progress bar, and completion ratios.

---

## 13. Git Workflow

Development was structured across modular feature branches corresponding to project milestones:

- `feature/domain-foundation`: Domain entities, value types, repository protocols, and Core Data stack setup.
- `feature/use-cases`: Implementation of domain use cases, priority calculation algorithms, and business rules.
- `feature/viewmodels`: Presentation ViewModels, state observers, and presentation layer models.
- `feature/ui-dashboard`: SwiftUI views, Today dashboard, custom components, and navigation hierarchy.
- `feature/core-app`: Timetable, assessments, tasks, group work, and progress views integration.
- `feature/final-integration`: WidgetKit extension, Notification Content Extension, and comprehensive test suite.

### Commit Conventions

Commits followed the Conventional Commits specification:

- `feat:` New features, architectural layers, and system extensions.
- `fix:` Bug fixes, business logic corrections, and error handling updates.
- `test:` Unit tests, repository integration tests, and extension testing.
- `docs:` Documentation, architecture guides, and project specification updates.

---

## 14. AI Use Declaration

Generative AI tools were used as development support for planning, code review, debugging guidance, test planning, documentation assistance and iterative implementation support. The application was manually built, executed, tested and verified in Xcode/Simulator, and the final implementation was reviewed against the assessment requirements.
