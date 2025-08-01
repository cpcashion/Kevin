import Foundation
import UIKit

struct AIAnalysisResult {
  let reply: String
  let proposal: AIProposal?
  let timelineEvent: AITimelineEvent?
}

struct AITimelineEvent {
  let type: String
  let title: String
  let bullets: [String]
}

final class AITimelineAnalyst {
  static let shared = AITimelineAnalyst()
  
  private let systemPrompt = """
You are Kevin's Maintenance Timeline Analyst.
Your job is to turn raw inputs into:
  a) short, human-readable reply (≤90 words)
  b) strict JSON for timeline and proposals

Principles:
- Be precise, conservative, audit-friendly
- Set uncertain fields to null
- Never fabricate costs/dates/vendors
- Recommend changes only when justified
- Succinct bullets, neutral tone

Output JSON structure:
{
  "reply": "Brief analysis...",
  "proposal": {
    "proposedStatus": "in_progress|completed|null",
    "proposedPriority": "low|medium|high|critical|null",
    "extractedCost": 157.33,
    "extractedVendor": "Acme Plumbing",
    "extractedInvoiceNumber": "INV-2241",
    "nextAction": "Assign plumber",
    "riskLevel": "low|medium|high",
    "confidence": 0.85,
    "reasoning": "P-trap needs replacement within 48h"
  },
  "timelineEvent": {
    "type": "document_parsed|progress_update|analysis_complete",
    "title": "Invoice parsed from Acme Plumbing",
    "bullets": [
      "Total: $157.33 (tax $12.33) • Invoice #INV-2241",
      "Labor: 2h @ $70/h • Part: 1.25in P-trap"
    ]
  }
}
"""
  
  // MARK: - Analysis Methods
  
  func analyzeMessage(_ text: String, context: MaintenanceRequest) async -> AIAnalysisResult {
    let prompt = """
    \(systemPrompt)
    
    CONTEXT:
    Issue: \(context.title)
    Description: \(context.description)
    Category: \(context.category.rawValue)
    Priority: \(context.priority.rawValue)
    Status: \(context.status.rawValue)
    
    USER MESSAGE: "\(text)"
    
    Analyze this message and provide JSON response:
    """
    
    return await performAnalysis(prompt: prompt)
  }
  
  func analyzePhoto(_ image: UIImage, context: MaintenanceRequest) async -> AIAnalysisResult {
    // For now, return a placeholder analysis
    // TODO: Implement OpenAI Vision API integration
    let prompt = """
    \(systemPrompt)
    
    CONTEXT:
    Issue: \(context.title)
    Description: \(context.description)
    Category: \(context.category.rawValue)
    Priority: \(context.priority.rawValue)
    Status: \(context.status.rawValue)
    
    A photo was uploaded. Analyze the visual information and provide JSON response:
    """
    
    return await performAnalysis(prompt: prompt)
  }
  
  func analyzeReceipt(_ image: UIImage, context: MaintenanceRequest) async -> AIAnalysisResult {
    // Extract text from receipt using Vision framework
    let extractedText = await extractTextFromImage(image)
    
    let prompt = """
    \(systemPrompt)
    
    CONTEXT:
    Issue: \(context.title)
    Description: \(context.description)
    Category: \(context.category.rawValue)
    Priority: \(context.priority.rawValue)
    Status: \(context.status.rawValue)
    
    RECEIPT TEXT: "\(extractedText)"
    
    Parse this receipt and extract costs, vendor, items. Provide JSON response:
    """
    
    return await performAnalysis(prompt: prompt)
  }
  
  func analyzeInvoice(_ image: UIImage, context: MaintenanceRequest) async -> AIAnalysisResult {
    // Extract text from invoice using Vision framework
    let extractedText = await extractTextFromImage(image)
    
    let prompt = """
    \(systemPrompt)
    
    CONTEXT:
    Issue: \(context.title)
    Description: \(context.description)
    Category: \(context.category.rawValue)
    Priority: \(context.priority.rawValue)
    Status: \(context.status.rawValue)
    
    INVOICE TEXT: "\(extractedText)"
    
    Parse this invoice and extract vendor, invoice number, costs, line items. Provide JSON response:
    """
    
    return await performAnalysis(prompt: prompt)
  }
  
  func analyzeVoice(_ transcription: String, context: MaintenanceRequest) async -> AIAnalysisResult {
    let prompt = """
    \(systemPrompt)
    
    CONTEXT:
    Issue: \(context.title)
    Description: \(context.description)
    Category: \(context.category.rawValue)
    Priority: \(context.priority.rawValue)
    Status: \(context.status.rawValue)
    
    VOICE TRANSCRIPTION: "\(transcription)"
    
    Analyze this voice note for completion keywords, urgency, cost mentions. Provide JSON response:
    """
    
    return await performAnalysis(prompt: prompt)
  }
  
