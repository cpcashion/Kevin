import Foundation

enum Role: String, Codable { case gm, owner, tech, admin }

// MARK: - Admin Configuration
struct AdminConfig {
  static let adminEmails = [
    "chriscashion@gmail.com",
    "chris.cashion@gmail.com",
    "kevind.cashion@gmail.com"
  ]
  
  static func isAdmin(email: String?) -> Bool {
    guard let email = email else { return false }
    return adminEmails.contains(email.lowercased())
  }
}

struct AppUser: Identifiable, Codable, Equatable {
  let id: String
  var role: Role
  var name: String
  var phone: String?
  var email: String?
}

enum VerificationStatus: String, Codable {
  case pending, verified, failed, disputed
  
  var displayName: String {
    switch self {
    case .pending: return "Pending Verification"
    case .verified: return "Verified"
    case .failed: return "Verification Failed"
    case .disputed: return "Under Review"
    }
  }
}

enum VerificationMethod: String, Codable {
  case gmb_oauth, phone, document, manual
  
  var displayName: String {
    switch self {
    case .gmb_oauth: return "Google My Business"
    case .phone: return "Phone Verification"
    case .document: return "Document Upload"
    case .manual: return "Manual Review"
    }
  }
}

enum BusinessType: String, Codable, CaseIterable {
  case restaurant = "restaurant"
  case cafe = "cafe"
  case bar = "bar"
  case retail = "retail"
  case hotel = "hotel"
  case gym = "gym"
  case salon = "salon"
  case clinic = "clinic"
  case office = "office"
  case warehouse = "warehouse"
  case gasStation = "gas_station"
  case grocery = "grocery"
  case pharmacy = "pharmacy"
  case healthcare = "healthcare"
  case financial = "financial"
  case fitness = "fitness"
  case automotive = "automotive"
  case other = "other"
  
  var displayName: String {
    switch self {
    case .restaurant: return "Restaurant"
    case .cafe: return "Cafe"
    case .bar: return "Bar"
    case .retail: return "Retail Store"
    case .hotel: return "Hotel"
    case .gym: return "Gym/Fitness"
    case .salon: return "Salon/Spa"
    case .clinic: return "Medical Clinic"
    case .office: return "Office"
    case .warehouse: return "Warehouse"
    case .gasStation: return "Gas Station"
    case .grocery: return "Grocery"
    case .pharmacy: return "Pharmacy"
    case .healthcare: return "Healthcare"
    case .financial: return "Bank/ATM"
    case .fitness: return "Fitness"
    case .automotive: return "Automotive"
    case .other: return "Other Business"
    }
  }
  
  var icon: String {
    switch self {
    case .restaurant: return "🍽️"
    case .cafe: return "☕"
    case .bar: return "🍺"
    case .retail: return "🛍️"
    case .hotel: return "🏨"
    case .gym: return "💪"
    case .salon: return "💅"
    case .clinic: return "🏥"
    case .office: return "🏢"
    case .warehouse: return "📦"
    case .gasStation: return "⛽"
    case .grocery: return "🛒"
    case .pharmacy: return "💊"
    case .healthcare: return "🏥"
    case .financial: return "🏦"
    case .fitness: return "💪"
    case .automotive: return "🚗"
    case .other: return "🏢"
    }
  }
  
  var color: String {
    switch self {
    case .restaurant: return "#FF6B6B"
    case .cafe: return "#8B4513"
    case .bar: return "#9B59B6"
    case .retail: return "#F7DC6F"
    case .hotel: return "#98D8C8"
    case .gym: return "#BB8FCE"
    case .salon: return "#F8C471"
    case .clinic: return "#FFEAA7"
    case .office: return "#BDC3C7"
    case .warehouse: return "#85929E"
    case .gasStation: return "#4ECDC4"
    case .grocery: return "#45B7D1"
    case .pharmacy: return "#96CEB4"
    case .healthcare: return "#FFEAA7"
    case .financial: return "#DDA0DD"
    case .fitness: return "#BB8FCE"
    case .automotive: return "#85C1E9"
    case .other: return "#BDC3C7"
    }
  }
  
