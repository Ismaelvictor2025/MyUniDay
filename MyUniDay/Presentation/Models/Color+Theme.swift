//
//  Color+Theme.swift
//  MyUniDay
//
//  Semantic colour and icon extensions supporting the MyUniDay visual theme.
//

import SwiftUI

extension Color {
    /// Warm amber gold accent used for preparation, readiness, and study alerts.
    public static let amber = Color(red: 0.96, green: 0.65, blue: 0.12)
}

extension ShapeStyle where Self == Color {
    /// ShapeStyle conformance enabling `.foregroundStyle(.amber)`.
    public static var amber: Color {
        Color.amber
    }
}

extension ClassType {
    /// Associated SF Symbol name representing each university class format.
    public var iconName: String {
        switch self {
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
