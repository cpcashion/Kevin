import Foundation

// MARK: - AI Insights Models

struct AIInsight {
    let id: String
    let title: String
    let description: String
    let confidence: Double // 0.0 to 1.0
    let priority: InsightPriority
    let category: InsightCategory
    let actionable: Bool
    let createdAt: Date
    
    enum InsightPriority: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    enum InsightCategory: String, CaseIterable {
        case trending = "Trending Issues"
        case preventive = "Preventive Maintenance"
        case cost = "Cost Optimization"
        case seasonal = "Seasonal Patterns"
        case performance = "Performance Analysis"
        case safety = "Safety Concerns"
    }
}

// MARK: - AI Insights Service

@MainActor
class AIInsightsService: ObservableObject {
    static let shared = AIInsightsService()
    
    @Published var currentInsight: AIInsight?
    @Published var isAnalyzing = false
    @Published var lastAnalysisDate: Date?
    
    private init() {}
    
    /// Analyze all issues and generate AI insights
    func analyzeIssues(_ issues: [Issue]) async {
        guard !issues.isEmpty else {
            currentInsight = nil
            return
        }
        
        isAnalyzing = true
        
        // Simulate AI analysis delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let insight = await generateInsight(from: issues)
        
        currentInsight = insight
        lastAnalysisDate = Date()
        isAnalyzing = false
    }
    
    /// Generate insights based on real issue data
    private func generateInsight(from issues: [Issue]) async -> AIInsight {
        let analysisResults = analyzeIssuePatterns(issues)
        
        // Determine the most significant insight
        if let trendingInsight = generateTrendingInsight(from: analysisResults) {
            return trendingInsight
        } else if let preventiveInsight = generatePreventiveInsight(from: analysisResults) {
            return preventiveInsight
        } else if let costInsight = generateCostInsight(from: analysisResults) {
            return costInsight
        } else if let performanceInsight = generatePerformanceInsight(from: analysisResults) {
            return performanceInsight
        } else {
            return generateDefaultInsight(from: analysisResults)
        }
    }
    
    /// Analyze patterns in the issues
    private func analyzeIssuePatterns(_ issues: [Issue]) -> IssueAnalysis {
        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        
        // Recent issues (last 7 days)
        let recentIssues = issues.filter { $0.createdAt >= oneWeekAgo }
        let previousWeekIssues = issues.filter { $0.createdAt >= twoWeeksAgo && $0.createdAt < oneWeekAgo }
        
        // Category analysis
        let categoryCount = Dictionary(grouping: recentIssues) { issue in
            extractCategory(from: issue)
        }.mapValues { $0.count }
        
        let previousCategoryCount = Dictionary(grouping: previousWeekIssues) { issue in
            extractCategory(from: issue)
        }.mapValues { $0.count }
        
        // Status analysis
        let openIssues = issues.filter { $0.status == .reported || $0.status == .in_progress }
        let completedIssues = issues.filter { $0.status == .completed }
        
        // Priority analysis
        let highPriorityIssues = issues.filter { $0.priority == .high }
        
        // Location analysis
        let locationCount = Dictionary(grouping: issues) { $0.locationId }.mapValues { $0.count }
        
        return IssueAnalysis(
            totalIssues: issues.count,
            recentIssues: recentIssues.count,
            previousWeekIssues: previousWeekIssues.count,
            openIssues: openIssues.count,
            completedIssues: completedIssues.count,
            highPriorityIssues: highPriorityIssues.count,
            categoryCount: categoryCount,
            previousCategoryCount: previousCategoryCount,
            locationCount: locationCount,
            averageResolutionTime: calculateAverageResolutionTime(completedIssues)
        )
    }
    
    /// Extract category from issue
    private func extractCategory(from issue: Issue) -> String {
        // Use AI analysis category if available
        if let aiCategory = issue.aiAnalysis?.category {
            return aiCategory.lowercased()
        }
        
        // Use issue type if available
        if let type = issue.type {
            return type.lowercased()
        }
        
        // Extract from title/description
        let text = "\(issue.title) \(issue.description ?? "")".lowercased()
        
        if text.contains("door") || text.contains("lock") || text.contains("handle") {
            return "door"
        } else if text.contains("hvac") || text.contains("air") || text.contains("heating") || text.contains("cooling") {
            return "hvac"
        } else if text.contains("electrical") || text.contains("light") || text.contains("outlet") || text.contains("power") {
            return "electrical"
        } else if text.contains("plumbing") || text.contains("water") || text.contains("leak") || text.contains("pipe") {
            return "plumbing"
        } else if text.contains("kitchen") || text.contains("equipment") || text.contains("appliance") {
            return "kitchen equipment"
        } else if text.contains("floor") || text.contains("ceiling") || text.contains("wall") {
            return "structural"
        } else {
            return "general"
        }
    }
    
    /// Calculate average resolution time
    private func calculateAverageResolutionTime(_ completedIssues: [Issue]) -> TimeInterval {
        guard !completedIssues.isEmpty else { return 0 }
        
        let totalTime = completedIssues.reduce(0.0) { total, issue in
            return total + issue.updatedAt.timeIntervalSince(issue.createdAt)
        }
        
        return totalTime / Double(completedIssues.count)
    }
    