  // Convert Google Places API types to BusinessType
  static func fromGooglePlaceTypes(_ types: [String]) -> BusinessType {
    // Check for specific business types based on Google Places types
    // Priority order matters - check most specific types first
    for type in types {
      switch type.lowercased() {
      // Food & Dining
      case "restaurant", "meal_takeaway", "meal_delivery", "food":
        return .restaurant
      case "cafe", "bakery", "coffee_shop":
        return .cafe
      case "bar", "night_club", "liquor_store":
        return .bar
      
      // Retail & Shopping
      case "convenience_store":
        return .retail
      case "store", "shopping_mall", "clothing_store", "electronics_store", "department_store", "shoe_store", "jewelry_store", "book_store", "home_goods_store":
        return .retail
      case "grocery_or_supermarket", "supermarket":
        return .grocery
      
      // Lodging
      case "lodging", "hotel", "motel":
        return .hotel
      
      // Health & Wellness
      case "gym", "fitness", "health":
        return .gym
      case "beauty_salon", "hair_care", "spa":
        return .salon
      case "hospital", "doctor", "dentist", "veterinary_care", "physiotherapist":
        return .clinic
      case "pharmacy", "drugstore":
        return .pharmacy
      
      // Professional Services
      case "office", "real_estate_agency", "lawyer", "accounting", "insurance_agency":
        return .office
      
      // Financial
      case "bank", "atm", "finance":
        return .financial
      
      // Automotive
      case "car_dealer", "car_repair", "car_wash", "auto_parts_store":
        return .automotive
      case "gas_station", "fuel":
        return .gasStation
      
      // Storage & Logistics
      case "storage", "moving_company":
        return .warehouse
      
      default:
        continue
      }
    }
    
    // Default fallback
    return .other
  }
}

struct Business: Identifiable, Codable, Equatable {
  let id: String
  var name: String
  var businessType: BusinessType
  var address: String?
  var phone: String?
  var website: String?
  var logoUrl: String?
  var placeId: String? // Google Places ID
  var latitude: Double?
  var longitude: Double?
  var businessHours: [String: String]? // Day of week -> hours
  var category: String? // More specific category (e.g., "Italian Restaurant", "Coffee Shop")
  var priceLevel: Int? // 1-4 scale
  var rating: Double?
  var totalRatings: Int?
  var ownerId: String // User ID of the business owner
  var createdAt: Date
  var isActive: Bool
  
  // Verification fields
  var verificationStatus: VerificationStatus
  var verificationMethod: VerificationMethod?
  var verifiedAt: Date?
  var verificationData: [String: String]? // Store GMB account ID, phone number used, etc.
  
  init(
    id: String,
    name: String,
    businessType: BusinessType,
    address: String? = nil,
    phone: String? = nil,
    website: String? = nil,
    logoUrl: String? = nil,
    placeId: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    businessHours: [String: String]? = nil,
    category: String? = nil,
    priceLevel: Int? = nil,
    rating: Double? = nil,
    totalRatings: Int? = nil,
    ownerId: String,
    createdAt: Date,
    isActive: Bool,
    verificationStatus: VerificationStatus = .pending,
    verificationMethod: VerificationMethod? = nil,
    verifiedAt: Date? = nil,
    verificationData: [String: String]? = nil
  ) {
    self.id = id
    self.name = name
    self.businessType = businessType
    self.address = address
    self.phone = phone
    self.website = website
    self.logoUrl = logoUrl
    self.placeId = placeId
    self.latitude = latitude
    self.longitude = longitude
    self.businessHours = businessHours
    self.category = category
    self.priceLevel = priceLevel
    self.rating = rating
    self.totalRatings = totalRatings
    self.ownerId = ownerId
    self.createdAt = createdAt
    self.isActive = isActive
    self.verificationStatus = verificationStatus
    self.verificationMethod = verificationMethod
    self.verifiedAt = verifiedAt
    self.verificationData = verificationData
  }
}

// Keep Restaurant as a typealias for backward compatibility
typealias Restaurant = Business

extension Business {
  // Convenience initializer for restaurants
  static func restaurant(
    id: String,
    name: String,
    address: String? = nil,
    phone: String? = nil,
    website: String? = nil,
    logoUrl: String? = nil,
    placeId: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    businessHours: [String: String]? = nil,
    cuisine: String? = nil,
    priceLevel: Int? = nil,
    rating: Double? = nil,
    totalRatings: Int? = nil,
    ownerId: String,
    createdAt: Date,
    isActive: Bool,
    verificationStatus: VerificationStatus = .pending,
    verificationMethod: VerificationMethod? = nil,
    verifiedAt: Date? = nil,
    verificationData: [String: String]? = nil
  ) -> Business {
    return Business(
      id: id,
      name: name,
      businessType: .restaurant,
      address: address,
      phone: phone,
      website: website,
      logoUrl: logoUrl,
      placeId: placeId,
      latitude: latitude,
      longitude: longitude,
      businessHours: businessHours,
      category: cuisine,
      priceLevel: priceLevel,
      rating: rating,
      totalRatings: totalRatings,
      ownerId: ownerId,
      createdAt: createdAt,
      isActive: isActive,
      verificationStatus: verificationStatus,
      verificationMethod: verificationMethod,
      verifiedAt: verifiedAt,
      verificationData: verificationData
    )
  }
}

