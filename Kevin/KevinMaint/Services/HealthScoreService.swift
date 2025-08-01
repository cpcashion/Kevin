import Foundation

struct HealthScoreService {
  static let shared = HealthScoreService()
  
  private init() {}
  
  // MARK: - Health Score Calculation
  
  func calculateHealthScore(
    for restaurantId: String,
    issues: [Issue],
    receipts: [Receipt],
    subscription: Subscription?
  ) async -> HealthScoreResult {
    
    // Simplified implementation for now
    let overallScore = 85 // Mock score
    
    let issueScore = ScoreComponent(
      score: 80,
      title: "Issue Management",
      description: "Based on active issues",
      factors: ["Sample factor"]
    )
    
    let maintenanceScore = ScoreComponent(
      score: 90,
      title: "Maintenance Efficiency", 
      description: "Based on resolution performance",
      factors: ["Sample factor"]
    )
    
    let costScore = ScoreComponent(
      score: 85,
      title: "Cost Management",
      description: "Based on spending efficiency",
      factors: ["Sample factor"]
    )
    
    let subscriptionScore = ScoreComponent(
      score: 90,
      title: "Subscription Health",
      description: "Based on plan status",
      factors: ["Sample factor"]
    )
    
    return HealthScoreResult(
      overallScore: overallScore,
      issueScore: issueScore,
      maintenanceScore: maintenanceScore,
      costScore: costScore,
      subscriptionScore: subscriptionScore,
      recommendations: []
    )
  }
}

// MARK: - Data Models

struct HealthScoreResult {
  let overallScore: Int
  let issueScore: ScoreComponent
  let maintenanceScore: ScoreComponent
  let costScore: ScoreComponent
  let subscriptionScore: ScoreComponent
  let recommendations: [HealthRecommendation]
  
  var scoreColor: String {
    switch overallScore {
    case 80...100: return "green"
    case 60...79: return "orange"
    default: return "red"
    }
  }
  
  var scoreDescription: String {
    switch overallScore {
    case 90...100: return "Excellent"
    case 80...89: return "Good"
    case 70...79: return "Fair"
    case 60...69: return "Poor"
    default: return "Critical"
    }
  }
}

struct ScoreComponent {
  let score: Int
  let title: String
  let description: String
  let factors: [String]
  
  var color: String {
    switch score {
    case 80...100: return "green"
    case 60...79: return "orange"
    default: return "red"
    }
  }
}

struct HealthRecommendation {
  let type: RecommendationType
  let title: String
  let description: String
  let action: String
  
  enum RecommendationType {
    case critical, warning, info
    
    var color: String {
      switch self {
      case .critical: return "red"
      case .warning: return "orange"
      case .info: return "blue"
      }
    }
    
    var icon: String {
      switch self {
      case .critical: return "exclamationmark.triangle.fill"
      case .warning: return "exclamationmark.circle.fill"
      case .info: return "info.circle.fill"
      }
    }
  }
}
