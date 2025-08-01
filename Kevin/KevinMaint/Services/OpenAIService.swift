import Foundation
import UIKit

// MARK: - Timeout Helper
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AIError.apiRequestFailed // Timeout error
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct OpenAIConfig {
    static let apiKey = APIKeys.openAIAPIKey
    static let baseURL = "https://api.openai.com/v1"
}

class OpenAIService {
    static let shared = OpenAIService()
    private init() {}
    
    // MARK: - Universal Document Analysis
    func analyzeDocument(_ image: UIImage) async throws -> DocumentAnalysisResult {
        print("📄 Processing document image for AI analysis...")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert document image to JPEG data")
            throw AIError.imageProcessingFailed
        }
        
        print("✅ Document image converted to JPEG (\(imageData.count) bytes)")
        let base64Image = imageData.base64EncodedString()
        print("✅ Document image encoded to base64 (\(base64Image.count) characters)")
        
        let payload = OpenAIVisionRequest(
            model: "gpt-4o",
            messages: [
                OpenAIMessage(
                    role: "user",
                    content: [
                        OpenAIContent(type: "text", text: documentAnalysisPrompt),
                        OpenAIContent(type: "image_url", imageUrl: OpenAIImageURL(url: "data:image/jpeg;base64,\(base64Image)"))
                    ]
                )
            ],
            maxTokens: 1000,
            temperature: 0.3
        )
        
        let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(payload)
        request.httpBody = jsonData
        
        print("🌐 Sending document request to OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw AIError.apiRequestFailed
        }
        