struct Location: Identifiable, Codable, Equatable {
  let id: String
  var businessId: String // Changed from restaurantId to businessId
  var name: String
  var address: String?
  var latitude: Double?
  var longitude: Double?
  var phone: String?
  
  // Keep restaurantId for backward compatibility
  var restaurantId: String {
    get { businessId }
    set { businessId = newValue }
  }
  var email: String?
  var managerName: String?
  var operatingHours: String?
  var timezone: String?
  var createdAt: Date
  var updatedAt: Date
  
  init(id: String = UUID().uuidString, restaurantId: String, name: String, address: String? = nil, latitude: Double? = nil, longitude: Double? = nil, phone: String? = nil, email: String? = nil, managerName: String? = nil, operatingHours: String? = nil, timezone: String? = nil) {
    self.id = id
    self.businessId = restaurantId // Use businessId internally
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
    self.phone = phone
    self.email = email
    self.managerName = managerName
    self.operatingHours = operatingHours
    self.timezone = timezone
    self.createdAt = Date()
    self.updatedAt = Date()
  }
  
  // Convenience initializer with businessId
  init(id: String = UUID().uuidString, businessId: String, name: String, address: String? = nil, latitude: Double? = nil, longitude: Double? = nil, phone: String? = nil, email: String? = nil, managerName: String? = nil, operatingHours: String? = nil, timezone: String? = nil) {
    self.id = id
    self.businessId = businessId
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
    self.phone = phone
    self.email = email
    self.managerName = managerName
    self.operatingHours = operatingHours
    self.timezone = timezone
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

enum IssueStatus: String, Codable {
  case reported, in_progress, completed
  
  var displayName: String {
    switch self {
    case .reported: return "Reported"
    case .in_progress: return "In Progress"
    case .completed: return "Completed"
    }
  }
  
  var icon: String {
    switch self {
    case .reported: return "exclamationmark.circle"
    case .in_progress: return "clock"
    case .completed: return "checkmark.circle.fill"
    }
  }
  
  var color: String {
    switch self {
    case .reported: return "orange"
    case .in_progress: return "blue"
    case .completed: return "gray"
    }
  }
  
  var description: String {
    switch self {
    case .reported: return "Issue has been submitted and is awaiting review"
    case .in_progress: return "Kevin is actively working on this issue"
    case .completed: return "Issue has been fully resolved"
    }
  }
  
  var isActive: Bool {
    switch self {
    case .completed: return false
    default: return true
    }
  }
  
  // For backward compatibility with existing data
  static func fromLegacyStatus(_ legacyStatus: String) -> IssueStatus {
    switch legacyStatus {
    case "new": return .reported
    case "triaged": return .reported
    case "scheduled": return .in_progress
    case "in_progress": return .in_progress
    case "pending_review": return .completed // Map old approved states to completed
    case "needs_revision": return .in_progress // Send back to in progress
    case "approved": return .completed // Map old approved to completed
    case "done": return .completed
    case "completed": return .completed
    default: return .reported
    }
  }
  
  // Available next statuses for workflow
  var availableTransitions: [IssueStatus] {
    switch self {
    case .reported: return [.in_progress]
    case .in_progress: return [.completed, .reported] // Can complete directly or go back to reported if needed
    case .completed: return [] // Final state
    }
  }
}

enum IssuePriority: String, Codable {
  case low, medium, high
}

struct Issue: Identifiable, Codable {
  let id: String
  var restaurantId: String
  var locationId: String
  var reporterId: String
  var title: String
  var description: String?
  var type: String?
  var priority: IssuePriority
  var status: IssueStatus
  var photoUrls: [String]?
  var aiAnalysis: AIAnalysis?
  var voiceNotes: String? // Voice transcription notes
  var createdAt: Date
  var updatedAt: Date
  
  // Convenience initializer for missing updatedAt
  init(id: String, restaurantId: String = "", locationId: String, reporterId: String, title: String, description: String? = nil, type: String? = nil, priority: IssuePriority, status: IssueStatus, photoUrls: [String]? = nil, aiAnalysis: AIAnalysis? = nil, voiceNotes: String? = nil, createdAt: Date, updatedAt: Date? = nil) {
    self.id = id
    self.restaurantId = restaurantId
    self.locationId = locationId
    self.reporterId = reporterId
    self.title = title
    self.description = description
    self.type = type
    self.priority = priority
    self.status = status
    self.photoUrls = photoUrls
    self.aiAnalysis = aiAnalysis
    self.voiceNotes = voiceNotes
    self.createdAt = createdAt
    self.updatedAt = updatedAt ?? createdAt
  }
}

struct AIAnalysis: Codable {
  var summary: String?  // Made optional to handle different AI analysis formats
  var description: String
  var category: String?
  var priority: String // Changed to String to match ImageAnalysisResult
  var estimatedCost: Double?
  var timeToComplete: String?
  var materialsNeeded: [String]?
  var safetyWarnings: [String]?
  var repairInstructions: String?
  var recommendations: [String]?
  var confidence: Double?
  
  // Additional fields for backward compatibility with older AI analysis format
  var materials: [String]?
  var safetyConcerns: [String]?
  var estimatedTimeField: String?  // Renamed to avoid conflict with computed property
  
  // Computed properties for unified access
  var effectiveSummary: String {
    return summary ?? description
  }
  
  var effectiveMaterials: [String] {
    return materialsNeeded ?? materials ?? []
  }
  
  var effectiveSafetyConcerns: [String] {
    return safetyWarnings ?? safetyConcerns ?? []
  }
  
  var effectiveEstimatedTime: String {
    return timeToComplete ?? estimatedTimeField ?? "Unknown"
  }
  
  // Computed property for backward compatibility with existing UI code
  var estimatedTime: String {
    return timeToComplete ?? estimatedTimeField ?? "Unknown"
  }
}

enum WorkOrderStatus: String, Codable {
  case scheduled, en_route, in_progress, blocked, completed
}

struct WorkOrder: Identifiable, Codable {
  let id: String
  var restaurantId: String
  let issueId: String
  let assigneeId: String?
  var status: WorkOrderStatus
  let scheduledAt: Date?
  var startedAt: Date?
  var completedAt: Date?
  var estimatedCost: Double?
  var actualCost: Double?
  var notes: String?
  let createdAt: Date
}

struct IssuePhoto: Identifiable, Codable {
  let id: String
  var issueId: String
  var url: String
  var thumbUrl: String?
  var takenAt: Date
}

struct WorkLog: Identifiable, Codable {
  let id: String
  var issueId: String
  var authorId: String
  var message: String
  var createdAt: Date
}

struct MaintenanceIssue: Codable {
  let issue_category: String
  let component: String
  let failure_mode: [String]
  let severity_0to3: Int
  let safety_flag: Bool
  let summary: String
  let recommended_fix_steps: [String]
  let tools: [String]
  let materials: [String]
  let est_time_min: Int
  let est_cost_usd: Double
  let confidence_0to1: Double
  let evidence_regions: [BBox]?
  let notes: String?
}

struct BBox: Codable { 
  let x: Double
  let y: Double 
  let w: Double
  let h: Double 
}

// MARK: - Messaging Models
enum MessageType: String, Codable {
  case text, image, voice, system, quick_reply, issue_update, work_order_update, ai_analysis
  
  var displayName: String {
    switch self {
    case .text: return "Message"
    case .image: return "Photo"
    case .voice: return "Voice Message"
    case .system: return "System Update"
    case .quick_reply: return "Quick Reply"
    case .issue_update: return "Issue Update"
    case .work_order_update: return "Work Order Update"
    case .ai_analysis: return "AI Analysis"
    }
  }
}

enum ConversationType: String, Codable {
  case emergency, issue_specific, general, work_order, ai_review
  
  var displayName: String {
    switch self {
    case .emergency: return "Emergency Support"
    case .issue_specific: return "Issue Discussion"
    case .general: return "General Support"
    case .work_order: return "Work Order Updates"
    case .ai_review: return "AI Analysis Review"
    }
  }
  
  var icon: String {
    switch self {
    case .emergency: return "exclamationmark.triangle.fill"
    case .issue_specific: return "wrench.and.screwdriver"
    case .general: return "message"
    case .work_order: return "clipboard"
    case .ai_review: return "brain.head.profile"
    }
  }
  
  var color: String {
    switch self {
    case .emergency: return "danger"
    case .issue_specific: return "warning"
    case .general: return "accent"
    case .work_order: return "success"
    case .ai_review: return "aiGreen"
    }
  }
}

struct Conversation: Identifiable, Codable {
  let id: String
  let restaurantId: String?
  let type: ConversationType
  let issueId: String? // nil for general conversations
  let workOrderId: String? // for work order conversations
  let participantIds: [String] // User IDs of participants
  let title: String? // Optional title for conversations
  let createdAt: Date
  let updatedAt: Date
  var isActive: Bool
  var lastMessageAt: Date?
  var unreadCount: [String: Int] // userId -> unread count
  var priority: IssuePriority? // for emergency/urgent conversations
  var restaurantName: String? // cached restaurant name for display
  var restaurantAddress: String? // cached restaurant address for display
  var managerName: String? // cached manager name for display
  var contextData: [String: String]? // additional context (issue details, etc.)
}

struct Message: Identifiable, Codable {
  let id: String
  let conversationId: String
  let senderId: String
  let senderName: String
  let senderRole: Role
  let type: MessageType
  let content: String
  let imageUrl: String? // For image messages
  let voiceUrl: String? // For voice messages
  let createdAt: Date
  var isRead: Bool
  var readBy: [String: Date] // userId -> read timestamp
  var metadata: MessageMetadata? // Rich message data
  
  // For Smart Timeline compatibility
  var text: String { content }
  var timestamp: Date { createdAt }
  
  func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [
      "id": id,
      "conversationId": conversationId,
      "senderId": senderId,
      "senderName": senderName,
      "senderRole": senderRole.rawValue,
      "type": type.rawValue,
      "content": content,
      "createdAt": createdAt,
      "isRead": isRead,
      "readBy": readBy.mapValues { $0.timeIntervalSince1970 }
    ]
    
    if let imageUrl = imageUrl {
      dict["imageUrl"] = imageUrl
    }
    
    if let voiceUrl = voiceUrl {
      dict["voiceUrl"] = voiceUrl
    }
    
    if let metadata = metadata {
      // Convert metadata to dictionary if needed
      dict["metadata"] = try? JSONEncoder().encode(metadata)
    }
    
    return dict
  }
}

struct MessageMetadata: Codable {
  var issueId: String?
  var workOrderId: String?
  var aiAnalysisId: String?
  var quickReplyOptions: [String]?
  var statusUpdate: String?
  var priority: IssuePriority?
  var attachments: [MessageAttachment]?
}

struct MessageAttachment: Codable {
  let id: String
  let type: String // "image", "document", "ai_analysis"
  let url: String
  let name: String
  let size: Int?
}

// MARK: - Quote Management
enum QuoteStatus: String, Codable {
  case ai_generated, manual_review, sent_to_customer, approved, rejected
  
