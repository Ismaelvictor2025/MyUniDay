//
//  AcademicDataNotifications.swift
//  MyUniDay
//
//  Central notification identifier alerting all ViewModels when coursework,
//  milestones, preparation items, or assessments are mutated.
//

import Foundation

extension Notification.Name {
    /// Notification posted whenever coursework data (assessments, tasks, preparation items)
    /// is created, modified, completed, or deleted across the application.
    public static let academicDataDidChange = Notification.Name("academicDataDidChange")
}