    /// Generate trending insight
    private func generateTrendingInsight(from analysis: IssueAnalysis) -> AIInsight? {
        guard analysis.previousWeekIssues > 0 else { return nil }
        
        // Find categories with significant increases
        for (category, currentCount) in analysis.categoryCount {
            let previousCount = analysis.previousCategoryCount[category] ?? 0
            
            if currentCount >= 2 && previousCount > 0 {
                let percentIncrease = Double(currentCount - previousCount) / Double(previousCount) * 100
                
                if percentIncrease >= 50 { // 50% or more increase
                    let confidence = min(0.95, 0.6 + (percentIncrease / 200)) // Scale confidence based on increase
                    
                    return AIInsight(
                        id: UUID().uuidString,
                        title: "Trending Issue Alert",
                        description: "\(category.capitalized) issues increased \(Int(percentIncrease))% this week (\(currentCount) vs \(previousCount) last week). Consider preventive maintenance or inspection of \(category) systems.",
                        confidence: confidence,
                        priority: .high,  // All high priority (critical removed)
                        category: .trending,
                        actionable: true,
                        createdAt: Date()
                    )
                }
            }
        }
        
        return nil
    }
    
    /// Generate preventive maintenance insight
    private func generatePreventiveInsight(from analysis: IssueAnalysis) -> AIInsight? {
        // Look for recurring issues in same location
        let problematicLocations = analysis.locationCount.filter { $0.value >= 3 }
        
        if let (locationId, count) = problematicLocations.max(by: { $0.value < $1.value }) {
            // Get business name from location ID
            let locationName = getLocationName(for: locationId)
            
            return AIInsight(
                id: UUID().uuidString,
                title: "Preventive Maintenance Opportunity",
                description: "\(locationName) has \(count) reported issues. This suggests underlying maintenance needs. Schedule comprehensive inspection to prevent future problems.",
                confidence: 0.78,
                priority: count >= 5 ? .high : .medium,
                category: .preventive,
                actionable: true,
                createdAt: Date()
            )
        }
        
        return nil
    }
    
    /// Get location name from ID (synchronous fallback)
    private func getLocationName(for locationId: String) -> String {
        // Try to get from Google Places cache if it's a Google Place ID
        if locationId.starts(with: "ChIJ") {
            // For now, return a placeholder - in production this would fetch from cache
            return "this location"
        }
        return "this location"
    }
    
    /// Generate cost optimization insight
    private func generateCostInsight(from analysis: IssueAnalysis) -> AIInsight? {
        let resolutionRate = Double(analysis.completedIssues) / Double(analysis.totalIssues)
        
        if analysis.openIssues >= 3 && resolutionRate < 0.7 {
            return AIInsight(
                id: UUID().uuidString,
                title: "Cost Optimization Alert",
                description: "\(analysis.openIssues) open issues with \(Int(resolutionRate * 100))% resolution rate. Faster resolution could reduce emergency repair costs by 30-50%.",
                confidence: 0.72,
                priority: .medium,
                category: .cost,
                actionable: true,
                createdAt: Date()
            )
        }
        
        return nil
    }
    
    /// Generate performance insight
    private func generatePerformanceInsight(from analysis: IssueAnalysis) -> AIInsight? {
        if analysis.averageResolutionTime > 0 {
            let avgDays = analysis.averageResolutionTime / (24 * 3600)
            
            if avgDays > 3 {
                return AIInsight(
                    id: UUID().uuidString,
                    title: "Response Time Analysis",
                    description: "Average resolution time is \(String(format: "%.1f", avgDays)) days. Faster response could improve customer satisfaction and prevent issue escalation.",
                    confidence: 0.85,
                    priority: avgDays > 7 ? .high : .medium,
                    category: .performance,
                    actionable: true,
                    createdAt: Date()
                )
            }
        }
        
        return nil
    }
    
    /// Generate default insight when no specific patterns found
    private func generateDefaultInsight(from analysis: IssueAnalysis) -> AIInsight {
        if analysis.totalIssues == 0 {
            return AIInsight(
                id: UUID().uuidString,
                title: "System Status",
                description: "No maintenance issues reported. System appears to be operating normally. Continue regular preventive maintenance schedules.",
                confidence: 0.90,
                priority: .low,
                category: .performance,
                actionable: false,
                createdAt: Date()
            )
        } else {
            let completionRate = Double(analysis.completedIssues) / Double(analysis.totalIssues) * 100
            
            return AIInsight(
                id: UUID().uuidString,
                title: "Maintenance Overview",
                description: "\(analysis.totalIssues) total issues tracked with \(Int(completionRate))% completion rate. \(analysis.openIssues) issues currently need attention.",
                confidence: 0.95,
                priority: analysis.openIssues > 5 ? .medium : .low,
                category: .performance,
                actionable: analysis.openIssues > 0,
                createdAt: Date()
            )
        }
    }
}

// MARK: - Supporting Models

struct IssueAnalysis {
    let totalIssues: Int
    let recentIssues: Int
    let previousWeekIssues: Int
    let openIssues: Int
    let completedIssues: Int
    let highPriorityIssues: Int
    let categoryCount: [String: Int]
    let previousCategoryCount: [String: Int]
    let locationCount: [String: Int]
    let averageResolutionTime: TimeInterval
}
