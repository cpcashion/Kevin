import SwiftUI

struct AIAccuracyView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  
  @State private var accuracyData: [AIAccuracyData] = []
  @State private var isLoading = true
  @State private var selectedMetric: AccuracyMetric = .assessment
  
  private let metrics: [AccuracyMetric] = [.assessment, .costPrediction, .timeEstimation, .categoryClassification]
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          ProgressView("Loading AI accuracy data...")
            .foregroundColor(KMTheme.secondaryText)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              // Header
              headerSection
              
              // Metric Selector
              metricSelector
              
              // Overall Performance
              overallPerformance
              
              // Accuracy Heatmap
              accuracyHeatmap
              
              // Detailed Breakdown
              detailedBreakdown
            }
            .padding(24)
          }
        }
      }
      .navigationTitle("AI Analysis Accuracy")
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
        loadAccuracyData()
      }
    }
  }
  
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "brain.head.profile")
          .foregroundColor(KMTheme.aiGreen)
          .font(.title2)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("AI Analysis Accuracy")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          Text("GPT-4 Vision Performance Metrics")
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        Spacer()
      }
      
      HStack {
        Image(systemName: "checkmark.seal.fill")
          .foregroundColor(KMTheme.success)
          .font(.caption)
        
        Text("AI accuracy has improved 23% over the last 30 days through continuous learning")
          .font(.caption)
          .foregroundColor(KMTheme.success)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(KMTheme.success.opacity(0.1))
      .cornerRadius(8)
    }
  }
  
  private var metricSelector: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Analysis Type")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(metrics, id: \.self) { metric in
            Button {
              selectedMetric = metric
            } label: {
              VStack(spacing: 4) {
                Text(metric.title)
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(selectedMetric == metric ? .white : KMTheme.secondaryText)
                
                Text("\(Int(overallAccuracy(for: metric) * 100))%")
                  .font(.caption2)
                  .fontWeight(.bold)
                  .foregroundColor(selectedMetric == metric ? .white : accuracyColor(overallAccuracy(for: metric)))
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(
                selectedMetric == metric ? KMTheme.aiGreen : KMTheme.cardBackground
              )
              .cornerRadius(12)
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(KMTheme.border, lineWidth: selectedMetric == metric ? 0 : 0.5)
              )
            }
          }
        }
        .padding(.horizontal, 24)
      }
      .padding(.horizontal, -24)
    }
  }
  
  private var overallPerformance: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
      MetricCard(
        number: "\(Int(overallAccuracy(for: selectedMetric) * 100))%",
        label: "Overall Accuracy",
        color: accuracyColor(overallAccuracy(for: selectedMetric))
      )
      
      MetricCard(
        number: "\(totalAnalyses)",
        label: "Total Analyses",
        color: KMTheme.accent
      )
      
      MetricCard(
        number: "+23%",
        label: "30-Day Improvement",
        color: KMTheme.success
      )
      
      MetricCard(
        number: "\(highPerformanceCategories)",
        label: "High Performance",
        color: KMTheme.progress
      )
    }
  }
  
  private var accuracyHeatmap: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Accuracy Heatmap")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      VStack(spacing: 8) {
        // Header row
        HStack {
          Text("Category")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
            .frame(width: 100, alignment: .leading)
          
          ForEach(metrics, id: \.self) { metric in
            Text(metric.shortTitle)
              .font(.caption2)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KMTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
        
        // Data rows
        ForEach(accuracyData) { data in
          HStack {
            Text(data.category)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
              .frame(width: 100, alignment: .leading)
            
            ForEach(metrics, id: \.self) { metric in
              let accuracy = data.accuracy(for: metric)
              
              Rectangle()
                .fill(accuracyColor(accuracy))
                .frame(height: 32)
                .cornerRadius(4)
                .overlay(
                  Text("\(Int(accuracy * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                )
                .frame(maxWidth: .infinity)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 4)
        }
      }
      .padding(16)
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
    }
  }
  
  private var detailedBreakdown: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Performance Details")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      LazyVStack(spacing: 12) {
        ForEach(accuracyData.sorted(by: { $0.accuracy(for: selectedMetric) > $1.accuracy(for: selectedMetric) })) { data in
          AccuracyDetailCard(data: data, metric: selectedMetric)
        }
      }
    }
  }
  
  private func overallAccuracy(for metric: AccuracyMetric) -> Double {
    guard !accuracyData.isEmpty else { return 0 }
    return accuracyData.map { $0.accuracy(for: metric) }.reduce(0, +) / Double(accuracyData.count)
  }
  
  private var totalAnalyses: Int {
    accuracyData.map { $0.totalAnalyses }.reduce(0, +)
  }
  
  private var highPerformanceCategories: Int {
    accuracyData.filter { $0.accuracy(for: selectedMetric) >= 0.85 }.count
  }
  
  private func accuracyColor(_ accuracy: Double) -> Color {
    switch accuracy {
    case 0.9...: return KMTheme.success
    case 0.8..<0.9: return KMTheme.aiGreen
    case 0.7..<0.8: return KMTheme.warning
    default: return KMTheme.danger
    }
  }
  
  private func loadAccuracyData() {
    Task {
      // Simulate loading real data - in production this would come from AI analytics
      await MainActor.run {
        accuracyData = [
          AIAccuracyData(
            category: "Electrical",
            assessmentAccuracy: 0.94,
            costAccuracy: 0.87,
            timeAccuracy: 0.91,
            categoryAccuracy: 0.98,
            totalAnalyses: 156
          ),
          AIAccuracyData(
            category: "Plumbing",
            assessmentAccuracy: 0.91,
            costAccuracy: 0.83,
            timeAccuracy: 0.88,
            categoryAccuracy: 0.96,
            totalAnalyses: 203
          ),
          AIAccuracyData(
            category: "HVAC",
            assessmentAccuracy: 0.89,
            costAccuracy: 0.79,
            timeAccuracy: 0.85,
            categoryAccuracy: 0.94,
            totalAnalyses: 127
          ),
          AIAccuracyData(
            category: "Kitchen Equipment",
            assessmentAccuracy: 0.96,
            costAccuracy: 0.92,
            timeAccuracy: 0.94,
            categoryAccuracy: 0.99,
            totalAnalyses: 284
          ),
          AIAccuracyData(
            category: "Structural",
            assessmentAccuracy: 0.85,
            costAccuracy: 0.74,
            timeAccuracy: 0.81,
            categoryAccuracy: 0.92,
            totalAnalyses: 89
          ),
          AIAccuracyData(
            category: "Cleaning",
            assessmentAccuracy: 0.97,
            costAccuracy: 0.95,
            timeAccuracy: 0.96,
            categoryAccuracy: 0.99,
            totalAnalyses: 341
          )
        ]
        isLoading = false
      }
    }
  }
}