  var displayName: String {
    switch self {
    case .ai_generated: return "AI Generated"
    case .manual_review: return "Under Review"
    case .sent_to_customer: return "Sent to Customer"
    case .approved: return "Approved"
    case .rejected: return "Rejected"
    }
  }
}

struct CostBreakdown: Codable {
  var laborHours: Double
  var laborRate: Double
  var materials: [MaterialCost]
  var additionalFees: [AdditionalFee]
  
  var totalLabor: Double {
    return laborHours * laborRate
  }
  
  var totalMaterials: Double {
    return materials.reduce(0) { $0 + $1.totalCost }
  }
  
  var totalAdditionalFees: Double {
    return additionalFees.reduce(0) { $0 + $1.amount }
  }
  
  var grandTotal: Double {
    return totalLabor + totalMaterials + totalAdditionalFees
  }
}

struct MaterialCost: Codable {
  let id: String
  var name: String
  var quantity: Double
  var unitPrice: Double
  var unit: String // "each", "sq ft", "linear ft", etc.
  
  var totalCost: Double {
    return quantity * unitPrice
  }
  
  init(id: String = UUID().uuidString, name: String, quantity: Double, unitPrice: Double, unit: String = "each") {
    self.id = id
    self.name = name
    self.quantity = quantity
    self.unitPrice = unitPrice
    self.unit = unit
  }
}

struct AdditionalFee: Codable {
  let id: String
  var name: String
  var amount: Double
  var description: String?
  
