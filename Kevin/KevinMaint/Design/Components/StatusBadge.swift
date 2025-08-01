import SwiftUI

struct LightStatusBadge: View {
    let status: IssueStatus
    
    private var statusColor: Color {
        switch status {
        case .reported:
            return LightTheme.openStatus
        case .in_progress:
            return LightTheme.inProgressStatus
        case .completed:
            return LightTheme.completedStatus
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .reported:
            return LightTheme.surfaceBackground
        case .in_progress:
            return LightTheme.accentLight
        case .completed:
            return LightTheme.successLight
        }
    }
    
    private var statusEmoji: String {
        switch status {
        case .reported: return "📋"
        case .in_progress: return "🚧"
        case .completed: return "🎉"
        }
    }
    
    private var displayName: String {
        switch status {
        case .reported: return "Reported"
        case .in_progress: return "In Progress"
        case .completed: return "Completed"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(statusEmoji)
                .font(.system(size: 12))
            
            Text(displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(16)
    }
}

struct LightPriorityBadge: View {
    let priority: IssuePriority
    
    private var priorityColor: Color {
        switch priority {
        case .low:
            return LightTheme.lowPriority
        case .medium:
            return LightTheme.mediumPriority
        case .high:
            return LightTheme.highPriority
        }
    }
    
    private var displayName: String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var body: some View {
        Text(displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(priorityColor)
            .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            LightStatusBadge(status: .reported)
            LightStatusBadge(status: .in_progress)
            LightStatusBadge(status: .completed)
        }
        
        HStack {
            LightPriorityBadge(priority: .low)
            LightPriorityBadge(priority: .medium)
            LightPriorityBadge(priority: .high)
        }
    }
    .padding()
    .background(LightTheme.background)
}
