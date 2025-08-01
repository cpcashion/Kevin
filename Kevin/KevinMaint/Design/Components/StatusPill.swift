import SwiftUI

struct StatusPill: View {
  let status: IssueStatus
  
  var color: Color {
    switch status {
    case .reported: return KMTheme.secondaryText
    case .in_progress: return KMTheme.accent
    case .completed: return KMTheme.success
    }
  }
  
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.icon)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(isActiveState ? .white : color)
      
      Text(status.displayName)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(isActiveState ? .white : color)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(isActiveState ? color : color.opacity(0.12))
    .clipShape(Capsule())
  }
  
  private var isActiveState: Bool {
    switch status {
    case .in_progress, .completed:
      return true
    case .reported:
      return false
    }
  }
}
