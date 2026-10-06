//
//  MyUniDayWidget.swift
//  MyUniDayWidget
//
//  WidgetKit extension presenting high-priority academic deadlines and upcoming
//  classes from the shared App Group container (group.com.vicky.MyUniDay).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
public struct AcademicEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetAcademicSnapshot

    public init(date: Date, snapshot: WidgetAcademicSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

// MARK: - Timeline Provider
public struct AcademicTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> AcademicEntry {
        AcademicEntry(date: Date(), snapshot: .previewSample)
    }

    public func getSnapshot(in context: Context, completion: @escaping (AcademicEntry) -> Void) {
        if context.isPreview {
            completion(AcademicEntry(date: Date(), snapshot: .previewSample))
        } else {
            let snapshot = WidgetSnapshotStore.shared.load()
            completion(AcademicEntry(date: Date(), snapshot: snapshot.hasAssessment ? snapshot : .previewSample))
        }
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<AcademicEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.shared.load()
        #if DEBUG
        if snapshot.hasAssessment || snapshot.hasUpcomingClass {
            print("[WidgetTimeline] Widget TimelineProvider read success: title='\(snapshot.priorityAssessmentTitle ?? "none")', progress=\(snapshot.progressPercentageString), tasks=\(snapshot.remainingTaskCount), nextClass='\(snapshot.nextClassSubjectCode ?? "none")'")
        } else {
            print("[WidgetTimeline] Widget TimelineProvider read failure: no active assessment or class found in snapshot (displaying empty state)")
        }
        #endif
        let currentEntry = AcademicEntry(date: Date(), snapshot: snapshot)

        // Schedule next reload in 15 minutes or when the upcoming class starts
        var nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        if let classStart = snapshot.nextClassStartTime, classStart > Date(), classStart < nextUpdate {
            nextUpdate = classStart
        }

        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Entry View
public struct MyUniDayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    public let entry: AcademicEntry

    public init(entry: AcademicEntry) {
        self.entry = entry
    }

    public var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(snapshot: entry.snapshot)
            case .systemMedium:
                MediumWidgetView(snapshot: entry.snapshot)
            default:
                SmallWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackgroundView()
        }
    }
}

// MARK: - Background View
private struct WidgetBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 16/255, green: 28/255, blue: 58/255), // Dark Navy
                Color(red: 25/255, green: 45/255, blue: 90/255)  // Deep Royal Blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - System Small Widget View (.systemSmall)
private struct SmallWidgetView: View {
    let snapshot: WidgetAcademicSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Brand & Cap
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("MYUNIDAY")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1.0)
                }

                Spacer()

                if snapshot.hasAssessment, let priority = snapshot.priorityLevel {
                    PriorityBadgeView(priority: priority)
                }
            }

            if snapshot.hasAssessment {
                // Assessment Content
                VStack(alignment: .leading, spacing: 2) {
                    if let code = snapshot.subjectCode {
                        Text(code)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                    }

                    Text(snapshot.priorityAssessmentTitle ?? "Assessment")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Due date
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(snapshot.dueDescription)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.85))

                // Progress Bar
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width * CGFloat(snapshot.progress), geo.size.width)))
                        }
                    }
                    .frame(height: 5)

                    HStack {
                        Text(snapshot.progressPercentageString)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(snapshot.tasksRemainingDescription)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Progress \(snapshot.progressPercentageString), \(snapshot.tasksRemainingDescription)")
            } else {
                // Empty state
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))

                    Text("All Caught Up!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text("No pending deadlines")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
            }
        }
        .padding(12)
    }
}

// MARK: - System Medium Widget View (.systemMedium)
private struct MediumWidgetView: View {
    let snapshot: WidgetAcademicSnapshot

    var body: some View {
        HStack(spacing: 12) {
            // Left Column: Priority Assessment (approx 55%)
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("MYUNIDAY")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(1.0)
                    }

                    Spacer()

                    if snapshot.hasAssessment, let priority = snapshot.priorityLevel {
                        PriorityBadgeView(priority: priority)
                    }
                }

                if snapshot.hasAssessment {
                    VStack(alignment: .leading, spacing: 2) {
                        if let code = snapshot.subjectCode {
                            Text(code)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                        }

                        Text(snapshot.priorityAssessmentTitle ?? "Assessment")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    // Due date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 10))
                        Text(snapshot.dueDescription)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))

                    // Progress bar
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.18))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.pink, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, min(geo.size.width * CGFloat(snapshot.progress), geo.size.width)))
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text(snapshot.progressPercentageString)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(snapshot.tasksRemainingDescription)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                } else {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                        Text("All Caught Up!")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("No pending coursework")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right Column: Next Class (approx 45%)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                    Text("NEXT CLASS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                        .tracking(0.8)
                }

                if snapshot.hasUpcomingClass {
                    VStack(alignment: .leading, spacing: 2) {
                        if let subject = snapshot.nextClassSubjectCode {
                            Text(subject)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }

                        if let type = snapshot.nextClassType {
                            Text(type)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    Spacer(minLength: 0)

                    if let time = snapshot.classTimeString {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                            Text(time)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }

                    if let loc = snapshot.classLocationString {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 9))
                            Text(loc)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white.opacity(0.75))
                    }
                } else {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                        Text("No Classes Today")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Enjoy your study time")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

// MARK: - Priority Badge View
private struct PriorityBadgeView: View {
    let priority: String

    private var priorityColor: Color {
        switch priority.lowercased() {
        case "critical":
            return .red
        case "high":
            return .orange
        case "medium":
            return .blue
        case "low":
            return .teal
        default:
            return .gray
        }
    }

    private var iconName: String {
        switch priority.lowercased() {
        case "critical":
            return "flame.fill"
        case "high":
            return "exclamationmark.circle.fill"
        default:
            return "circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 7))
            Text(priority.uppercased())
                .font(.system(size: 8, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(priorityColor.opacity(0.85))
        .clipShape(Capsule())
        .accessibilityLabel("Priority \(priority)")
    }
}

// MARK: - Widget Configuration
public struct MyUniDayWidget: Widget {
    public let kind: String = "MyUniDayWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AcademicTimelineProvider()) { entry in
            MyUniDayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MyUniDay Academic Summary")
        .description("View your highest-priority assessment deadline and upcoming class schedule at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle
@main
struct MyUniDayWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyUniDayWidget()
    }
}
