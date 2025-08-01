import Foundation
import UIKit

// MARK: - Maintenance V2 Models

enum MaintenanceCategory: String, Codable, CaseIterable {
  case hvac
  case electrical
  case plumbing
  case kitchen
  case doors_windows
  case refrigeration
  case flooring
  case painting
  case cleaning
  case other
  
  var displayName: String {
    switch self {
    case .hvac: return "HVAC"
    case .electrical: return "Electrical"
    case .plumbing: return "Plumbing"
    case .kitchen: return "Kitchen"
    case .doors_windows: return "Doors & Windows"
    case .refrigeration: return "Refrigeration"
    case .flooring: return "Flooring"
    case .painting: return "Painting"
    case .cleaning: return "Cleaning"
    case .other: return "Other"
    }
  }
}

enum MaintenancePriority: String, Codable { case low, medium, high }

enum RequestStatus: String, Codable { case reported, in_progress, completed }

struct MaintenanceRequest: Identifiable, Codable {
  let id: String
  let businessId: String
  let locationId: String?
  let reporterId: String
  var assigneeId: String?
  
  // Details
  var title: String
  var description: String
  var category: MaintenanceCategory
  var priority: MaintenancePriority
  var status: RequestStatus
  
  // AI
  var aiAnalysis: AIAnalysis?
  var estimatedCost: Double?
  var estimatedTime: String?
  
  // Photos
  var photoUrls: [String]?
  
  // Scheduling
  var scheduledAt: Date?
  var startedAt: Date?
  var completedAt: Date?
  
  // Costs
  var quotedCost: Double?
  var actualCost: Double?
  
  // Meta
  let createdAt: Date
  var updatedAt: Date
  
  init(
    id: String = UUID().uuidString,
    businessId: String,
    locationId: String? = nil,
    reporterId: String,
    assigneeId: String? = nil,
    title: String,
    description: String,
    category: MaintenanceCategory,
    priority: MaintenancePriority = .medium,
    status: RequestStatus = .reported,
    aiAnalysis: AIAnalysis? = nil,
    estimatedCost: Double? = nil,
    estimatedTime: String? = nil,
    photoUrls: [String]? = nil,
    scheduledAt: Date? = nil,
    startedAt: Date? = nil,
    completedAt: Date? = nil,
    quotedCost: Double? = nil,
    actualCost: Double? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.businessId = businessId
    self.locationId = locationId
    self.reporterId = reporterId
    self.assigneeId = assigneeId
    self.title = title
    self.description = description
    self.category = category
    self.priority = priority
    self.status = status
    self.aiAnalysis = aiAnalysis
    self.estimatedCost = estimatedCost
    self.estimatedTime = estimatedTime
    self.photoUrls = photoUrls
    self.scheduledAt = scheduledAt
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.quotedCost = quotedCost
    self.actualCost = actualCost
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

struct RequestUpdate: Identifiable, Codable {
  let id: String
  let requestId: String
  let authorId: String
  var message: String
  let createdAt: Date
  
  init(id: String = UUID().uuidString, requestId: String, authorId: String, message: String, createdAt: Date = Date()) {
    self.id = id
    self.requestId = requestId
    self.authorId = authorId
    self.message = message
    self.createdAt = createdAt
  }
}

struct MaintenancePhoto: Identifiable, Codable {
  let id: String
  let requestId: String
  let url: String
  var thumbUrl: String?
  let takenAt: Date
}
