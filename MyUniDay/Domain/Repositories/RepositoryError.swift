//
//  RepositoryError.swift
//  MyUniDay
//
//  Defines domain-level persistence errors.
//

import Foundation

/// Errors that can occur during domain repository persistence operations.
public enum RepositoryError: Error, LocalizedError, Equatable {
    case notFound(id: UUID)
    case invalidData(reason: String)
    case underlying(description: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Item with identifier \(id.uuidString) was not found."
        case .invalidData(let reason):
            return "Invalid data encountered: \(reason)"
        case .underlying(let description):
            return "Persistence operation failed: \(description)"
        }
    }
}
