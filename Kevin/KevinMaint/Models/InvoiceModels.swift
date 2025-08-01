import Foundation

// MARK: - Invoice Models

struct Invoice: Identifiable, Codable {
    let id: String
    let invoiceNumber: String // e.g., "INV-20241022-001"
    let issueId: String
    let businessId: String
    let businessName: String
    let businessAddress: String?
    let businessEmail: String?
    let businessPhone: String?
    
    // Line items
    var lineItems: [InvoiceLineItem]
    
    // Dates
    let issueDate: Date
    var dueDate: Date
    var paidDate: Date?
    
    // Financial
    var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }
    var taxRate: Double // e.g., 0.08 for 8%
    var taxAmount: Double {
        subtotal * taxRate
    }
    var total: Double {
        subtotal + taxAmount
    }
    
    // Status
    var status: InvoiceStatus
    var paymentInstructions: String?
    
    // Metadata
    var notes: String?
    var pdfUrl: String? // Firebase Storage URL for generated PDF
    var receiptUrls: [String]? // Firebase Storage URLs for receipt photos
    let createdBy: String // Admin user ID
    let createdAt: Date
    var updatedAt: Date
    var sentAt: Date? // When invoice was emailed
    
    init(
        id: String = UUID().uuidString,
        invoiceNumber: String,
        issueId: String,
        businessId: String,
        businessName: String,
        businessAddress: String? = nil,
        businessEmail: String? = nil,
        businessPhone: String? = nil,
        lineItems: [InvoiceLineItem] = [],
        issueDate: Date = Date(),
        dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        paidDate: Date? = nil,
        taxRate: Double = 0.08,
        status: InvoiceStatus = .draft,
        paymentInstructions: String? = "Payment due within 30 days. Please make checks payable to Kevin Maint.",
        notes: String? = nil,
        pdfUrl: String? = nil,
        receiptUrls: [String]? = nil,
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sentAt: Date? = nil
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.issueId = issueId
        self.businessId = businessId
        self.businessName = businessName
        self.businessAddress = businessAddress
        self.businessEmail = businessEmail
        self.businessPhone = businessPhone
        self.lineItems = lineItems
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.taxRate = taxRate
        self.status = status
        self.paymentInstructions = paymentInstructions
        self.notes = notes
        self.pdfUrl = pdfUrl
        self.receiptUrls = receiptUrls
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sentAt = sentAt
    }
}

struct InvoiceLineItem: Identifiable, Codable, Equatable {
    let id: String
    var description: String
    var quantity: Double
    var unitPrice: Double
    var receiptId: String? // Link to receipt if applicable
    
    var total: Double {
        quantity * unitPrice
    }
    
    init(
        id: String = UUID().uuidString,
        description: String,
        quantity: Double = 1.0,
        unitPrice: Double,
        receiptId: String? = nil
    ) {
        self.id = id
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.receiptId = receiptId
    }
}

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft
    case sent
    case paid
    case overdue
    case cancelled
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .sent: return "Sent"
        case .paid: return "Paid"
        case .overdue: return "Overdue"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .sent: return "blue"
        case .paid: return "green"
        case .overdue: return "red"
        case .cancelled: return "gray"
        }
    }
}

// MARK: - Invoice Number Generator

class InvoiceNumberGenerator {
    private static let counterKey = "InvoiceNumberCounter"
    
    static func generate(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: date)
        
        // Get and increment counter from UserDefaults
        let currentCounter = UserDefaults.standard.integer(forKey: counterKey)
        let nextCounter = currentCounter + 1
        UserDefaults.standard.set(nextCounter, forKey: counterKey)
        
        // Format counter as 4-digit number (0001, 0002, etc.)
        let suffix = String(format: "%04d", nextCounter)
        
        return "INV-\(dateString)-\(suffix)"
    }
    
    // Reset counter (for testing purposes)
    static func resetCounter() {
        UserDefaults.standard.set(0, forKey: counterKey)
    }
}