  init(id: String = UUID().uuidString, name: String, amount: Double, description: String? = nil) {
    self.id = id
    self.name = name
    self.amount = amount
    self.description = description
  }
}

struct QuoteEstimate: Identifiable, Codable {
  let id: String
  let issueId: String
  let restaurantId: String
  var aiAnalysisId: String? // Reference to the AI analysis that generated this
  var status: QuoteStatus
  var costBreakdown: CostBreakdown
  var aiConfidence: Double? // AI confidence in the estimate
  var notes: String?
  var validUntil: Date?
  var createdBy: String // User ID
  var createdAt: Date
  var updatedAt: Date
  var sentAt: Date? // When quote was sent to customer
  var approvedAt: Date? // When customer approved
  
  // Convenience computed properties
  var totalEstimate: Double {
    return costBreakdown.grandTotal
  }
  
  var isExpired: Bool {
    guard let validUntil = validUntil else { return false }
    return Date() > validUntil
  }
  
  init(
    id: String = UUID().uuidString,
    issueId: String,
    restaurantId: String,
    aiAnalysisId: String? = nil,
    status: QuoteStatus = .ai_generated,
    costBreakdown: CostBreakdown,
    aiConfidence: Double? = nil,
    notes: String? = nil,
    validUntil: Date? = nil,
    createdBy: String,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    sentAt: Date? = nil,
    approvedAt: Date? = nil
  ) {
    self.id = id
    self.issueId = issueId
    self.restaurantId = restaurantId
    self.aiAnalysisId = aiAnalysisId
    self.status = status
    self.costBreakdown = costBreakdown
    self.aiConfidence = aiConfidence
    self.notes = notes
    self.validUntil = validUntil
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.sentAt = sentAt
    self.approvedAt = approvedAt
  }
}

// MARK: - Receipt Management
enum ReceiptStatus: String, Codable {
  case pending, approved, rejected, reimbursed
  