enum AccuracyMetric: CaseIterable {
  case assessment
  case costPrediction
  case timeEstimation
  case categoryClassification
  
  var title: String {
    switch self {
    case .assessment: return "Damage Assessment"
    case .costPrediction: return "Cost Prediction"
    case .timeEstimation: return "Time Estimation"
    case .categoryClassification: return "Category Classification"
    }
  }
  
  var shortTitle: String {
    switch self {
    case .assessment: return "Assessment"
    case .costPrediction: return "Cost"
    case .timeEstimation: return "Time"
    case .categoryClassification: return "Category"
    }
  }
}

struct AIAccuracyData: Identifiable {
  let id = UUID()
  let category: String
  let assessmentAccuracy: Double
  let costAccuracy: Double
  let timeAccuracy: Double
  let categoryAccuracy: Double
  let totalAnalyses: Int
  
  func accuracy(for metric: AccuracyMetric) -> Double {
    switch metric {
    case .assessment: return assessmentAccuracy
    case .costPrediction: return costAccuracy
    case .timeEstimation: return timeAccuracy
    case .categoryClassification: return categoryAccuracy
    }
  }
}

struct AccuracyDetailCard: View {
  let data: AIAccuracyData
  let metric: AccuracyMetric
  
  private var accuracy: Double {
    data.accuracy(for: metric)
  }
  
  private var accuracyColor: Color {
    switch accuracy {
    case 0.9...: return KMTheme.success
    case 0.8..<0.9: return KMTheme.aiGreen
    case 0.7..<0.8: return KMTheme.warning
    default: return KMTheme.danger
    }
  }
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(data.category)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        Text("\(data.totalAnalyses) analyses")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(Int(accuracy * 100))%")
          .font(.title3)
          .fontWeight(.bold)
          .foregroundColor(accuracyColor)
        
        HStack(spacing: 4) {
          Circle()
            .fill(accuracyColor)
            .frame(width: 8, height: 8)
          
          Text(performanceLabel)
            .font(.caption2)
            .foregroundColor(accuracyColor)
        }
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(accuracyColor.opacity(0.2), lineWidth: 1)
    )
  }
  
  private var performanceLabel: String {
    switch accuracy {
    case 0.95...: return "Excellent"
    case 0.9..<0.95: return "Very Good"
    case 0.8..<0.9: return "Good"
    case 0.7..<0.8: return "Fair"
    default: return "Needs Improvement"
    }
  }
}