        print("📡 OpenAI document response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ OpenAI API error: \(errorString)")
            }
            throw AIError.apiRequestFailed
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            print("❌ No content in OpenAI document response")
            throw AIError.invalidResponse
        }
        
        print("✅ Received OpenAI document response: \(content.prefix(100))...")
        return try parseDocumentAnalysisResponse(content)
    }
    
    // LEGACY: Keep for backward compatibility
    func analyzeReceiptImage(_ image: UIImage) async throws -> ReceiptAnalysisResult {
        print("🧾 Processing receipt image for OpenAI analysis...")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert receipt image to JPEG data")
            throw AIError.imageProcessingFailed
        }
        
        print("✅ Receipt image converted to JPEG (\(imageData.count) bytes)")
        let base64Image = imageData.base64EncodedString()
        print("✅ Receipt image encoded to base64 (\(base64Image.count) characters)")
        
        let payload = OpenAIVisionRequest(
            model: "gpt-4o",
            messages: [
                OpenAIMessage(
                    role: "user",
                    content: [
                        OpenAIContent(type: "text", text: receiptAnalysisPrompt),
                        OpenAIContent(type: "image_url", imageUrl: OpenAIImageURL(url: "data:image/jpeg;base64,\(base64Image)"))
                    ]
                )
            ],
            maxTokens: 800,
            temperature: 0.3
        )
        
        let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(payload)
        request.httpBody = jsonData
        
        print("🌐 Sending receipt request to OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw AIError.apiRequestFailed
        }
        
        print("📡 OpenAI receipt response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ OpenAI API error: \(errorString)")
            }
            throw AIError.apiRequestFailed
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            print("❌ No content in OpenAI receipt response")
            throw AIError.invalidResponse
        }
        
        print("✅ Received OpenAI receipt response: \(content.prefix(100))...")
        return try parseReceiptAnalysisResponse(content)
    }

    func analyzeMaintenanceImage(_ image: UIImage, userId: String? = nil) async throws -> ImageAnalysisResult {
        let startTime = Date()
        
        // Start performance tracking
        PerformanceMonitoringService.shared.trackAIAnalysis(
            imageSize: image.size,
            imageSizeBytes: image.jpegData(compressionQuality: 0.8)?.count
        )
        
        // Log analysis start
        RemoteLoggingService.shared.logAIAnalysis(
            event: .started,
            imageSize: image.size,
            userId: userId
        )
        
        print("📸 Processing image for OpenAI analysis...")
        
        // Validate API configuration
        guard APIKeys.isOpenAIConfigured else {
            let error = AIError.apiRequestFailed
            RemoteLoggingService.shared.logAIAnalysis(
                event: .failed,
                error: error,
                userId: userId
            )
            ErrorReportingService.shared.reportAIAnalysisFailure(
                error: error,
                imageSize: image.size,
                userFeedback: "API key not configured",
                userId: userId
            )
            throw error
        }
        
        // OPTIMIZATION: Resize image to reduce processing time and API costs
        let optimizedImage = resizeImageForAnalysis(image)
        print("📸 Image optimized: \(image.size) → \(optimizedImage.size)")
        
        // Convert optimized image to JPEG with aggressive compression for speed
        guard let imageData = optimizedImage.jpegData(compressionQuality: 0.5) else { // SPEED: Lower quality for faster upload
            let error = AIError.imageProcessingFailed
            RemoteLoggingService.shared.logAIAnalysis(
                event: .failed,
                imageSize: image.size,
                error: error,
                userId: userId
            )
            ErrorReportingService.shared.reportAIAnalysisFailure(
                error: error,
                imageSize: image.size,
                userFeedback: "Failed to convert image to JPEG",
                userId: userId
            )
            throw error
        }
        
        RemoteLoggingService.shared.logAIAnalysis(
            event: .imageProcessed,
            imageSize: optimizedImage.size,
            imageSizeBytes: imageData.count,
            userId: userId
        )
        
        print("✅ Image converted to JPEG (\(imageData.count) bytes)")
        let base64Image = imageData.base64EncodedString()
        print("✅ Image encoded to base64 (\(base64Image.count) characters)")
        
        let payload = OpenAIVisionRequest(
            model: "gpt-4o-mini", // SPEED OPTIMIZATION: Use faster, cheaper model
            messages: [
                OpenAIMessage(
                    role: "user",
                    content: [
                        OpenAIContent(type: "text", text: maintenanceAnalysisPrompt),
                        OpenAIContent(type: "image_url", imageUrl: OpenAIImageURL(url: "data:image/jpeg;base64,\(base64Image)"))
                    ]
                )
            ],
            maxTokens: 500, // SPEED OPTIMIZATION: Reduce token limit for faster response
            temperature: 0.3 // SPEED OPTIMIZATION: Lower temperature for faster, more focused responses
        )
        
        let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(payload)
            request.httpBody = jsonData
            
            RemoteLoggingService.shared.logAIAnalysis(
                event: .apiRequestSent,
                imageSize: image.size,
                imageSizeBytes: imageData.count,
                userId: userId
            )
            
            print("🌐 Sending request to OpenAI...")
            let requestStartTime = Date()
            
            // Add timeout to prevent hanging
            let (data, response) = try await withTimeout(seconds: 30) {
                try await URLSession.shared.data(for: request)
            }
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = AIError.apiRequestFailed
                RemoteLoggingService.shared.logAIAnalysis(
                    event: .failed,
                    imageSize: image.size,
                    imageSizeBytes: imageData.count,
                    error: error,
                    duration: Date().timeIntervalSince(startTime),
                    userId: userId
                )
                ErrorReportingService.shared.reportAIAnalysisFailure(
                    error: error,
                    imageSize: image.size,
                    imageSizeBytes: imageData.count,
                    userFeedback: "Invalid HTTP response from OpenAI",
                    userId: userId
                )
                throw error
            }
            
            // Log network request
            RemoteLoggingService.shared.logNetworkRequest(
                url: url.absoluteString,
                method: "POST",
                statusCode: httpResponse.statusCode,
                responseTime: requestDuration,
                error: httpResponse.statusCode != 200 ? AIError.apiRequestFailed : nil,
                userId: userId
            )
            
            print("📡 OpenAI response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ OpenAI API error: \(errorString)")
                
                let error = AIError.apiRequestFailed
                RemoteLoggingService.shared.logAIAnalysis(
                    event: .failed,
                    imageSize: image.size,
                    imageSizeBytes: imageData.count,
                    apiResponse: errorString,
                    error: error,
                    duration: Date().timeIntervalSince(startTime),
                    userId: userId
                )
                
                ErrorReportingService.shared.reportAIAnalysisFailure(
                    error: error,
                    imageSize: image.size,
                    imageSizeBytes: imageData.count,
                    apiResponse: errorString,
                    userFeedback: "OpenAI API returned status \(httpResponse.statusCode)",
                    userId: userId
                )
                throw error
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            RemoteLoggingService.shared.logAIAnalysis(
                event: .apiResponseReceived,
                imageSize: image.size,
                imageSizeBytes: imageData.count,
                apiResponse: responseString,
                duration: requestDuration,
                userId: userId
            )
            
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = openAIResponse.choices.first?.message.content else {
                let error = AIError.invalidResponse
                RemoteLoggingService.shared.logAIAnalysis(
                    event: .failed,
                    imageSize: image.size,
                    imageSizeBytes: imageData.count,
                    apiResponse: responseString,
                    error: error,
                    duration: Date().timeIntervalSince(startTime),
                    userId: userId
                )
                ErrorReportingService.shared.reportAIAnalysisFailure(
                    error: error,
                    imageSize: image.size,
                    imageSizeBytes: imageData.count,
                    apiResponse: responseString,
                    userFeedback: "No content in OpenAI response",
                    userId: userId
                )
                throw error
            }
            
            print("✅ Received OpenAI response: \(content.prefix(100))...")
            
            RemoteLoggingService.shared.logAIAnalysis(
                event: .parsingStarted,
                imageSize: image.size,
                imageSizeBytes: imageData.count,
                apiResponse: content,
                userId: userId
            )
            
            let result = try parseAnalysisResponse(content)
            
            let totalDuration = Date().timeIntervalSince(startTime)
            
            // Complete performance tracking
            PerformanceMonitoringService.shared.completeAIAnalysis(
                success: true,
                duration: totalDuration,
                confidence: result.confidence
            )
            
            RemoteLoggingService.shared.logAIAnalysis(
                event: .completed,
                imageSize: image.size,
                imageSizeBytes: imageData.count,
                apiResponse: content,
                duration: totalDuration,
                userId: userId
            )
            
            return result
            
        } catch {
            let totalDuration = Date().timeIntervalSince(startTime)
            
            // Complete performance tracking (failed)
            PerformanceMonitoringService.shared.completeAIAnalysis(
                success: false,
                duration: totalDuration
            )
            
            RemoteLoggingService.shared.logAIAnalysis(
                event: .failed,
                imageSize: image.size,
                imageSizeBytes: imageData.count,
                error: error,
                duration: totalDuration,
                userId: userId
            )
            
            ErrorReportingService.shared.reportAIAnalysisFailure(
                error: error,
                imageSize: image.size,
                imageSizeBytes: imageData.count,
                userFeedback: "Analysis failed with error: \(error.localizedDescription)",
                userId: userId
            )
            
            throw error
        }
    }
    
    // MARK: - AI Prompts
    private var documentAnalysisPrompt: String {
        """
        You are an expert at analyzing business documents and extracting key information.
        
        STEP 1: First, identify what type of document this is:
        - invoice: A bill requesting payment for goods/services rendered
        - receipt: Proof of payment for a completed transaction
        - quote: An estimate or proposal for future work
        - work_order: Instructions or details for maintenance/repair work
        - photo: A photograph (not a document with text)
        - warranty: Warranty information or guarantee documentation
        - inspection: Inspection report or checklist
        - other: Any other type of document
        
        STEP 2: Extract relevant information based on the document type.
        
        Please analyze this document and return JSON in this format:
        
        {
            "document_type": "invoice|receipt|quote|work_order|photo|warranty|inspection|other",
            "vendor": "Business/company name",
            "date": "YYYY-MM-DD",
            "description": "Brief summary of the document",
            "subtotal": 145.00,
            "tax": 9.06,
            "total": 154.06,
            "invoice_number": "INV-12345",
            "po_number": "PO-67890",
            "estimated_cost": "$500-700",
            "valid_until": "YYYY-MM-DD",
            "contractor": "Company name",
            "scope": "Description of work",
            "timeline": "Expected completion time",
            "items": ["Item 1", "Item 2"],
            "expense_category": "materials|tools|supplies|labor|other",
            "confidence": 0.95
        }
        
        CRITICAL INSTRUCTIONS FOR FINANCIAL DOCUMENTS:
        
        FOR SUBTOTAL:
        - Amount BEFORE tax is added
        - Look for: "SUBTOTAL", "SUB TOTAL", or sum of line items
        - This is the amount before any taxes
        
        FOR TAX:
        - Tax amount only (the tax portion)
        - Look for: "TAX", "SALES TAX", "GST", "HST", "VAT"
        - This is just the tax amount, not included in subtotal
        
        FOR TOTAL:
        - Final amount the customer actually paid (including tax AND tips)
        - Look for: "PAID", "AMOUNT PAID", "TOTAL PAID", "FINAL TOTAL", "TOTAL"
        - This is the actual amount charged to the customer's payment method
        - For receipts with tips, this will be higher than subtotal + tax
        - Look for payment method lines like "Paid MasterCard", "Paid Visa", etc.
        
        EXAMPLE:
        If a receipt shows:
        - Subtotal: $22.72
        - Tax: $2.28
        - Total (before tips): $25.00
        - Added tips: $2.27
        - Paid MasterCard: $27.27
        
        Then return:
        - "subtotal": 22.72
        - "tax": 2.28
        - "total": 27.27 (the final amount paid)
        
        DOCUMENT-SPECIFIC FIELDS:
        - Invoices: Include invoice_number, po_number, subtotal, tax, total
        - Receipts: Include subtotal, tax, total, items, expense_category
        - Quotes: Include estimated_cost, valid_until, scope
        - Work Orders: Include contractor, scope, timeline
        
        Only include fields that are relevant to the document type. Set confidence based on document clarity.
        """
    }
    
    private var receiptAnalysisPrompt: String {
        """
        You are an expert at analyzing receipts and extracting key information for expense tracking and reimbursement.
        
        Please analyze this receipt image and extract the following information in JSON format:
        
        {
            "vendor": "Name of the store/business",
            "total_amount": 0.00,
            "tax_amount": 0.00,
            "purchase_date": "YYYY-MM-DD",
            "items": ["List of purchased items"],
            "category": "materials|tools|supplies|transportation|other",
            "description": "Brief summary of what was purchased",
            "confidence": 0.0
        }
        
        CRITICAL INSTRUCTIONS FOR AMOUNTS:
        
        FOR TOTAL_AMOUNT:
        - This should be the SUBTOTAL BEFORE TAX (not the final total)
        - Look for labels: "SUBTOTAL", "SUB TOTAL", or the sum of all item prices
        - This is the amount before tax is added
        - Example: If receipt shows Subtotal $5.47, Tax $0.40, Total $5.87
          Then: total_amount = 5.47, tax_amount = 0.40
        
        FOR TAX_AMOUNT:
        - This is the tax portion only
        - Look for labels: "TAX", "SALES TAX", "GST", "HST"
        - This will be added to total_amount by the app to get the final total
        
        IMPORTANT: total_amount should be BEFORE tax, not the final total!
        The app will calculate: Final Total = total_amount + tax_amount
        
        Other Guidelines:
        - Extract the vendor name from the receipt header (store name/logo)
        - Find tax amount (look for "TAX", "SALES TAX", "GST", "HST")
        - Parse the date carefully (MM/DD/YY or DD/MM/YY format)
        - List individual items purchased with their descriptions
        - Categorize based on items: materials (lumber, paint, hardware), tools (drill, hammer), supplies (cleaning, office), transportation (gas, parking), other
        - Create a concise description of what was purchased
        - Provide confidence score (0.0-1.0) based on receipt clarity and text readability
        
        If the total amount is unclear, set confidence to 0.5 or lower and use your best estimate.
        """
    }

    private var maintenanceAnalysisPrompt: String {
        """
        You are a professional restaurant maintenance expert and cost estimator analyzing this image for issues that need repair or attention.
        
        Please analyze this image and provide a detailed maintenance assessment with cost estimation in the following JSON format:
        
        {
            "description": "Detailed description of what you see and any issues identified",
            "recommendations": ["List of specific repair actions needed"],
            "priority": "Urgent|High|Medium|Low",
            "estimatedTime": "Time estimate for repair (e.g., '2-3 hours', '4-6 hours', '1-2 days')",
            "confidence": 0.85,
            "category": "Door/Window|Wall/Paint|Electrical|Plumbing|Furniture|Flooring|HVAC|Kitchen Equipment|Other",
            "materials": ["Specific materials/parts needed with quantities (e.g., '2 sheets drywall', '1 gallon paint', '10 feet PVC pipe')"],
            "safety_concerns": ["Any safety issues identified"],
            "dimensions": "Estimated size/area affected (e.g., '3x4 feet', '2 square feet', 'single outlet')",
            "complexity": "Simple|Moderate|Complex|Requires Specialist",
            "trade_required": "General Handyman|Plumber|Electrician|Carpenter|HVAC Tech|Painter|Drywall Specialist"
        }
        
        Focus specifically on:
        - Structural damage (cracks, holes, dents) - estimate size in square feet
        - Paint/finish issues (chipping, staining, wear) - estimate area to be painted
        - Door/window problems (alignment, hardware, sealing) - identify specific parts needed
        - Electrical issues (outlets, switches, fixtures) - specify exact components
        - Plumbing issues (leaks, clogs, fixtures) - identify pipe sizes and materials
        - Furniture damage (scratches, breaks, instability) - assess repair vs replace
        - HVAC issues (filters, vents, temperature control) - specify parts/services
        - Kitchen equipment (appliances, fixtures) - identify make/model if visible
        - Cleanliness/maintenance issues
        - Safety hazards
        
        CRITICAL FOR COST ESTIMATION:
        - Be SPECIFIC about quantities (e.g., "2 sheets 4x8 drywall" not just "drywall")
        - Estimate dimensions/area affected (e.g., "3x4 foot hole" not just "hole in wall")
        - Identify exact trade needed (electrician rates differ from handyman)
        - Assess complexity realistically (affects labor hours and rates)
        - Note if permits might be required (electrical, plumbing, structural work)
        - Estimate realistic time ranges (e.g., "2-3 hours" for small drywall repair)
        
        Be specific about repair recommendations and realistic about time estimates.
        """
    }
    
    private func parseAnalysisResponse(_ content: String) throws -> ImageAnalysisResult {
        // Extract JSON from markdown code blocks if present
        var jsonString = content
        
        // Remove markdown code block markers
        if content.contains("```json") {
            jsonString = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        print("🔍 Parsing JSON: \(jsonString.prefix(200))...")
        
        // Try to parse JSON response
        if let jsonData = jsonString.data(using: .utf8),
           let analysis = try? JSONDecoder().decode(OpenAIAnalysis.self, from: jsonData) {
            print("✅ Successfully parsed OpenAI analysis")
            return AIAnalysis(
                summary: String(analysis.description.prefix(100)), // Create summary from description
                description: analysis.description,
                category: analysis.category,
                priority: analysis.priority,
                estimatedCost: nil, // OpenAI doesn't provide cost estimates
                timeToComplete: analysis.estimatedTime,
                materialsNeeded: analysis.materials,
                safetyWarnings: analysis.safety_concerns,
                repairInstructions: analysis.recommendations.joined(separator: ". "),
                recommendations: analysis.recommendations,
                confidence: analysis.confidence
            )
        }
        
        print("❌ Failed to parse JSON, content: \(jsonString.prefix(500))")
        throw AIError.invalidResponse
    }
    
    private func parseReceiptAnalysisResponse(_ content: String) throws -> ReceiptAnalysisResult {
        // Extract JSON from markdown code blocks if present
        var jsonString = content
        
        // Remove markdown code block markers
        if content.contains("```json") {
            jsonString = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        print("🔍 Parsing receipt JSON: \(jsonString.prefix(200))...")
        
        // Try to parse JSON response
        if let jsonData = jsonString.data(using: .utf8),
           let analysis = try? JSONDecoder().decode(OpenAIReceiptAnalysis.self, from: jsonData) {
            print("✅ Successfully parsed OpenAI receipt analysis")
            
            // Parse date string to Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let purchaseDate = dateFormatter.date(from: analysis.purchase_date) ?? Date()
            
            // Map category string to ReceiptCategory enum
            let category: ReceiptCategory
            switch analysis.category.lowercased() {
            case "materials": category = .materials
            case "tools": category = .tools
            case "supplies": category = .supplies
            case "transportation": category = .transportation
            default: category = .other
            }
            
            return ReceiptAnalysisResult(
                vendor: analysis.vendor,
                totalAmount: analysis.total_amount,
                taxAmount: analysis.tax_amount > 0 ? analysis.tax_amount : nil,
                purchaseDate: purchaseDate,
                items: analysis.items,
                category: category,
                description: analysis.description,
                confidence: analysis.confidence
            )
        }
        
        print("❌ Failed to parse receipt JSON, content: \(jsonString.prefix(500))")
        throw AIError.invalidResponse
    }
    
    private func parseDocumentAnalysisResponse(_ content: String) throws -> DocumentAnalysisResult {
        // Extract JSON from markdown code blocks if present
        var jsonString = content
        
        // Remove markdown code block markers
        if content.contains("```json") {
            jsonString = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        print("🔍 Parsing document JSON: \(jsonString.prefix(200))...")
        
        // Try to parse JSON response
        if let jsonData = jsonString.data(using: .utf8),
           let analysis = try? JSONDecoder().decode(OpenAIDocumentAnalysis.self, from: jsonData) {
            print("✅ Successfully parsed OpenAI document analysis")
            
            // Parse dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = analysis.date.flatMap { dateFormatter.date(from: $0) }
            let validUntil = analysis.valid_until.flatMap { dateFormatter.date(from: $0) }
            
            // Map document type string to enum
            let documentType: DocumentType
            switch analysis.document_type.lowercased() {
            case "invoice": documentType = .invoice
            case "receipt": documentType = .receipt
            case "quote": documentType = .quote
            case "work_order": documentType = .workOrder
            case "photo": documentType = .photo
            case "warranty": documentType = .warranty
            case "inspection": documentType = .inspection
            default: documentType = .other
            }
            
            return DocumentAnalysisResult(
                documentType: documentType,
                vendor: analysis.vendor,
                date: date,
                description: analysis.description,
                subtotal: analysis.subtotal,
                tax: analysis.tax,
                total: analysis.total,
                invoiceNumber: analysis.invoice_number,
                purchaseOrderNumber: analysis.po_number,
                estimatedCost: analysis.estimated_cost,
                validUntil: validUntil,
                contractor: analysis.contractor,
                scope: analysis.scope,
                timeline: analysis.timeline,
                items: analysis.items,
                expenseCategory: analysis.expense_category,
                confidence: analysis.confidence
            )
        }
        
        print("❌ Failed to parse document JSON, content: \(jsonString.prefix(500))")
        throw AIError.invalidResponse
    }
}

// MARK: - OpenAI API Models

struct OpenAIVisionRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: [OpenAIContent]
}

struct OpenAIContent: Codable {
    let type: String
    let text: String?
    let imageUrl: OpenAIImageURL?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.imageUrl = nil
    }
    
    init(type: String, imageUrl: OpenAIImageURL) {
        self.type = type
        self.text = nil
        self.imageUrl = imageUrl
    }
}

