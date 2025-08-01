import Foundation
import FirebaseFirestore
import Combine

struct LocationStats {
  let locationId: String
  let openIssuesCount: Int
  let completedIssuesCount: Int
  let averageResponseTime: String
  let aiHealthScore: Int
  let isOnline: Bool
  let lastSync: String
}

@MainActor
class LocationStatsService: ObservableObject {
  private let db = Firestore.firestore()
  private var listeners: [String: ListenerRegistration] = [:]
  
  @Published var locationStats: [String: LocationStats] = [:]
  
  func startListening(for locationIds: [String]) {
    print("📊 [LocationStatsService] Starting to listen for stats for \(locationIds.count) locations")
    
    // Stop existing listeners
    stopAllListeners()
    
    // Start new listeners for each location
    for locationId in locationIds {
      startListeningToLocation(locationId)
    }
  }
  
  func stopAllListeners() {
    print("📊 [LocationStatsService] Stopping all location stats listeners")
    for (_, listener) in listeners {
      listener.remove()
    }
    listeners.removeAll()
  }
  
  private func startListeningToLocation(_ locationId: String) {
    print("📊 [LocationStatsService] Starting listener for location: \(locationId)")
    
    // Listen to issues for this location
    let listener = db.collection("issues")
      .whereField("locationId", isEqualTo: locationId)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        
        if let error = error {
          print("❌ [LocationStatsService] Error listening to issues for location \(locationId): \(error)")
          return
        }
        
        guard let documents = snapshot?.documents else {
          print("📊 [LocationStatsService] No issues found for location \(locationId)")
          self.updateLocationStats(locationId: locationId, issues: [])
          return
        }
        
        let issues = documents.compactMap { doc -> Issue? in
          do {
            let data = doc.data()
            
            // Extract basic fields
            guard let reporterId = data["reporterId"] as? String,
                  let title = data["title"] as? String,
                  let priorityString = data["priority"] as? String,
                  let statusString = data["status"] as? String,
                  let priority = IssuePriority(rawValue: priorityString),
                  let status = IssueStatus(rawValue: statusString),
                  let createdAtTimestamp = data["createdAt"] as? Timestamp else {
              print("❌ [LocationStatsService] Missing required fields in issue document")
              return nil
            }
            
            let createdAt = createdAtTimestamp.dateValue()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
            
            // Parse AI analysis if present
            var aiAnalysis: AIAnalysis? = nil
            if let aiAnalysisString = data["aiAnalysis"] as? String,
               let aiAnalysisData = aiAnalysisString.data(using: .utf8) {
              aiAnalysis = try? JSONDecoder().decode(AIAnalysis.self, from: aiAnalysisData)
            }
            
            return Issue(
              id: doc.documentID,
              restaurantId: data["restaurantId"] as? String ?? "",
              locationId: data["locationId"] as? String ?? "",
              reporterId: reporterId,
              title: title,
              description: data["description"] as? String,
              type: data["type"] as? String,
              priority: priority,
              status: status,
              photoUrls: data["photoUrls"] as? [String],
              aiAnalysis: aiAnalysis,
              createdAt: createdAt,
              updatedAt: updatedAt
            )
          } catch {
            print("❌ [LocationStatsService] Error decoding issue: \(error)")
            return nil
          }
        }
        
        print("📊 [LocationStatsService] Loaded \(issues.count) issues for location \(locationId)")
        Task { @MainActor in
          self.updateLocationStats(locationId: locationId, issues: issues)
        }
      }
    
    listeners[locationId] = listener
  }
  
  private func updateLocationStats(locationId: String, issues: [Issue]) {
    let openIssues = issues.filter { issue in
      switch issue.status {
      case .reported, .in_progress:
        return true
      case .completed:
        return false
      }
    }
    
    let completedIssues = issues.filter { $0.status == .completed }
    
    // Calculate average response time (time from creation to first status change)
    let responseTimes = issues.compactMap { issue -> TimeInterval? in
      guard issue.status != .reported else { return nil }
      return issue.updatedAt.timeIntervalSince(issue.createdAt)
    }
    
    let averageResponseTimeInterval = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
    let averageResponseTime = formatResponseTime(averageResponseTimeInterval)
    
    // Calculate AI Health Score based on issue resolution rate and response time
    let aiHealthScore = calculateHealthScore(
      totalIssues: issues.count,
      completedIssues: completedIssues.count,
      averageResponseTime: averageResponseTimeInterval
    )
    
    // Simulate online status and last sync (in real app, this would come from device/system status)
    let isOnline = true
    let lastSync = "2m ago"
    
    let stats = LocationStats(
      locationId: locationId,
      openIssuesCount: openIssues.count,
      completedIssuesCount: completedIssues.count,
      averageResponseTime: averageResponseTime,
      aiHealthScore: aiHealthScore,
      isOnline: isOnline,
      lastSync: lastSync
    )
    
    locationStats[locationId] = stats
    
    print("📊 [LocationStatsService] Updated stats for location \(locationId):")
    print("   - Open Issues: \(openIssues.count)")
    print("   - Completed: \(completedIssues.count)")
    print("   - Avg Response: \(averageResponseTime)")
    print("   - Health Score: \(aiHealthScore)%")
  }
  
  private func formatResponseTime(_ timeInterval: TimeInterval) -> String {
    if timeInterval == 0 {
      return "N/A"
    }
    
    let hours = timeInterval / 3600
    if hours >= 24 {
      let days = Int(hours / 24)
      return "\(days)d"
    } else if hours >= 1 {
      return String(format: "%.1fh", hours)
    } else {
      let minutes = Int(timeInterval / 60)
      return "\(minutes)m"
    }
  }
  
  private func calculateHealthScore(totalIssues: Int, completedIssues: Int, averageResponseTime: TimeInterval) -> Int {
    guard totalIssues > 0 else { return 95 } // Default high score for locations with no issues
    
    // Base score from completion rate (0-70 points)
    let completionRate = Double(completedIssues) / Double(totalIssues)
    let completionScore = completionRate * 70
    
    // Response time score (0-30 points)
    // Excellent: < 2 hours (30 pts), Good: < 8 hours (20 pts), Fair: < 24 hours (10 pts), Poor: > 24 hours (0 pts)
    let responseScore: Double
    if averageResponseTime == 0 {
      responseScore = 15 // Neutral score if no response data
    } else if averageResponseTime < 7200 { // < 2 hours
      responseScore = 30
    } else if averageResponseTime < 28800 { // < 8 hours
      responseScore = 20
    } else if averageResponseTime < 86400 { // < 24 hours
      responseScore = 10
    } else {
      responseScore = 0
    }
    
    let totalScore = Int(completionScore + responseScore)
    return min(100, max(0, totalScore))
  }
  
  func getStats(for locationId: String) -> LocationStats? {
    return locationStats[locationId]
  }
}
