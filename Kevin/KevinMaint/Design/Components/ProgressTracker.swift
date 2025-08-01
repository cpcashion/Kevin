import SwiftUI

struct ProgressTracker: View {
    let steps: [ProgressStep]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 0) {
                    // Step circle
                    VStack(spacing: LightTheme.Spacing.xs) {
                        ZStack {
                            Circle()
                                .fill(step.isCompleted ? LightTheme.accent : LightTheme.border)
                                .frame(width: 32, height: 32)
                            
                            if step.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            } else {
                                Text(step.emoji)
                                    .font(.system(size: 12))
                            }
                        }
                        
                        // Step title
                        Text(step.title)
                            .font(LightTheme.Typography.caption)
                            .foregroundColor(step.isCompleted ? LightTheme.primaryText : LightTheme.tertiaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        // Completed by info
                        if step.isCompleted, let completedBy = step.completedBy {
                            Text(completedBy)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(LightTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Connector line (except for last item)
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(step.isCompleted && steps[index + 1].isCompleted ? LightTheme.accent : LightTheme.border)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, LightTheme.Spacing.md)
        .padding(.vertical, LightTheme.Spacing.sm)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressTracker(steps: [
            ProgressStep(title: "Reported", emoji: "📸", isCompleted: true, completedBy: "Alex"),
            ProgressStep(title: "Analyzed", emoji: "🔍", isCompleted: true, completedBy: "AI"),
            ProgressStep(title: "Assigned", emoji: "🛠", isCompleted: true, completedBy: "Jamie"),
            ProgressStep(title: "In Progress", emoji: "🚧", isCompleted: false, completedBy: nil),
            ProgressStep(title: "Completed", emoji: "✅", isCompleted: false, completedBy: nil)
        ])
        .background(LightTheme.cardBackground)
        .cornerRadius(LightTheme.CornerRadius.md)
        
        ProgressTracker(steps: [
            ProgressStep(title: "Reported", emoji: "📸", isCompleted: true, completedBy: "Sam"),
            ProgressStep(title: "Analyzed", emoji: "🔍", isCompleted: true, completedBy: "AI"),
            ProgressStep(title: "Assigned", emoji: "🛠", isCompleted: true, completedBy: "Maria"),
            ProgressStep(title: "In Progress", emoji: "🚧", isCompleted: true, completedBy: "Maria"),
            ProgressStep(title: "Completed", emoji: "✅", isCompleted: true, completedBy: "Maria")
        ])
        .background(LightTheme.cardBackground)
        .cornerRadius(LightTheme.CornerRadius.md)
    }
    .padding()
    .background(LightTheme.background)
}
