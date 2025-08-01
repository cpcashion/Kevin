import SwiftUI

struct DataVisualizationButtons: View {
  let onIssueTimelinePressed: () -> Void
  let onAIAccuracyPressed: () -> Void
  let onRestaurantHealthPressed: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Analytics & Insights")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        HStack(spacing: 4) {
          Image(systemName: "brain.head.profile")
            .foregroundColor(KMTheme.aiGreen)
            .font(.caption)
          
          Text("AI Powered")
            .font(.caption2)
            .foregroundColor(KMTheme.aiGreen)
        }
      }
      
      HStack(spacing: 12) {
        // Issue Timeline Button
        DataVizButton(
          icon: "clock.arrow.circlepath",
          title: "Issue Timeline",
          subtitle: "Resolution Speed",
          color: KMTheme.accent,
          gradientColors: [KMTheme.accent.opacity(0.8), KMTheme.accent.opacity(0.4)],
          action: onIssueTimelinePressed
        )
        
        // AI Accuracy Button
        DataVizButton(
          icon: "brain.head.profile",
          title: "AI Accuracy",
          subtitle: "Analysis Quality",
          color: KMTheme.aiGreen,
          gradientColors: [KMTheme.aiGreen.opacity(0.8), KMTheme.aiGreen.opacity(0.4)],
          action: onAIAccuracyPressed
        )
        
        // Restaurant Health Button
        DataVizButton(
          icon: "heart.text.square",
          title: "Health Trends",
          subtitle: "Restaurant Status",
          color: KMTheme.progress,
          gradientColors: [KMTheme.progress.opacity(0.8), KMTheme.progress.opacity(0.4)],
          action: onRestaurantHealthPressed
        )
      }
    }
  }
}

struct DataVizButton: View {
  let icon: String
  let title: String
  let subtitle: String
  let color: Color
  let gradientColors: [Color]
  let action: () -> Void
  
  @State private var isPressed = false
  
  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        // Icon with gradient background
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 44, height: 44)
          
          Image(systemName: icon)
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(.white)
        }
        
        VStack(spacing: 2) {
          Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
            .multilineTextAlignment(.center)
          
          Text(subtitle)
            .font(.caption2)
            .foregroundColor(KMTheme.secondaryText)
            .multilineTextAlignment(.center)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(KMTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.1)]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
      )
      .scaleEffect(isPressed ? 0.95 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    .buttonStyle(PlainButtonStyle())
    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
      isPressed = pressing
    }, perform: {})
  }
}

#Preview {
  DataVisualizationButtons(
    onIssueTimelinePressed: {},
    onAIAccuracyPressed: {},
    onRestaurantHealthPressed: {}
  )
  .padding()
  .background(KMTheme.background)
}