struct OpenAIImageURL: Codable {
    let url: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIResponseMessage
}

struct OpenAIResponseMessage: Codable {
    let content: String
}

struct OpenAIAnalysis: Codable {
    let description: String
    let recommendations: [String]
    let priority: String
    let estimatedTime: String
    let confidence: Double
    let category: String
    let materials: [String]
    let safety_concerns: [String]
    let dimensions: String?
    let complexity: String?
    let trade_required: String?
}

struct OpenAIReceiptAnalysis: Codable {
    let vendor: String
    let total_amount: Double
    let tax_amount: Double
    let purchase_date: String
    let items: [String]
    let category: String
    let description: String
    let confidence: Double
}

struct OpenAIDocumentAnalysis: Codable {
    let document_type: String
    let vendor: String?
    let date: String?
    let description: String?
    let subtotal: Double?
    let tax: Double?
    let total: Double?
    let invoice_number: String?
    let po_number: String?
    let estimated_cost: String?
    let valid_until: String?
    let contractor: String?
    let scope: String?
    let timeline: String?
    let items: [String]?
    let expense_category: String?
    let confidence: Double
}

struct DocumentAnalysisResult {
    let documentType: DocumentType
    let vendor: String?
    let date: Date?
    let description: String?
    let subtotal: Double?
    let tax: Double?
    let total: Double?
    let invoiceNumber: String?
    let purchaseOrderNumber: String?
    let estimatedCost: String?
    let validUntil: Date?
    let contractor: String?
    let scope: String?
    let timeline: String?
    let items: [String]?
    let expenseCategory: String?
    let confidence: Double
}

// MARK: - Image Optimization Extension
extension OpenAIService {
    /// Resizes image to optimal size for AI analysis (reduces processing time and API costs)
    private func resizeImageForAnalysis(_ image: UIImage) -> UIImage {
        // SPEED OPTIMIZATION: Smaller target size for faster processing
        let maxDimension: CGFloat = 768 // Reduced from 1024 for 2x faster processing
        let currentSize = image.size
        
        // If image is already small enough, return as-is
        if max(currentSize.width, currentSize.height) <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = currentSize.width / currentSize.height
        let newSize: CGSize
        
        if currentSize.width > currentSize.height {
            // Landscape: limit width
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait: limit height
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Resize the image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
}

