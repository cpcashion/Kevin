import Foundation
import FirebaseFirestore

// MARK: - Document Type
enum DocumentType: String, Codable, CaseIterable {
    case invoice = "invoice"
    case receipt = "receipt"
    case quote = "quote"
    case workOrder = "work_order"
    case photo = "photo"
    case warranty = "warranty"
    case inspection = "inspection"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .invoice: return "Invoice"
        case .receipt: return "Receipt"
        case .quote: return "Quote/Estimate"
        case .workOrder: return "Work Order"
        case .photo: return "Photo"
        case .warranty: return "Warranty"
        case .inspection: return "Inspection Report"
        case .other: return "Document"
        }
    }
    
    var icon: String {
        switch self {
        case .invoice: return "doc.text.fill"
        case .receipt: return "receipt.fill"
        case .quote: return "doc.badge.ellipsis"
        case .workOrder: return "wrench.and.screwdriver.fill"
        case .photo: return "photo.fill"
        case .warranty: return "checkmark.seal.fill"
        case .inspection: return "list.clipboard.fill"
        case .other: return "doc.fill"
        }
    }
    
    var category: DocumentCategory {
        switch self {
        case .invoice, .receipt, .quote:
            return .financial
        case .workOrder, .inspection:
            return .workOrder
        case .photo:
            return .photo
        case .warranty, .other:
            return .other
        }
    }
}

// MARK: - Document Category
enum DocumentCategory: String, Codable {
    case financial = "financial"
    case workOrder = "work_order"
    case photo = "photo"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .financial: return "Financial"
        case .workOrder: return "Work Order"
        case .photo: return "Photo"
        case .other: return "Other"
        }
    }
}

// MARK: - Issue Document Model
struct IssueDocument: Codable, Identifiable {
    let id: String
    let issueId: String
    let type: DocumentType
    let category: DocumentCategory
    
    // File storage
    let fileUrl: String
    let thumbnailUrl: String?
    let fileName: String
    let fileSize: Int?
    
    // AI Analysis
    let aiAnalysis: DocumentAnalysis?
    let confidence: Double?
    
    // Metadata
    let uploadedBy: String
    let uploadedAt: Date
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case type
        case category
        case fileUrl = "file_url"
        case thumbnailUrl = "thumbnail_url"
        case fileName = "file_name"
        case fileSize = "file_size"
        case aiAnalysis = "ai_analysis"
        case confidence
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
        case notes
    }
}

// MARK: - Document Analysis (AI Extracted Data)
struct DocumentAnalysis: Codable {
    // Common fields
    let vendor: String?
    let date: Date?
    let description: String?
    
    // Financial fields
    let subtotal: Double?
    let tax: Double?
    let total: Double?
    let invoiceNumber: String?
    let purchaseOrderNumber: String?
    
    // Quote/Estimate fields
    let estimatedCost: String?
    let validUntil: Date?
    
    // Work Order fields
    let contractor: String?
    let scope: String?
    let timeline: String?
    
    // Items/Line items
    let items: [String]?
    
    // Category (for receipts/invoices)
    let expenseCategory: String?
    
    enum CodingKeys: String, CodingKey {
        case vendor, date, description
        case subtotal, tax, total
        case invoiceNumber = "invoice_number"
        case purchaseOrderNumber = "po_number"
        case estimatedCost = "estimated_cost"
        case validUntil = "valid_until"
        case contractor, scope, timeline
        case items
        case expenseCategory = "expense_category"
    }
}

// MARK: - Firestore Extensions
extension IssueDocument {
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let issueId = dictionary["issue_id"] as? String,
              let typeString = dictionary["type"] as? String,
              let type = DocumentType(rawValue: typeString),
              let categoryString = dictionary["category"] as? String,
              let category = DocumentCategory(rawValue: categoryString),
              let fileUrl = dictionary["file_url"] as? String,
              let fileName = dictionary["file_name"] as? String,
              let uploadedBy = dictionary["uploaded_by"] as? String,
              let uploadedAtTimestamp = dictionary["uploaded_at"] as? Timestamp else {
            return nil
        }
        
