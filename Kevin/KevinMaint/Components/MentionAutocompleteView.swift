import SwiftUI

/// Autocomplete view for @ mentions
struct MentionAutocompleteView: View {
    let users: [AppUser]
    let onSelectUser: (AppUser) -> Void
    
    var body: some View {
        if !users.isEmpty {
            VStack(spacing: 0) {
                ForEach(users, id: \.id) { user in
                    Button(action: {
                        onSelectUser(user)
                    }) {
                        HStack(spacing: 12) {
                            // Avatar circle with initials
                            ZStack {
                                Circle()
                                    .fill(KMTheme.accent.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                
                                Text(user.name.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(KMTheme.accent)
                            }
                            
                            // User info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(KMTheme.primaryText)
                                
                                if let email = user.email {
                                    Text(email.components(separatedBy: "@").first ?? email)
                                        .font(.system(size: 13))
                                        .foregroundColor(KMTheme.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            // Role badge
                            if user.role == .admin {
                                Text("Admin")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KMTheme.accent)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if user.id != users.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        MentionAutocompleteView(
            users: [
                AppUser(id: "1", role: .admin, name: "Kevin Admin", phone: nil, email: "kevin@example.com"),
                AppUser(id: "2", role: .tech, name: "John Smith", phone: nil, email: "john@example.com"),
                AppUser(id: "3", role: .gm, name: "Sarah Johnson", phone: nil, email: "sarah@example.com")
            ],
            onSelectUser: { user in
                print("Selected: \(user.name)")
            }
        )
        .background(KMTheme.background)
    }
}