  var displayName: String {
    switch self {
    case .pending: return "Pending Review"
    case .approved: return "Approved"
    case .rejected: return "Rejected"
    case .reimbursed: return "Reimbursed"
    }
  }
  
  var color: String {
    switch self {
    case .pending: return "orange"
    case .approved: return "green"
    case .rejected: return "red"
    case .reimbursed: return "blue"
    }
  }
  
  var icon: String {
    switch self {
    case .pending: return "clock"
    case .approved: return "checkmark.circle"
    case .rejected: return "xmark.circle"
    case .reimbursed: return "dollarsign.circle"
    }
  }
}

enum ReceiptCategory: String, Codable, CaseIterable {
  case materials, tools, supplies, transportation, other
  
  var displayName: String {
    switch self {
    case .materials: return "Materials"
    case .tools: return "Tools"
    case .supplies: return "Supplies"
    case .transportation: return "Transportation"
    case .other: return "Other"
    }
  }
  
  var icon: String {
    switch self {
    case .materials: return "hammer"
    case .tools: return "wrench"
    case .supplies: return "box"
    case .transportation: return "car"
    case .other: return "questionmark.circle"
    }
  }
}

struct Receipt: Identifiable, Codable {
  let id: String
  let issueId: String
  let workOrderId: String?
  let restaurantId: String
  let submittedBy: String // User ID of the tech who submitted
  var vendor: String // Store/vendor name
  var category: ReceiptCategory
  var amount: Double
  var taxAmount: Double?
  var description: String
  var purchaseDate: Date
  var receiptImageUrl: String // URL to receipt photo in Firebase Storage
  var thumbnailUrl: String? // Thumbnail for quick preview
  var status: ReceiptStatus
  var reviewedBy: String? // User ID of reviewer
  var reviewedAt: Date?
  var reviewNotes: String?
  var reimbursedAt: Date?
  let createdAt: Date
  var updatedAt: Date
  
  // Computed properties
  var totalAmount: Double {
    return amount + (taxAmount ?? 0)
  }
  
  var isReimbursable: Bool {
    return status == .approved && reimbursedAt == nil
  }
  
