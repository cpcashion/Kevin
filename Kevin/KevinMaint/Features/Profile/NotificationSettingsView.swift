import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var pushNotificationsEnabled = false
    @State private var issueUpdatesEnabled = true
    @State private var workOrdersEnabled = true
    @State private var messagesEnabled = true
    @State private var weeklyReportsEnabled = false
    @State private var showingPermissionAlert = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // System Notifications Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Notifications")
                        .font(.headline)
                        .foregroundColor(KMTheme.primaryText)
                    
                    VStack(spacing: 0) {
                        NotificationToggleRow(
                            icon: "bell.badge",
                            title: "Push Notifications",
                            subtitle: notificationStatus == .authorized ? "Enabled in Settings" : "Disabled in Settings",
                            isEnabled: $pushNotificationsEnabled,
                            isSystemSetting: true
                        ) {
                            if notificationStatus != .authorized {
                                showingPermissionAlert = true
                            }
                        }
                        
                        if notificationStatus != .authorized {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enable push notifications in Settings to receive real-time updates about your maintenance requests.")
                                    .font(.caption)
                                    .foregroundColor(KMTheme.secondaryText)
                                
                                Button(action: openSettings) {
                                    Text("Open Settings")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(KMTheme.accent)
                                }
                            }
                            .padding(16)
                            .background(KMTheme.background)
                        }
                    }
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                }
                
                // Notification Preferences Section
                if notificationStatus == .authorized {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notification Preferences")
                            .font(.headline)
                            .foregroundColor(KMTheme.primaryText)
                        
                        VStack(spacing: 0) {
                            NotificationToggleRow(
                                icon: "exclamationmark.triangle",
                                title: "Issue Updates",
                                subtitle: "Status changes and new comments",
                                isEnabled: $issueUpdatesEnabled
                            )
                            
                            Divider().background(KMTheme.border)
                            
                            NotificationToggleRow(
                                icon: "wrench.and.screwdriver",
                                title: "Work Orders",
                                subtitle: "New work orders and completions",
                                isEnabled: $workOrdersEnabled
                            )
                            
                            Divider().background(KMTheme.border)
                            
                            NotificationToggleRow(
                                icon: "message",
                                title: "Messages",
                                subtitle: "New messages from Kevin's team",
                                isEnabled: $messagesEnabled
                            )
                            
                            Divider().background(KMTheme.border)
                            
                            NotificationToggleRow(
                                icon: "chart.bar",
                                title: "Weekly Reports",
                                subtitle: "Summary of maintenance activity",
                                isEnabled: $weeklyReportsEnabled
                            )
                        }
                        .background(KMTheme.cardBackground)
                        .cornerRadius(12)
                    }
                }
                
                // Information Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(KMTheme.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About Notifications")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(KMTheme.primaryText)
                            
                            Text("You'll receive notifications for important updates about your maintenance requests. You can customize which types of notifications you receive.")
                                .font(.caption)
                                .foregroundColor(KMTheme.secondaryText)
                        }
                    }
                }
                .padding(16)
                .background(KMTheme.cardBackground)
                .cornerRadius(12)
            }
            .padding(20)
        }
        .background(KMTheme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .kevinNavigationBarStyle()
        .onAppear(perform: checkNotificationStatus)
        .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To receive push notifications, please enable them in your device Settings.")
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
                self.pushNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    var isSystemSetting: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(KMTheme.accent)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
            }
            
            Spacer()
            
            if !isSystemSetting {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            if let action = onTap {
                action()
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
