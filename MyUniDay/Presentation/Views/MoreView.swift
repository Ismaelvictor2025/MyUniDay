//
//  MoreView.swift
//  MyUniDay
//
//  Application information, development demo status, privacy, and accessibility settings.
//

import SwiftUI

public struct MoreView: View {
#if DEBUG
    public var isDemoMode: Bool = false
    public var onSwitchMode: ((Bool) -> Void)?

    public init(
        isDemoMode: Bool = false,
        onSwitchMode: ((Bool) -> Void)? = nil
    ) {
        self.isDemoMode = isDemoMode
        self.onSwitchMode = onSwitchMode
    }
#else
    public init() {}
#endif

    public var body: some View {
        List {
            // App Identity & About
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text("MyUniDay")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Your university, organised.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Version 1.0 (MVP)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            #if DEBUG
            // Development Mode Section
            Section("Development & Demo Mode") {
                HStack {
                    Label("Current Data Store", systemImage: isDemoMode ? "play.circle.fill" : "internaldrive.fill")
                        .foregroundStyle(isDemoMode ? .green : .blue)
                    Spacer()
                    Text(isDemoMode ? "Demo Mode" : "Live Store")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isDemoMode ? .green : .secondary)
                }

                Button {
                    onSwitchMode?(!isDemoMode)
                } label: {
                    Label(
                        isDemoMode ? "Switch to Live Core Data Store" : "Switch to Demo Mode Data",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            }
            #endif

            // Productivity & Student Mission
            Section("About MyUniDay") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The University Command Centre")
                        .font(.headline)
                    Text("MyUniDay was created to eliminate the friction caused by university information being scattered across separate timetables, learning management systems, and checklists. It answers four core questions every day:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)

                    VStack(alignment: .leading, spacing: 4) {
                        bullet("What should I prioritise?")
                        bullet("Where do I need to be next?")
                        bullet("What do I need to prepare?")
                        bullet("What should I work on right now?")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            // Local Data & Privacy
            Section("Data & Privacy") {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("100% Local Storage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("All assessments, timetable sessions, and checklists are saved locally on your device via Core Data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                }
            }

            // Accessibility Features
            Section("Accessibility & Experience") {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dynamic Type & VoiceOver")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("All labels, buttons, and badges support system text resizing and VoiceOver accessibility labels.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "figure.arms.open")
                        .foregroundStyle(.indigo)
                }

                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reduce Motion Support")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Animated graduation cap and transitions automatically pause when Reduce Motion is enabled in iOS Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .fontWeight(.bold)
                .foregroundStyle(.indigo)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
