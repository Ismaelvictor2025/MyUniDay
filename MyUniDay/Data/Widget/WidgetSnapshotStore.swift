//
//  WidgetSnapshotStore.swift
//  MyUniDay
//
//  Persistence store for the shared WidgetAcademicSnapshot using App Group storage.
//

import Foundation

/// Manages persistence of `WidgetAcademicSnapshot` across the main app and WidgetKit extension.
public final class WidgetSnapshotStore: Sendable {
    public static let defaultAppGroupIdentifier = "group.com.vicky.MyUniDay"
    public static let snapshotKey = "myuniday_widget_academic_snapshot"
    public static let snapshotFileName = "widget_academic_snapshot.json"

    public static let shared = WidgetSnapshotStore()

    public let appGroupIdentifier: String
    private let userDefaults: UserDefaults?
    private let containerURL: URL?

    public init(appGroupIdentifier: String = defaultAppGroupIdentifier) {
        self.appGroupIdentifier = appGroupIdentifier
        self.userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        self.containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    public var isAppGroupAccessible: Bool {
        return userDefaults != nil || containerURL != nil
    }

    public var fileURL: URL? {
        containerURL?.appendingPathComponent(Self.snapshotFileName)
    }

    /// Persists the academic snapshot to the shared App Group container.
    @discardableResult
    public func save(snapshot: WidgetAcademicSnapshot) -> Bool {
        guard let encoded = try? JSONEncoder().encode(snapshot) else {
            #if DEBUG
            print("[WidgetSync] App Group snapshot write failure: JSON encoding failed")
            #endif
            return false
        }

        var writeSuccess = false

        // 1. Write to App Group UserDefaults
        if let defaults = userDefaults {
            defaults.set(encoded, forKey: Self.snapshotKey)
            defaults.synchronize()
            writeSuccess = true
        }

        // 2. Write to App Group shared container directory file
        if let fileURL = fileURL {
            do {
                try encoded.write(to: fileURL, options: .atomic)
                writeSuccess = true
            } catch {
                #if DEBUG
                print("[WidgetSync] App Group file write error: \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        if writeSuccess {
            print("[WidgetSync] App Group snapshot write success to suite '\(appGroupIdentifier)'")
        } else {
            print("[WidgetSync] App Group snapshot write failure: neither UserDefaults suite nor file container was accessible for '\(appGroupIdentifier)'")
        }
        #endif

        return writeSuccess
    }

    /// Loads the latest academic snapshot from the shared App Group container.
    public func load() -> WidgetAcademicSnapshot {
        // 1. Try App Group UserDefaults
        if let defaults = userDefaults,
           let data = defaults.data(forKey: Self.snapshotKey),
           let snapshot = try? JSONDecoder().decode(WidgetAcademicSnapshot.self, from: data) {
            #if DEBUG
            print("[WidgetTimeline] Widget TimelineProvider read success from UserDefaults: '\(snapshot.priorityAssessmentTitle ?? "none")'")
            #endif
            return snapshot
        }

        // 2. Try App Group shared file
        if let fileURL = fileURL,
           let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder().decode(WidgetAcademicSnapshot.self, from: data) {
            #if DEBUG
            print("[WidgetTimeline] Widget TimelineProvider read success from file: '\(snapshot.priorityAssessmentTitle ?? "none")'")
            #endif
            return snapshot
        }

        #if DEBUG
        print("[WidgetTimeline] Widget TimelineProvider read: no snapshot found in '\(appGroupIdentifier)', returning .empty")
        #endif

        return .empty
    }

    /// Clears any persisted snapshot (useful for testing empty states).
    public func clear() {
        userDefaults?.removeObject(forKey: Self.snapshotKey)
        userDefaults?.synchronize()
        if let fileURL = fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
