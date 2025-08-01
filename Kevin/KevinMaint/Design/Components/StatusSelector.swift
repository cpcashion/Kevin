import SwiftUI

struct StatusSelector: View {
  @Binding var selectedStatus: IssueStatus
  @State private var isExpanded = false
  let onStatusChange: (IssueStatus) -> Void
  
  private let allStatuses: [IssueStatus] = [
    .reported, .in_progress, .completed
  ]
  
  var body: some View {
    VStack(spacing: 0) {
      // Current status button
      Button(action: { 
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      }) {
        HStack(spacing: 12) {
          Image(systemName: selectedStatus.icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(colorForStatus(selectedStatus))
            .frame(width: 20)
          
          Text(selectedStatus.displayName)
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
          
          Image(systemName: "chevron.down")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(KMTheme.tertiaryText)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(KMTheme.border, lineWidth: 0.5)
        )
      }
      .buttonStyle(PlainButtonStyle())
      
      // Expanded status options
      if isExpanded {
        VStack(spacing: 1) {
          ForEach(allStatuses, id: \.self) { status in
            StatusOption(
              status: status,
              isSelected: status == selectedStatus,
              color: colorForStatus(status)
            ) {
              withAnimation(.easeInOut(duration: 0.2)) {
                selectedStatus = status
                isExpanded = false
                onStatusChange(status)
              }
            }
          }
        }
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(KMTheme.border, lineWidth: 0.5)
        )
        .padding(.top, 8)
        .transition(.asymmetric(
          insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
          removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
        ))
      }
    }
  }
  
  private func colorForStatus(_ status: IssueStatus) -> Color {
    switch status {
    case .reported:
      return KMTheme.secondaryText
    case .in_progress:
      return KMTheme.accent
    case .completed:
      return KMTheme.success
    }
  }
}

struct StatusOption: View {
  let status: IssueStatus
  let isSelected: Bool
  let color: Color
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Image(systemName: status.icon)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(color)
          .frame(width: 20)
        
        Text(status.displayName)
          .font(.body)
          .fontWeight(isSelected ? .semibold : .regular)
          .foregroundColor(isSelected ? KMTheme.primaryText : KMTheme.secondaryText)
        
        Spacer()
        
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(color)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(isSelected ? color.opacity(0.08) : Color.clear)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

#Preview {
  @Previewable @State var status: IssueStatus = .in_progress
  
  return VStack(spacing: 20) {
    StatusSelector(selectedStatus: $status) { newStatus in
      print("Status changed to: \(newStatus)")
    }
    
    Spacer()
  }
  .padding(20)
  .background(KMTheme.background)
}
