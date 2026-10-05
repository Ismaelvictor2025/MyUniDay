//
//  SupportView.swift
//  MyUniDay
//
//  University-neutral support framework connecting students to academic skills,
//  wellbeing services, accessibility assistance, and urgent crisis contacts.
//

import SwiftUI

public struct SupportView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                HStack(spacing: 8) {
                    Image(systemName: "lifepreserver.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STUDENT SUPPORT")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(.red)
                            .tracking(1.2)
                        Text("University assistance services framework")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Emergency & Urgent Help Section
                urgentHelpBanner

                // Support Services Categories
                VStack(alignment: .leading, spacing: 14) {
                    Text("CAMPUS SERVICES DIRECTORY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    serviceCard(
                        title: "Academic & Learning Support",
                        description: "Writing centres, mathematics & statistics drop-in hubs, referencing guides, and study skills consultation.",
                        icon: "graduationcap.fill",
                        tint: .indigo,
                        tags: ["Essay Review", "Maths Help", "Study Skills"]
                    )

                    serviceCard(
                        title: "Wellbeing & Mental Health",
                        description: "Free and confidential student counselling, stress management workshops, mindfulness sessions, and peer mentor networks.",
                        icon: "heart.fill",
                        tint: .pink,
                        tags: ["Counselling", "Mindfulness", "Peer Mentoring"]
                    )

                    serviceCard(
                        title: "Accessibility & Disability Services",
                        description: "Academic adjustment plans, alternative exam arrangements, assistive software licenses, and note-taking support.",
                        icon: "figure.walk.motion",
                        tint: .blue,
                        tags: ["Exam Adjustments", "Assistive Tech", "Special Consideration"]
                    )

                    serviceCard(
                        title: "Student Services & IT Helpdesk",
                        description: "Enrolment queries, timetable clashes, student card replacement, LMS technical issues, and campus Wi-Fi configuration.",
                        icon: "laptopcomputer",
                        tint: .teal,
                        tags: ["Enrolment", "LMS Access", "Campus Wi-Fi"]
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var urgentHelpBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                    Text("URGENT / CRISIS SUPPORT")
                        .fontWeight(.bold)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.25))
                .clipShape(Capsule())

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Need Immediate Help?")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("If you or someone around you is in immediate danger or distress:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 6) {
                urgentRow(label: "Emergency Services", value: "Call 000 / 911 / 112")
                urgentRow(label: "Campus Security", value: "Available 24/7 via your student safety app or campus phone")
                urgentRow(label: "Lifeline Crisis Line", value: "Free, confidential 24/7 telephone crisis support")
            }
            .padding(10)
            .background(Color.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.red, Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.red.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private func urgentRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(value)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func serviceCard(
        title: String,
        description: String,
        icon: String,
        tint: Color,
        tags: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 32)

                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Spacer()
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
