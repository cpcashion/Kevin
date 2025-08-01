import SwiftUI

struct WorkOrderStatusBanner: View {
  let issue: Issue
  let workOrders: [WorkOrder]
  let onComplete: () -> Void
  let onAddUpdate: () -> Void
  
  private var primaryWorkOrder: WorkOrder? {
    workOrders.first
  }
  
  private var isCompleted: Bool {
    issue.status == .completed || primaryWorkOrder?.status == .completed
  }
  
  private var isInProgress: Bool {
    issue.status == .in_progress || primaryWorkOrder?.status == .in_progress
  }
  
  var body: some View {
    VStack(spacing: 0) {
      if isCompleted {
        completedBanner
      } else if isInProgress {
        inProgressBanner
      } else {
        pendingBanner
      }
    }
    .cornerRadius(12)
    .shadow(color: KMTheme.background.opacity(0.1), radius: 2, x: 0, y: 1)
  }
  
  private var completedBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.title2)
        .foregroundColor(KMTheme.success)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Work Completed")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        if let completedAt = primaryWorkOrder?.completedAt {
          Text("Finished \(completedAt, style: .date)")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      
      Spacer()
      
      Button("Archive") {
        // Archive functionality
      }
      .font(.caption)
      .fontWeight(.medium)
      .foregroundColor(KMTheme.tertiaryText)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(KMTheme.borderSecondary)
      .cornerRadius(6)
    }
    .padding(16)
    .background(KMTheme.success.opacity(0.1))
    .overlay(
      Rectangle()
        .frame(height: 3)
        .foregroundColor(KMTheme.success),
      alignment: .top
    )
  }
  
  private var inProgressBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "gear.circle.fill")
        .font(.title2)
        .foregroundColor(KMTheme.accent)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Work in Progress")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Text("Ready to mark as complete?")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      Spacer()
      
      HStack(spacing: 8) {
        Button("Update") {
          onAddUpdate()
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KMTheme.accent.opacity(0.1))
        .cornerRadius(6)
        
        Button("Complete") {
          onComplete()
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KMTheme.success)
        .cornerRadius(6)
      }
    }
    .padding(16)
    .background(KMTheme.accent.opacity(0.05))
    .overlay(
      Rectangle()
        .frame(height: 3)
        .foregroundColor(KMTheme.accent),
      alignment: .top
    )
  }
  
  private var scheduledBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "calendar.circle.fill")
        .font(.title2)
        .foregroundColor(KMTheme.warning)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Work Scheduled")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Text("Tap to start working")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      Spacer()
      
      Button("Start Work") {
        onAddUpdate()
      }
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundColor(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(KMTheme.warning)
      .cornerRadius(6)
    }
    .padding(16)
    .background(KMTheme.warning.opacity(0.1))
    .overlay(
      Rectangle()
        .frame(height: 3)
        .foregroundColor(KMTheme.warning),
      alignment: .top
    )
  }
  
  private var pendingBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "gear.circle.fill")
        .font(.title2)
        .foregroundColor(KMTheme.accent)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Ready to Start Work")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Text("Mark as complete when finished")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      Spacer()
      
      Button("Complete") {
        onComplete()
      }
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundColor(.black.opacity(0.8))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(KMTheme.success)
      .cornerRadius(6)
    }
    .padding(16)
    .background(KMTheme.accent.opacity(0.05))
    .overlay(
      Rectangle()
        .frame(height: 3)
        .foregroundColor(KMTheme.accent),
      alignment: .top
    )
  }
}
