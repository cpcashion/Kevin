import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSignOutAlert = false
    @State private var showingBugReport = false
    @State private var showingContactSupport = false
    @State private var showingSupportInbox = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    
                    // Header with user info
                    VStack(spacing: 16) {
                        // Profile Image
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                        
                        // User Info
                        if let user = appState.currentAppUser {
                            VStack(spacing: 4) {
                                Text(user.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(KMTheme.primaryText)
                                
                                if let email = user.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(KMTheme.secondaryText)
                                }
                                
                                // Admin badge
                                if user.role == .admin {
                                    Text("ADMIN")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(KMTheme.accent)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                
                // Settings sections
                VStack(spacing: 0) {
                    // Account section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Account")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        
                        VStack(spacing: 1) {
                            NavigationLink(destination: AccountSettingsView()) {
                                ProfileMenuItemContent(
                                    icon: "person.circle",
                                    title: "Account Settings",
                                    subtitle: "Manage your profile and preferences"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: NotificationSettingsView()) {
                                ProfileMenuItemContent(
                                    icon: "bell",
                                    title: "Notifications",
                                    subtitle: "Configure maintenance alerts"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 32)
                    
                    
                    
                    // Admin section (only for admins)
                    if appState.currentAppUser?.role == .admin {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Admin")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(KMTheme.primaryText)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 1) {
                                ProfileMenuItem(
                                    icon: "tray.full",
                                    title: "Support Inbox",
                                    subtitle: "View and respond to user messages"
                                ) {
                                    showingSupportInbox = true
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    
                    // Support section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Support")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        
                        VStack(spacing: 1) {
                            NavigationLink(destination: HelpView()) {
                                ProfileMenuItemContent(
                                    icon: "questionmark.circle",
                                    title: "Help & FAQ",
                                    subtitle: "Get answers to common questions"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            ProfileMenuItem(
                                icon: "envelope",
                                title: "Contact Kevin's Team",
                                subtitle: "Get direct support from our team"
                            ) {
                                showingContactSupport = true
                            }
                            
                            ProfileMenuItem(
                                icon: "exclamationmark.triangle",
                                title: "Report Bug",
                                subtitle: "Help us fix issues you encounter"
                            ) {
                                showingBugReport = true
                            }
                        }
                    }
                    .padding(.bottom, 32)
                    
                    
                    // Sign out section
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 1) {
                            ProfileMenuItem(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                subtitle: "Sign out of your Kevin account",
                                isDestructive: true
                            ) {
                                showingSignOutAlert = true
                            }
                        }
                    }
                }
                    
                    // App version
                    Text("Kevin Beta v1.0")
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                        .padding(.top, 40)
                        .padding(.bottom, 100) // Extra padding to avoid tab bar overlap
                }
            }
            .background(KMTheme.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .kevinNavigationBarStyle()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                appState.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out of your Kevin Maint account?")
        }
        .sheet(isPresented: $showingBugReport) {
            BugReportView()
        }
        .sheet(isPresented: $showingContactSupport) {
            ContactSupportView()
        }
        .sheet(isPresented: $showingSupportInbox) {
            AdminSupportInboxView()
        }
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? KMTheme.danger : KMTheme.accent)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? KMTheme.danger : KMTheme.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
                
                // Chevron
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KMTheme.tertiaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(KMTheme.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Non-button version for use with NavigationLink
struct ProfileMenuItemContent: View {
    let icon: String
    let title: String
    let subtitle: String
    let isDestructive: Bool
    
    init(icon: String, title: String, subtitle: String, isDestructive: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isDestructive ? KMTheme.danger : KMTheme.accent)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isDestructive ? KMTheme.danger : KMTheme.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
            }
            
            Spacer()
            
            // Chevron
            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KMTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(KMTheme.cardBackground)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