        self.id = id
        self.issueId = issueId
        self.type = type
        self.category = category
        self.fileUrl = fileUrl
        self.thumbnailUrl = dictionary["thumbnail_url"] as? String
        self.fileName = fileName
        self.fileSize = dictionary["file_size"] as? Int
        self.confidence = dictionary["confidence"] as? Double
        self.uploadedBy = uploadedBy
        self.uploadedAt = uploadedAtTimestamp.dateValue()
        self.notes = dictionary["notes"] as? String
        
        // Parse AI analysis if present
        if let analysisDict = dictionary["ai_analysis"] as? [String: Any] {
            self.aiAnalysis = DocumentAnalysis(dictionary: analysisDict)
        } else {
            self.aiAnalysis = nil
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "issue_id": issueId,
            "type": type.rawValue,
            "category": category.rawValue,
            "file_url": fileUrl,
            "file_name": fileName,
            "uploaded_by": uploadedBy,
            "uploaded_at": Timestamp(date: uploadedAt)
        ]
        
        if let thumbnailUrl = thumbnailUrl {
            dict["thumbnail_url"] = thumbnailUrl
        }
        if let fileSize = fileSize {
            dict["file_size"] = fileSize
        }
        if let confidence = confidence {
            dict["confidence"] = confidence
        }
        if let notes = notes {
            dict["notes"] = notes
        }
        if let aiAnalysis = aiAnalysis {
            dict["ai_analysis"] = aiAnalysis.toDictionary()
        }
        
        return dict
    }
}

extension DocumentAnalysis {
    init?(dictionary: [String: Any]) {
        self.vendor = dictionary["vendor"] as? String
        self.description = dictionary["description"] as? String
        self.subtotal = dictionary["subtotal"] as? Double
        self.tax = dictionary["tax"] as? Double
        self.total = dictionary["total"] as? Double
        self.invoiceNumber = dictionary["invoice_number"] as? String
        self.purchaseOrderNumber = dictionary["po_number"] as? String
        self.estimatedCost = dictionary["estimated_cost"] as? String
        self.contractor = dictionary["contractor"] as? String
        self.scope = dictionary["scope"] as? String
        self.timeline = dictionary["timeline"] as? String
        self.items = dictionary["items"] as? [String]
        self.expenseCategory = dictionary["expense_category"] as? String
        
        // Parse dates
        if let dateTimestamp = dictionary["date"] as? Timestamp {
            self.date = dateTimestamp.dateValue()
        } else {
            self.date = nil
        }
        
        if let validUntilTimestamp = dictionary["valid_until"] as? Timestamp {
            self.validUntil = validUntilTimestamp.dateValue()
        } else {
            self.validUntil = nil
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let vendor = vendor { dict["vendor"] = vendor }
        if let description = description { dict["description"] = description }
        if let subtotal = subtotal { dict["subtotal"] = subtotal }
        if let tax = tax { dict["tax"] = tax }
        if let total = total { dict["total"] = total }
        if let invoiceNumber = invoiceNumber { dict["invoice_number"] = invoiceNumber }
        if let purchaseOrderNumber = purchaseOrderNumber { dict["po_number"] = purchaseOrderNumber }
        if let estimatedCost = estimatedCost { dict["estimated_cost"] = estimatedCost }
        if let contractor = contractor { dict["contractor"] = contractor }
        if let scope = scope { dict["scope"] = scope }
        if let timeline = timeline { dict["timeline"] = timeline }
        if let items = items { dict["items"] = items }
        if let expenseCategory = expenseCategory { dict["expense_category"] = expenseCategory }
        if let date = date { dict["date"] = Timestamp(date: date) }
        if let validUntil = validUntil { dict["valid_until"] = Timestamp(date: validUntil) }
        
        return dict
    }
}
