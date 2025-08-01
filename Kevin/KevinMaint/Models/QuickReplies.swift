import Foundation

// MARK: - Quick Reply Suggestions

struct QuickReply: Identifiable {
  let id = UUID()
  let text: String
  let icon: String
  let category: QuickReplyCategory
  
  enum QuickReplyCategory {
    case acknowledgment
    case status
    case question
    case completion
    case delay
  }
}

class QuickRepliesProvider {
  static let shared = QuickRepliesProvider()
  
  // Common quick replies for restaurant owners/GMs
  let ownerReplies: [QuickReply] = [
    QuickReply(text: "Thanks for the update!", icon: "hand.thumbsup.fill", category: .acknowledgment),
    QuickReply(text: "When can this be fixed?", icon: "clock.fill", category: .question),
    QuickReply(text: "This is urgent, please prioritize", icon: "exclamationmark.circle.fill", category: .status),
    QuickReply(text: "Approved, please proceed", icon: "checkmark.circle.fill", category: .acknowledgment),
    QuickReply(text: "Can you send photos?", icon: "camera.fill", category: .question),
    QuickReply(text: "What's the estimated cost?", icon: "dollarsign.circle.fill", category: .question),
    QuickReply(text: "Keep me posted", icon: "bell.fill", category: .acknowledgment)
  ]
  
  // Common quick replies for Kevin/Admin
  let adminReplies: [QuickReply] = [
    QuickReply(text: "On it! 👍", icon: "hand.thumbsup.fill", category: .acknowledgment),
    QuickReply(text: "I'll handle this today", icon: "calendar.badge.clock", category: .status),
    QuickReply(text: "Heading there now", icon: "car.fill", category: .status),
    QuickReply(text: "Need more details", icon: "questionmark.circle.fill", category: .question),
    QuickReply(text: "Completed ✅", icon: "checkmark.circle.fill", category: .completion),
    QuickReply(text: "Waiting on parts", icon: "clock.fill", category: .delay),
    QuickReply(text: "ETA 30 minutes", icon: "timer", category: .status),
    QuickReply(text: "Will update shortly", icon: "arrow.clockwise", category: .acknowledgment),
    QuickReply(text: "Sending quote now", icon: "doc.text.fill", category: .status)
  ]
  
  // Context-aware suggestions based on issue status
  func suggestionsFor(issueStatus: String, userRole: String) -> [QuickReply] {
    let baseReplies = userRole == "admin" ? adminReplies : ownerReplies
    
    // Filter based on issue status
    switch issueStatus.lowercased() {
    case "reported", "open":
      return baseReplies.filter { $0.category == .acknowledgment || $0.category == .status }
    case "in_progress":
      return baseReplies.filter { $0.category == .status || $0.category == .question }
    case "waiting":
      return baseReplies.filter { $0.category == .status || $0.category == .delay }
    case "resolved":
      return baseReplies.filter { $0.category == .completion || $0.category == .acknowledgment }
    default:
      return Array(baseReplies.prefix(4))
    }
  }
  
  // AI-powered smart suggestions based on last message
  func smartSuggestionsFor(lastMessage: String, userRole: String) -> [QuickReply] {
    let lowercased = lastMessage.lowercased()
    
    // Question detection
    if lowercased.contains("when") || lowercased.contains("how long") {
      if userRole == "admin" {
        return [
          QuickReply(text: "I'll handle this today", icon: "calendar.badge.clock", category: .status),
          QuickReply(text: "ETA 30 minutes", icon: "timer", category: .status),
          QuickReply(text: "Tomorrow morning", icon: "sunrise.fill", category: .status)
        ]
      } else {
        return [
          QuickReply(text: "As soon as possible please", icon: "exclamationmark.circle.fill", category: .status),
          QuickReply(text: "No rush, whenever works", icon: "clock.fill", category: .acknowledgment)
        ]
      }
    }
    
    // Cost/quote detection
    if lowercased.contains("cost") || lowercased.contains("quote") || lowercased.contains("price") {
      if userRole == "admin" {
        return [
          QuickReply(text: "Sending quote now", icon: "doc.text.fill", category: .status),
          QuickReply(text: "Checking with vendor", icon: "phone.fill", category: .status)
        ]
      } else {
        return [
          QuickReply(text: "Approved, please proceed", icon: "checkmark.circle.fill", category: .acknowledgment),
          QuickReply(text: "Let me review and get back to you", icon: "doc.text.magnifyingglass", category: .acknowledgment)
        ]
      }
    }
    
    // Photo request detection
    if lowercased.contains("photo") || lowercased.contains("picture") || lowercased.contains("image") {
      return [
        QuickReply(text: "Sending photos now", icon: "camera.fill", category: .status),
        QuickReply(text: "I'll take some photos", icon: "camera.fill", category: .acknowledgment)
      ]
    }
    
    // Completion detection
    if lowercased.contains("done") || lowercased.contains("complete") || lowercased.contains("finished") {
      if userRole == "admin" {
        return [
          QuickReply(text: "Completed ✅", icon: "checkmark.circle.fill", category: .completion)
        ]
      } else {
        return [
          QuickReply(text: "Thanks! Looks great", icon: "hand.thumbsup.fill", category: .acknowledgment),
          QuickReply(text: "Perfect, thank you!", icon: "star.fill", category: .acknowledgment)
        ]
      }
    }
    
    // Default suggestions
    return suggestionsFor(issueStatus: "open", userRole: userRole)
  }
}
