//
//  DomainErrors.swift
//  MyUniDay
//
//  Typed domain-specific errors for MyUniDay use cases, providing
//  student-friendly descriptions and actionable recovery suggestions.
//

import Foundation

/// Errors that can occur when querying prioritized assessments.
public enum PriorityAssessmentError: LocalizedError, Equatable, Sendable {
    case assessmentFetchFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .assessmentFetchFailed:
            return "Unable to load your prioritized assessments. Please try refreshing."
        }
    }

    public var recoverySuggestion: String? {
        "Check that your coursework is up to date or pull down to refresh."
    }
}

/// Errors that can occur when determining the student's next class session.
public enum NextClassError: LocalizedError, Equatable, Sendable {
    case scheduleUnavailable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .scheduleUnavailable:
            return "Unable to determine your upcoming class session right now."
        }
    }

    public var recoverySuggestion: String? {
        "Check your timetable to ensure your class schedule is up to date."
    }
}

/// Errors that can occur when retrieving preparation items for a class session.
public enum ClassPreparationError: LocalizedError, Equatable, Sendable {
    case checklistUnavailable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .checklistUnavailable:
            return "Unable to load class preparation checklist items."
        }
    }

    public var recoverySuggestion: String? {
        "Ensure the class session exists and try refreshing your checklist."
    }
}

/// Errors that can occur when creating or validating a coursework assessment.
public enum AssessmentCreationError: LocalizedError, Equatable, Sendable {
    case emptyTitle
    case invalidWeighting
    case invalidProgress
    case invalidWorkload
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Please enter an assessment title."
        case .invalidWeighting:
            return "Assessment weighting must be between 0% and 100%."
        case .invalidProgress:
            return "Assessment progress must be between 0% and 100%."
        case .invalidWorkload:
            return "Estimated workload hours cannot be negative."
        case .persistenceFailed:
            return "Unable to save this assessment. Please check the details and try again."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyTitle:
            return "Provide a descriptive title for your assessment."
        case .invalidWeighting:
            return "Enter a grade weighting percentage from 0 to 100."
        case .invalidProgress:
            return "Enter a completion progress value between 0% and 100%."
        case .invalidWorkload:
            return "Enter an estimated study workload of 0 or more hours."
        case .persistenceFailed:
            return "Verify that the parent subject exists and try saving again."
        }
    }
}

/// Errors that can occur when scheduling or creating a class session.
public enum ClassSessionCreationError: LocalizedError, Equatable, Sendable {
    case emptyBuilding
    case emptyRoom
    case emptyCampus
    case invalidTimeRange
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyBuilding:
            return "Please enter a building name for this class."
        case .emptyRoom:
            return "Please enter a room identifier for this class."
        case .emptyCampus:
            return "Please specify the campus location."
        case .invalidTimeRange:
            return "Class end time cannot be earlier than its start time."
        case .persistenceFailed:
            return "Unable to save this class session. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyBuilding:
            return "Enter the building where the class is conducted."
        case .emptyRoom:
            return "Enter the classroom or lecture hall identifier."
        case .emptyCampus:
            return "Select or enter your university campus."
        case .invalidTimeRange:
            return "Adjust the scheduled times so the class ends after it begins."
        case .persistenceFailed:
            return "Verify that the enrolled subject exists and try saving again."
        }
    }
}

/// Errors that can occur when creating or validating an enrolled university subject.
public enum SubjectCreationError: LocalizedError, Equatable, Sendable {
    case emptyCode
    case emptyName
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyCode:
            return "Please enter a subject code (e.g. COMP10001)."
        case .emptyName:
            return "Please enter a subject name."
        case .persistenceFailed:
            return "Unable to save this subject. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyCode:
            return "Enter your course handbook subject code."
        case .emptyName:
            return "Enter the official name of the enrolled subject."
        case .persistenceFailed:
            return "Check your input and try saving again."
        }
    }
}

/// Errors that can occur when creating, updating, or deleting assessment tasks or prep items.
public enum TaskManagementError: LocalizedError, Equatable, Sendable {
    case emptyTitle
    case assessmentNotFound
    case taskNotFound
    case sessionNotFound
    case missingParentSubject
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Task title cannot be empty."
        case .assessmentNotFound:
            return "The parent assessment could not be found."
        case .taskNotFound:
            return "The requested milestone task could not be found."
        case .sessionNotFound:
            return "The parent class session could not be found."
        case .missingParentSubject:
            return "This assessment is not linked to an enrolled subject."
        case .persistenceFailed:
            return "Unable to save task changes. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyTitle:
            return "Provide a clear description for the milestone task."
        default:
            return "Refresh your coursework view and try again."
        }
    }
}

/// Errors that can occur when toggling task or preparation item completion states.
public enum TaskToggleError: LocalizedError, Equatable, Sendable {
    case assessmentNotFound
    case taskNotFound
    case missingParentSubject
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .assessmentNotFound:
            return "The parent assessment could not be found."
        case .taskNotFound:
            return "The milestone task could not be found."
        case .missingParentSubject:
            return "This assessment is not linked to an enrolled subject."
        case .persistenceFailed:
            return "Unable to update task completion status. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        "Refresh your coursework and try again."
    }
}

/// Errors that can occur when calculating academic productivity metrics.
public enum AcademicProgressError: LocalizedError, Equatable, Sendable {
    case calculationFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .calculationFailed:
            return "Unable to calculate academic progress metrics right now."
        }
    }

    public var recoverySuggestion: String? {
        "Check your coursework list and refresh the progress overview."
    }
}

/// Errors that can occur when calculating "Study Now" recommendations.
public enum StudyRecommendationError: LocalizedError, Equatable, Sendable {
    case recommendationUnavailable(reason: String)

    public var errorDescription: String? {
        switch self {
        case .recommendationUnavailable:
            return "Unable to determine study recommendations right now."
        }
    }

    public var recoverySuggestion: String? {
        "Ensure your upcoming assessments are up to date and try again."
    }
}

/// Errors that can occur when updating manual progress on an assessment.
public enum AssessmentProgressUpdateError: LocalizedError, Equatable, Sendable {
    case assessmentNotFound
    case missingParentSubject
    case invalidProgressRange(progress: Double)
    case manualOverrideForbidden(taskCount: Int)
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .assessmentNotFound:
            return "Assessment could not be found."
        case .missingParentSubject:
            return "Assessment is not linked to an enrolled subject."
        case .invalidProgressRange(let progress):
            return "Assessment progress must be between 0% and 100% (received \(Int(progress * 100))%)."
        case .manualOverrideForbidden(let count):
            return "Cannot manually set progress because this assessment has \(count) milestone tasks. Complete the tasks to advance progress."
        case .persistenceFailed:
            return "Unable to save assessment progress. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .manualOverrideForbidden:
            return "Check off your breakdown tasks to update progress automatically."
        case .invalidProgressRange:
            return "Provide a progress percentage between 0 and 100."
        default:
            return "Please refresh your coursework and try again."
        }
    }
}

/// Errors that can occur during group project management.
public enum GroupProjectError: LocalizedError, Equatable, Sendable {
    case emptyName
    case projectNotFound
    case taskNotFound
    case memberNotFound
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Please enter a group project name."
        case .projectNotFound:
            return "The group project could not be found."
        case .taskNotFound:
            return "The group task could not be found."
        case .memberNotFound:
            return "The team member could not be found."
        case .persistenceFailed:
            return "Unable to save group project changes. Please try again."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyName:
            return "Enter a name for your group project."
        default:
            return "Refresh the group project list and try again."
        }
    }
}
