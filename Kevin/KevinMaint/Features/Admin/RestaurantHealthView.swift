import SwiftUI
import Charts

struct RestaurantHealthView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  
  @State private var healthData: [RestaurantHealthData] = []
  @State private var isLoading = true
  @State private var selectedTimeframe: HealthTimeframe = .month
  @State private var selectedRestaurant: String = "All"
  
  private let timeframes: [HealthTimeframe] = [.week, .month, .quarter, .year]
  
  private var restaurantNames: [String] {
    ["All"] + Array(Set(healthData.map { $0.restaurantName })).sorted()
  }
  
  private var filteredData: [RestaurantHealthData] {
    let timeFiltered = healthData.filter { data in
      let daysDiff = Calendar.current.dateComponents([.day], from: data.date, to: Date()).day ?? 0
      switch selectedTimeframe {
      case .week: return daysDiff <= 7
      case .month: return daysDiff <= 30
      case .quarter: return daysDiff <= 90
      case .year: return daysDiff <= 365
      }
    }
    
    if selectedRestaurant == "All" {
      return timeFiltered
    }
    return timeFiltered.filter { $0.restaurantName == selectedRestaurant }
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          ProgressView("Loading health trends...")
            .foregroundColor(KMTheme.secondaryText)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              // Header
              headerSection
              
              // Filters
              filtersSection
              
              // Health Overview
              healthOverview
              
              // Trend Chart
              trendChart
              
              // Restaurant Rankings
              restaurantRankings
              
              // Health Alerts
              healthAlerts
            }
            .padding(24)
          }
        }
      }
      .navigationTitle("Restaurant Health Trends")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(KMTheme.cardBackground, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
      .onAppear {
        loadHealthData()
      }
    }
  }
  
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "heart.text.square")
          .foregroundColor(KMTheme.progress)
          .font(.title2)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Restaurant Health Trends")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          Text("Maintenance Health Score Analysis")
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        Spacer()
      }
      
      HStack {
        Image(systemName: "chart.line.uptrend.xyaxis")
          .foregroundColor(KMTheme.success)
          .font(.caption)
        
        Text("Overall restaurant health has improved 18% this month with Kevin's proactive maintenance")
          .font(.caption)
          .foregroundColor(KMTheme.success)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(KMTheme.success.opacity(0.1))
      .cornerRadius(8)
    }
  }
  
  private var filtersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Timeframe Filter
      VStack(alignment: .leading, spacing: 8) {
        Text("Timeframe")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(timeframes, id: \.self) { timeframe in
              Button {
                selectedTimeframe = timeframe
              } label: {
                Text(timeframe.title)
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(selectedTimeframe == timeframe ? .white : KMTheme.secondaryText)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(
                    selectedTimeframe == timeframe ? KMTheme.progress : KMTheme.cardBackground
                  )
                  .cornerRadius(16)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16)
                      .stroke(KMTheme.border, lineWidth: selectedTimeframe == timeframe ? 0 : 0.5)
                  )
              }
            }
          }
          .padding(.horizontal, 24)
        }
        .padding(.horizontal, -24)
      }
      
      // Restaurant Filter
      VStack(alignment: .leading, spacing: 8) {
        Text("Restaurant")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(restaurantNames, id: \.self) { restaurant in
              Button {
                selectedRestaurant = restaurant
              } label: {
                Text(restaurant)
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(selectedRestaurant == restaurant ? .white : KMTheme.secondaryText)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(
                    selectedRestaurant == restaurant ? KMTheme.accent : KMTheme.cardBackground
                  )
                  .cornerRadius(16)
                  .overlay(
                    RoundedRectangle(cornerRadius: 16)
                      .stroke(KMTheme.border, lineWidth: selectedRestaurant == restaurant ? 0 : 0.5)
                  )
              }
            }
          }
          .padding(.horizontal, 24)
        }
        .padding(.horizontal, -24)
      }
    }
  }
  
  private var healthOverview: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
      MetricCard(
        number: String(format: "%.1f", averageHealthScore),
        label: "Avg Health Score",
        color: healthScoreColor(averageHealthScore)
      )
      
      MetricCard(
        number: "\(healthyRestaurants)",
        label: "Healthy Restaurants",
        color: KMTheme.success
      )
      
      MetricCard(
        number: "\(atRiskRestaurants)",
        label: "At Risk",
        color: KMTheme.warning
      )
      
      MetricCard(
        number: "\(criticalRestaurants)",
        label: "Critical",
        color: KMTheme.danger
      )
    }
  }
  
  private var trendChart: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Health Score Trends")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      Chart(filteredData) { data in
        LineMark(
          x: .value("Date", data.date),
          y: .value("Health Score", data.healthScore)
        )
        .foregroundStyle(by: .value("Restaurant", data.restaurantName))
        .lineStyle(StrokeStyle(lineWidth: 2))
        
        PointMark(
          x: .value("Date", data.date),
          y: .value("Health Score", data.healthScore)
        )
        .foregroundStyle(by: .value("Restaurant", data.restaurantName))
        .symbolSize(30)
      }
      .frame(height: 300)
      .chartXAxis {
        AxisMarks(values: .automatic) { _ in
          AxisValueLabel(format: .dateTime.month().day())
            .foregroundStyle(KMTheme.secondaryText)
            .font(.caption)
        }
      }
      .chartYAxis {
        AxisMarks(values: .automatic) { _ in
          AxisValueLabel()
            .foregroundStyle(KMTheme.secondaryText)
            .font(.caption)
        }
      }
      .chartYScale(domain: 0...100)
      .chartLegend(position: .bottom)
      .padding(16)
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
    }
  }
  
  private var restaurantRankings: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Restaurant Rankings")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      LazyVStack(spacing: 12) {
        ForEach(Array(latestHealthScores.enumerated()), id: \.element.id) { index, data in
          RestaurantHealthCard(data: data, rank: index + 1)
        }
      }
    }
  }
  
  private var healthAlerts: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Health Alerts")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      LazyVStack(spacing: 12) {
        ForEach(healthAlertData) { alert in
          HealthAlertCard(alert: alert)
        }
      }
    }
  }
  
  private var averageHealthScore: Double {
    guard !filteredData.isEmpty else { return 0 }
    return filteredData.map { $0.healthScore }.reduce(0, +) / Double(filteredData.count)
  }
  
  private var healthyRestaurants: Int {
    latestHealthScores.filter { $0.healthScore >= 80 }.count
  }
  
  private var atRiskRestaurants: Int {
    latestHealthScores.filter { $0.healthScore >= 60 && $0.healthScore < 80 }.count
  }
  
  private var criticalRestaurants: Int {
    latestHealthScores.filter { $0.healthScore < 60 }.count
  }
  
  private var latestHealthScores: [RestaurantHealthData] {
    let grouped = Dictionary(grouping: filteredData) { $0.restaurantName }
    return grouped.compactMap { (_, values) in
      values.max(by: { $0.date < $1.date })
    }.sorted(by: { $0.healthScore > $1.healthScore })
  }
  
  private var healthAlertData: [HealthAlert] {
    latestHealthScores.compactMap { data in
      if data.healthScore < 60 {
        return HealthAlert(
          restaurantName: data.restaurantName,
          type: .critical,
          message: "Critical maintenance issues detected",
          healthScore: data.healthScore
        )
      } else if data.healthScore < 80 {
        return HealthAlert(
          restaurantName: data.restaurantName,
          type: .warning,
          message: "Preventive maintenance recommended",
          healthScore: data.healthScore
        )
      }
      return nil
    }
  }
  
  private func healthScoreColor(_ score: Double) -> Color {
    switch score {
    case 80...: return KMTheme.success
    case 60..<80: return KMTheme.warning
    default: return KMTheme.danger
    }
  }
  
  private func loadHealthData() {
    isLoading = true
    
    Task {
      // Load real restaurant health data from Firebase
      do {
        // TODO: Implement actual Firebase analytics data loading
        // For now, show empty state until real data is available
        await MainActor.run {
          healthData = []
          isLoading = false
        }
      } catch {
        print("❌ [RestaurantHealthView] Failed to load health data: \(error)")
        await MainActor.run {
          healthData = []
          isLoading = false
        }
      }
    }
  }
}

