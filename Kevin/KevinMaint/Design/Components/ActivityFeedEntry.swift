import SwiftUI

struct ActivityFeedEntry: View {
    let entry: ActivityEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: LightTheme.Spacing.sm) {
            // Avatar or icon
            ZStack {
                if entry.isSystemEntry {
                    // System entries (AI, etc.) get special icons
                    RoundedRectangle(cornerRadius: LightTheme.CornerRadius.sm)
                        .fill(LightTheme.accentLight)
                        .frame(width: 32, height: 32)
                    
                    if entry.type == .aiAnalysis {
                        Image(systemName: "brain")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LightTheme.accent)
                    } else {
                        Image(systemName: entry.type.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LightTheme.accent)
                    }
                } else {
                    // User entries get initials
                    Circle()
                        .fill(LightTheme.accent)
                        .frame(width: 32, height: 32)
                    
                    Text(entry.authorInitials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // Content bubble
            VStack(alignment: .leading, spacing: LightTheme.Spacing.xs) {
                // Entry type tag (for non-message entries)
                if entry.type != .message && entry.type != .update {
                    HStack {
                        Text(entry.type.tag)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(LightTheme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LightTheme.surfaceBackground)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(entry.displayTime)
                            .font(LightTheme.Typography.caption)
                            .foregroundColor(LightTheme.tertiaryText)
                    }
                }
                
                // Content text
                Text(entry.content)
                    .font(LightTheme.Typography.body)
                    .foregroundColor(LightTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Author and time (for messages and updates)
                if entry.type == .message || entry.type == .update {
                    HStack {
                        Text(entry.authorName)
                            .font(LightTheme.Typography.footnote)
                            .foregroundColor(LightTheme.secondaryText)
                        
                        Spacer()
                        
                        Text(entry.displayTime)
                            .font(LightTheme.Typography.caption)
                            .foregroundColor(LightTheme.tertiaryText)
                    }
                }
                
                // Status change metadata
                if entry.type == .statusChanged, let metadata = entry.metadata {
                    HStack {
                        if let oldStatus = metadata["oldStatus"], let newStatus = metadata["newStatus"] {
                            Text("\(oldStatus) → \(newStatus)")
                                .font(LightTheme.Typography.caption)
                                .foregroundColor(LightTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LightTheme.accentLight)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }
            }
            .padding(LightTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LightTheme.CornerRadius.md)
                    .fill(entry.isSystemEntry ? LightTheme.surfaceBackground : LightTheme.cardBackground)
                    .shadow(color: LightTheme.shadow, radius: 1, x: 0, y: 1)
            )
            
            Spacer()
        }
        .padding(.horizontal, LightTheme.Spacing.md)
        .padding(.vertical, LightTheme.Spacing.xs)
    }
}

#Preview {
    VStack(spacing: 12) {
        ActivityFeedEntry(entry: ActivityEntry(
            type: .issueCreated,
            content: "Issue created by Alex at 9:15 AM",
            authorId: "user1",
            authorName: "Alex Chen",
            authorInitials: "AC"
        ))
        
        ActivityFeedEntry(entry: ActivityEntry(
            type: .aiAnalysis,
            content: "AI suggests replacement hinge, estimated 30 min",
            authorId: "ai",
            authorName: "AI Assistant",
            authorInitials: "AI"
        ))
        
        ActivityFeedEntry(entry: ActivityEntry(
            type: .update,
            content: "In progress — picking up part",
            authorId: "tech1",
            authorName: "Jamie Rodriguez",
            authorInitials: "JR"
        ))
        
        ActivityFeedEntry(entry: ActivityEntry(
            type: .message,
            content: "Please fix before Friday rush",
            authorId: "user2",
            authorName: "Sam Wilson",
            authorInitials: "SW"
        ))
        
        ActivityFeedEntry(entry: ActivityEntry(
            type: .statusChanged,
            content: "Status changed to In Progress",
            authorId: "tech1",
            authorName: "Jamie Rodriguez",
            authorInitials: "JR",
            metadata: ["oldStatus": "Open", "newStatus": "In Progress"]
        ))
    }
    .background(LightTheme.background)
}