  init(
    id: String = UUID().uuidString,
    issueId: String,
    workOrderId: String? = nil,
    restaurantId: String,
    submittedBy: String,
    vendor: String,
    category: ReceiptCategory,
    amount: Double,
    taxAmount: Double? = nil,
    description: String,
    purchaseDate: Date,
    receiptImageUrl: String,
    thumbnailUrl: String? = nil,
    status: ReceiptStatus = .pending,
    reviewedBy: String? = nil,
    reviewedAt: Date? = nil,
    reviewNotes: String? = nil,
    reimbursedAt: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.issueId = issueId
    self.workOrderId = workOrderId
    self.restaurantId = restaurantId
    self.submittedBy = submittedBy
    self.vendor = vendor
    self.category = category
    self.amount = amount
    self.taxAmount = taxAmount
    self.description = description
    self.purchaseDate = purchaseDate
    self.receiptImageUrl = receiptImageUrl
    self.thumbnailUrl = thumbnailUrl
    self.status = status
    self.reviewedBy = reviewedBy
    self.reviewedAt = reviewedAt
    self.reviewNotes = reviewNotes
    self.reimbursedAt = reimbursedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Payment & Subscription Management
enum SubscriptionPlan: String, Codable, CaseIterable {
  case basic, professional, enterprise
  
  var displayName: String {
    switch self {
    case .basic: return "Basic Plan"
    case .professional: return "Professional Plan"
    case .enterprise: return "Enterprise Plan"
    }
  }
  
  var monthlyPrice: Double {
    switch self {
    case .basic: return 99.0
    case .professional: return 199.0
    case .enterprise: return 399.0
    }
  }
  
  var features: [String] {
    switch self {
    case .basic:
      return [
        "Up to 50 issues per month",
        "AI-powered maintenance analysis",
        "Basic reporting",
        "Email support"
      ]
    case .professional:
      return [
        "Up to 200 issues per month",
        "AI-powered maintenance analysis",
        "Advanced reporting & analytics",
        "Priority support",
        "Receipt management",
        "Custom work order templates"
      ]
    case .enterprise:
      return [
        "Unlimited issues",
        "AI-powered maintenance analysis",
        "Advanced reporting & analytics",
        "24/7 phone support",
        "Receipt management",
        "Custom work order templates",
        "Multi-location management",
        "API access"
      ]
    }
  }
  
  var issueLimit: Int? {
    switch self {
    case .basic: return 50
    case .professional: return 200
    case .enterprise: return nil // Unlimited
    }
  }
}

enum PaymentStatus: String, Codable {
  case pending, processing, succeeded, failed, cancelled, refunded
  
  var displayName: String {
    switch self {
    case .pending: return "Pending"
    case .processing: return "Processing"
    case .succeeded: return "Paid"
    case .failed: return "Failed"
    case .cancelled: return "Cancelled"
    case .refunded: return "Refunded"
    }
  }
  
  var color: String {
    switch self {
    case .pending: return "orange"
    case .processing: return "blue"
    case .succeeded: return "green"
    case .failed: return "red"
    case .cancelled: return "gray"
    case .refunded: return "purple"
    }
  }
}

enum SubscriptionStatus: String, Codable {
  case active, past_due, cancelled, unpaid, trialing
  
  var displayName: String {
    switch self {
    case .active: return "Active"
    case .past_due: return "Past Due"
    case .cancelled: return "Cancelled"
    case .unpaid: return "Unpaid"
    case .trialing: return "Trial"
    }
  }
  
  var isActive: Bool {
    return self == .active || self == .trialing
  }
}

struct Subscription: Identifiable, Codable {
  let id: String
  let restaurantId: String
  var plan: SubscriptionPlan
  var status: SubscriptionStatus
  var stripeSubscriptionId: String?
  var stripeCustomerId: String?
  var currentPeriodStart: Date
  var currentPeriodEnd: Date
  var cancelAtPeriodEnd: Bool
  var cancelledAt: Date?
  var trialEnd: Date?
  var issuesUsedThisMonth: Int
  let createdAt: Date
  var updatedAt: Date
  
  // Computed properties
  var isInTrial: Bool {
    guard let trialEnd = trialEnd else { return false }
    return Date() < trialEnd && status == .trialing
  }
  
  var daysUntilRenewal: Int {
    let calendar = Calendar.current
    return calendar.dateComponents([.day], from: Date(), to: currentPeriodEnd).day ?? 0
  }
  
  var canCreateIssues: Bool {
    guard status.isActive else { return false }
    
    if let limit = plan.issueLimit {
      return issuesUsedThisMonth < limit
    }
    return true // Unlimited plan
  }
  
  var remainingIssues: Int? {
    guard let limit = plan.issueLimit else { return nil }
    return max(0, limit - issuesUsedThisMonth)
  }
  
  init(
    id: String = UUID().uuidString,
    restaurantId: String,
    plan: SubscriptionPlan,
    status: SubscriptionStatus = .trialing,
    stripeSubscriptionId: String? = nil,
    stripeCustomerId: String? = nil,
    currentPeriodStart: Date = Date(),
    currentPeriodEnd: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
    cancelAtPeriodEnd: Bool = false,
    cancelledAt: Date? = nil,
    trialEnd: Date? = Calendar.current.date(byAdding: .day, value: 14, to: Date()),
    issuesUsedThisMonth: Int = 0,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.restaurantId = restaurantId
    self.plan = plan
    self.status = status
    self.stripeSubscriptionId = stripeSubscriptionId
    self.stripeCustomerId = stripeCustomerId
    self.currentPeriodStart = currentPeriodStart
    self.currentPeriodEnd = currentPeriodEnd
    self.cancelAtPeriodEnd = cancelAtPeriodEnd
    self.cancelledAt = cancelledAt
    self.trialEnd = trialEnd
    self.issuesUsedThisMonth = issuesUsedThisMonth
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

struct Payment: Identifiable, Codable {
  let id: String
  let restaurantId: String
  let subscriptionId: String?
  var amount: Double
  var currency: String
  var status: PaymentStatus
  var stripePaymentIntentId: String?
  var stripeChargeId: String?
  var description: String
  var receiptUrl: String? // Stripe receipt URL
  var failureReason: String?
  let createdAt: Date
  var updatedAt: Date
  
  init(
    id: String = UUID().uuidString,
    restaurantId: String,
    subscriptionId: String? = nil,
    amount: Double,
    currency: String = "usd",
    status: PaymentStatus = .pending,
    stripePaymentIntentId: String? = nil,
    stripeChargeId: String? = nil,
    description: String,
    receiptUrl: String? = nil,
    failureReason: String? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.restaurantId = restaurantId
    self.subscriptionId = subscriptionId
    self.amount = amount
    self.currency = currency
    self.status = status
    self.stripePaymentIntentId = stripePaymentIntentId
    self.stripeChargeId = stripeChargeId
    self.description = description
    self.receiptUrl = receiptUrl
    self.failureReason = failureReason
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Support Messages
enum SupportMessageStatus: String, Codable {
  case new, inProgress, resolved, closed
  
  var displayName: String {
    switch self {
    case .new: return "New"
    case .inProgress: return "In Progress"
    case .resolved: return "Resolved"
    case .closed: return "Closed"
    }
  }
  
  var color: String {
    switch self {
    case .new: return "orange"
    case .inProgress: return "blue"
    case .resolved: return "green"
    case .closed: return "gray"
    }
  }
}

enum SupportCategory: String, Codable, CaseIterable {
  case general, technical, billing, feature, urgent
  
  var displayName: String {
    switch self {
    case .general: return "General Question"
    case .technical: return "Technical Issue"
    case .billing: return "Billing Question"
    case .feature: return "Feature Request"
    case .urgent: return "Urgent Issue"
    }
  }
  
  var icon: String {
    switch self {
    case .general: return "questionmark.circle"
    case .technical: return "wrench.and.screwdriver"
    case .billing: return "dollarsign.circle"
    case .feature: return "lightbulb"
    case .urgent: return "exclamationmark.triangle"
    }
  }
}

struct SupportMessage: Identifiable, Codable {
  let id: String
  let userId: String
  var userName: String
  var userEmail: String?
  var category: SupportCategory
  var subject: String
  var message: String
  var status: SupportMessageStatus
  var adminNotes: String?
  var respondedBy: String? // Admin user ID who responded
  var respondedAt: Date?
  let createdAt: Date
  var updatedAt: Date
  
  init(
    id: String = UUID().uuidString,
    userId: String,
    userName: String,
    userEmail: String? = nil,
    category: SupportCategory,
    subject: String,
    message: String,
    status: SupportMessageStatus = .new,
    adminNotes: String? = nil,
    respondedBy: String? = nil,
    respondedAt: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.userId = userId
    self.userName = userName
    self.userEmail = userEmail
    self.category = category
    self.subject = subject
    self.message = message
    self.status = status
    self.adminNotes = adminNotes
    self.respondedBy = respondedBy
    self.respondedAt = respondedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Smart Reply Templates
struct SmartReplyTemplate {
  static let restaurantReplies = [
    "When can someone come look at this?",
    "Is this urgent or can it wait?",
    "I've completed the work order",
    "I need to add more photos",
    "What parts do I need to order?",
    "This is getting worse",
    "The issue is resolved",
    "I need emergency assistance"
  ]
  
  static let adminReplies = [
    "I'll have someone there within 2 hours",
    "Can you send more photos of the issue?",
    "This looks like a plumbing issue",
    "I've updated the work order status",
    "Let me connect you with our specialist team",
    "This can wait until tomorrow",
    "Escalating to emergency priority",
    "Work order has been completed"
  ]
  
  static func getRepliesFor(role: Role, conversationType: ConversationType) -> [String] {
    switch role {
    case .admin:
      return adminReplies
    default:
      return restaurantReplies
    }
  }
}