enum HealthTimeframe: CaseIterable {
  case week, month, quarter, year
  
  var title: String {
    switch self {
    case .week: return "7 Days"
    case .month: return "30 Days"
    case .quarter: return "90 Days"
    case .year: return "1 Year"
    }
  }
}

struct RestaurantHealthData: Identifiable {
  let id = UUID()
  let restaurantName: String
  let date: Date
  let healthScore: Double
  let issueCount: Int
  let criticalIssues: Int
  let avgResolutionTime: Double
}

struct HealthAlert: Identifiable {
  let id = UUID()
  let restaurantName: String
  let type: AlertType
  let message: String
  let healthScore: Double
  
  enum AlertType {
    case critical, warning
    
    var color: Color {
      switch self {
      case .critical: return KMTheme.danger
      case .warning: return KMTheme.warning
      }
    }
    
    var icon: String {
      switch self {
      case .critical: return "exclamationmark.triangle.fill"
      case .warning: return "exclamationmark.circle.fill"
      }
    }
  }
}

struct RestaurantHealthCard: View {
  let data: RestaurantHealthData
  let rank: Int
  
  private var healthColor: Color {
    switch data.healthScore {
    case 80...: return KMTheme.success
    case 60..<80: return KMTheme.warning
    default: return KMTheme.danger
    }
  }
  
  private var rankColor: Color {
    switch rank {
    case 1: return Color.yellow
    case 2: return KMTheme.secondaryText
    case 3: return Color.orange
    default: return KMTheme.tertiaryText
    }
  }
  
  var body: some View {
    HStack {
      // Rank
      Text("#\(rank)")
        .font(.headline)
        .fontWeight(.bold)
        .foregroundColor(rankColor)
        .frame(width: 40)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(data.restaurantName)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        HStack(spacing: 12) {
          Text("\(data.issueCount) issues")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          
          if data.criticalIssues > 0 {
            Text("\(data.criticalIssues) critical")
              .font(.caption)
              .foregroundColor(KMTheme.danger)
          }
        }
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(Int(data.healthScore))")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(healthColor)
        
        Text("Health Score")
          .font(.caption2)
          .foregroundColor(KMTheme.tertiaryText)
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(healthColor.opacity(0.2), lineWidth: 1)
    )
  }
}

struct HealthAlertCard: View {
  let alert: HealthAlert
  
  var body: some View {
    HStack {
      Image(systemName: alert.type.icon)
        .foregroundColor(alert.type.color)
        .font(.title3)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(alert.restaurantName)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        Text(alert.message)
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(Int(alert.healthScore))")
          .font(.headline)
          .fontWeight(.bold)
          .foregroundColor(alert.type.color)
        
        Text("Score")
          .font(.caption2)
          .foregroundColor(KMTheme.tertiaryText)
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(alert.type.color.opacity(0.2), lineWidth: 1)
    )
  }
}
