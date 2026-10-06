//
//  NotificationContentView.swift
//  MyUniDayNotificationContent
//
//  SwiftUI custom interface for MyUniDay rich academic notifications.
//

import SwiftUI

public struct NotificationContentView: View {
    public let payload: AssessmentReminderPayload

    public init(payload: AssessmentReminderPayload) {
        self.payload = payload
    }

    public var body: some View {
        Group {
            if payload.isFallback {
                fallbackView
            } else {
                fullContentView
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 16/255, green: 28/255, blue: 58/255), // Dark Navy
                    Color(red: 25/255, green: 45/255, blue: 90/255)  // Deep Royal Blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            payload.isFallback
                ? "MyUniDay Assessment Reminder. Open MyUniDay to view the latest coursework details."
                : "MyUniDay Assessment Due Soon: \(payload.assessmentTitle), \(payload.subjectCode), \(payload.priority) Priority, \(payload.formattedDueDate), \(payload.formattedProgress), \(payload.formattedTasksRemaining)"
        )
    }

    private var fallbackView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Brand Identity & Due Alert Badge
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("MYUNIDAY")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .tracking(1.2)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("ASSESSMENT REMINDER")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundColor(Color(red: 255/255, green: 215/255, blue: 110/255))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.18))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Assessment Reminder")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Text("Open MyUniDay to view the latest coursework details.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.top, 4)
        }
    }

    private var fullContentView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Brand Identity & Due Alert Badge
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("MYUNIDAY")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .tracking(1.2)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("ASSESSMENT DUE SOON")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundColor(Color(red: 255/255, green: 215/255, blue: 110/255))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.18))
                .clipShape(Capsule())
            }

            // Subject Code & Assessment Title
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(payload.subjectCode)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 175/255, green: 205/255, blue: 255/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    if let subjectName = payload.subjectName, !subjectName.isEmpty {
                        Text(subjectName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    Spacer()

                    PriorityBadge(priority: payload.priority)
                }

                Text(payload.assessmentTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Due Date & Timing
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))

                Text(payload.formattedDueDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11))
                    Text(payload.formattedTasksRemaining)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Progress Bar & Percentage
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.20))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.purple, Color.indigo],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width * CGFloat(payload.progress), geo.size.width)))
                    }
                }
                .frame(height: 7)

                HStack {
                    Text(payload.formattedProgress)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    if payload.totalTaskCount > 0 {
                        let completedCount = max(0, payload.totalTaskCount - payload.remainingTaskCount)
                        Text("\(completedCount) of \(payload.totalTaskCount) milestones done")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
            }
        }
    }
}

// MARK: - Priority Badge Subview
private struct PriorityBadge: View {
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
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 9))
            Text("\(priority.uppercased()) PRIORITY")
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(priorityColor.opacity(0.85))
        .clipShape(Capsule())
    }
}

#Preview {
    NotificationContentView(payload: .previewSample)
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
