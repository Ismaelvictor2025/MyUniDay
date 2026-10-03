//
//  NextClassCard.swift
//  MyUniDay
//
//  Presentation card displaying details of the next upcoming class session.
//

import SwiftUI

/// Card displaying the student's next scheduled class session with clear visual hierarchy,
/// time range, relative commencement pill, and location details.
public struct NextClassCard: View {
    public let session: ClassSession
    public let subjectName: String?

    public init(session: ClassSession, subjectName: String? = nil) {
        self.session = session
        self.subjectName = subjectName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Class Type, Subject & Relative Time
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: iconForClassType(session.classType))
                        .font(.caption)
                    Text(session.classType.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(.indigo)
                .background(Color.indigo.opacity(0.12))
                .clipShape(Capsule())

                if let subject = subjectName, !subject.isEmpty {
                    Text(subject)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                relativeTimePill
            }

            // Time & Location Details
            HStack(spacing: 20) {
                // Time Column
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.indigo)
                        Text(timeRangeFormatted)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                Divider()
                    .frame(height: 32)

                // Location Column
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCATION")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.indigo)
                        Text("\(session.building), \(session.room)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
            }

            // Campus Footnote
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(session.campus) Campus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [Color.indigo.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1.5)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.classType.rawValue), \(timeRangeFormatted), located at \(session.building), \(session.room), \(session.campus) Campus")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var relativeTimePill: some View {
        let info = relativeTimeInfo
        HStack(spacing: 4) {
            Circle()
                .fill(info.isNow ? Color.green : Color.indigo)
                .frame(width: 6, height: 6)
            Text(info.text)
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var relativeTimeInfo: (text: String, isNow: Bool) {
        let diff = Int(session.startDate.timeIntervalSince(Date()))
        if diff <= 0 {
            return ("Happening now", true)
        } else if diff < 3600 {
            let mins = max(1, diff / 60)
            return ("In \(mins)m", false)
        } else if diff < 86400 {
            let hours = diff / 3600
            return ("In \(hours)h", false)
        } else {
            return ("Upcoming", false)
        }
    }

    private var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: session.startDate)
        let end = formatter.string(from: session.endDate)
        return "\(start) – \(end)"
    }

    private func iconForClassType(_ type: ClassType) -> String {
        switch type {
        case .lecture: return "person.wave.2.fill"
        case .tutorial: return "bubble.left.and.bubble.right.fill"
        case .lab: return "desktopcomputer"
        case .workshop: return "wrench.and.screwdriver.fill"
        case .seminar: return "text.book.closed.fill"
        case .studio: return "paintbrush.pointed.fill"
        case .other: return "calendar"
        }
    }
}

#Preview {
    NextClassCard(
        session: ClassSession(
            classType: .workshop,
            startDate: Date().addingTimeInterval(3600 * 2),
            endDate: Date().addingTimeInterval(3600 * 4),
            campus: "City",
            building: "Building EA",
            room: "Room 15"
        ),
        subjectName: "Object Oriented Programming"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