  // MARK: - Private Methods
  
  private func performAnalysis(prompt: String) async -> AIAnalysisResult {
    // For now, return mock data
    // TODO: Implement actual OpenAI API call
    
    // Simulate API delay
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    
    // Mock response based on prompt content
    let mockReply = generateMockReply(from: prompt)
    let mockProposal = generateMockProposal(from: prompt)
    let mockEvent = generateMockTimelineEvent(from: prompt)
    
    return AIAnalysisResult(
      reply: mockReply,
      proposal: mockProposal,
      timelineEvent: mockEvent
    )
  }
  
  private func generateMockReply(from prompt: String) -> String {
    if prompt.contains("RECEIPT") {
      return "Receipt processed. Found vendor and total cost. Recommend updating status to reflect work completion."
    } else if prompt.contains("INVOICE") {
      return "Invoice parsed successfully. Extracted vendor details and line items. Cost appears reasonable for scope of work."
    } else if prompt.contains("VOICE") {
      return "Voice note analyzed. Detected progress update with completion indicators. Recommend status change."
    } else if prompt.contains("photo") {
      return "Photo analyzed. Visual inspection shows progress on repair work. Quality appears satisfactory."
    } else {
      return "Message analyzed. Progress update noted. Continue monitoring for completion."
    }
  }
  
  private func generateMockProposal(from prompt: String) -> AIProposal? {
    if prompt.contains("RECEIPT") || prompt.contains("INVOICE") {
      return AIProposal(
        proposedStatus: .completed,
        proposedPriority: nil,
        extractedCost: 157.33,
        extractedVendor: "Mock Repair Co",
        extractedInvoiceNumber: "INV-2024-001",
        nextAction: "Verify work completion",
        riskLevel: .low,
        confidence: 0.85,
        reasoning: "Receipt indicates work completion with reasonable cost"
      )
    } else if prompt.contains("completed") || prompt.contains("finished") || prompt.contains("done") {
      return AIProposal(
        proposedStatus: .completed,
        proposedPriority: nil,
        extractedCost: nil,
        extractedVendor: nil,
        extractedInvoiceNumber: nil,
        nextAction: "Close issue",
        riskLevel: .low,
        confidence: 0.75,
        reasoning: "User indicates work completion"
      )
    } else if prompt.contains("urgent") || prompt.contains("emergency") {
      return AIProposal(
        proposedStatus: nil,
        proposedPriority: .high,  // Changed from .critical (removed)
        extractedCost: nil,
        extractedVendor: nil,
        extractedInvoiceNumber: nil,
        nextAction: "Escalate immediately",
        riskLevel: .high,
        confidence: 0.90,
        reasoning: "Urgent language detected"
      )
    }
    
    return nil
  }
  
  private func generateMockTimelineEvent(from prompt: String) -> AITimelineEvent? {
    if prompt.contains("RECEIPT") {
      return AITimelineEvent(
        type: "document_parsed",
        title: "Receipt processed",
        bullets: [
          "Vendor: Mock Repair Co",
          "Total: $157.33 (tax $12.33)",
          "Items: Labor 2h, Parts 1x"
        ]
      )
    } else if prompt.contains("INVOICE") {
      return AITimelineEvent(
        type: "document_parsed",
        title: "Invoice analyzed",
        bullets: [
          "Invoice #INV-2024-001",
          "Vendor: Mock Repair Co",
          "Total: $157.33"
        ]
      )
    } else if prompt.contains("VOICE") {
      return AITimelineEvent(
        type: "progress_update",
        title: "Voice note analyzed",
        bullets: [
          "Progress indicators detected",
          "Work appears on track",
          "No issues reported"
        ]
      )
    }
    
    return AITimelineEvent(
      type: "analysis_complete",
      title: "Message analyzed",
      bullets: [
        "Content processed successfully",
        "No immediate action required"
      ]
    )
  }
  
  private func extractTextFromImage(_ image: UIImage) async -> String {
    // TODO: Implement Vision framework OCR
    // For now, return placeholder text
    return "Mock extracted text from image"
  }
}

// MARK: - Extensions

extension MaintenanceRequest {
  func toContextString() -> String {
    return """
    Title: \(title)
    Description: \(description)
    Category: \(category.rawValue)
    Priority: \(priority.rawValue)
    Status: \(status.rawValue)
    """
  }
}
