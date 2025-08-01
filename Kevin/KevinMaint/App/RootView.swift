import SwiftUI
import UIKit

struct RootView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.colorScheme) var colorScheme
  @State private var showingOnboarding = true
  @State private var hasCompletedFullFlow = false
  @State private var selectedTab = 1  // Shared tab state
  @State private var showingConversation: Conversation?
  @State private var selectedIssueId: String?
  
  var body: some View {
    Group {
      if showingOnboarding && !hasCompletedFullFlow {
        // Always show complete Kevin onboarding experience first
        FullOnboardingFlow(
          showingOnboarding: $showingOnboarding,
          hasCompletedFullFlow: $hasCompletedFullFlow
        )
        .environmentObject(appState)
        .onAppear { print("🎬 [RootView] Showing full onboarding flow") }
      } else {
        MainTabView(selectedTab: $selectedTab, selectedIssueId: $selectedIssueId)
          .onAppear { 
            LaunchTimeProfiler.shared.checkpoint("MainTabView appeared")
            LaunchTimeProfiler.shared.finishProfiling()
            PerformanceMonitoringService.shared.completeAppLaunch(success: true)
            print("📱 [RootView] Showing main app") 
          }
      }
    }
    .preferredColorScheme(KMTheme.currentTheme == .dark ? .dark : .light)
    .statusBarHidden(false)
    .background(StatusBarStyleModifier(theme: appState.currentTheme))
    .onAppear {
      LaunchTimeProfiler.shared.checkpoint("RootView appeared")
      configureAppAppearance()
      LaunchTimeProfiler.shared.checkpoint("App appearance configured")
      
      // Setup notifications
      NotificationService.shared.setupNotifications()
      LaunchTimeProfiler.shared.checkpoint("Notifications configured")
    }
    .onChange(of: appState.currentTheme) { _, newTheme in
      configureAppAppearance()
      // Force UI refresh for search bars
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshSearchBars"), object: nil)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
      print("📢 [RootView] Received userDidSignOut notification")
      showingOnboarding = true
      hasCompletedFullFlow = false
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
      // App became active - refresh theme detection
      KMTheme.setSystemTheme()
      let detectedTheme = KMTheme.currentTheme
      
      // If no manual theme is set, update to match system
      if UserDefaults.standard.string(forKey: "selectedTheme") == nil {
        appState.currentTheme = detectedTheme
        print("🎨 [RootView] Updated to system theme: \(detectedTheme)")
      }
    }
    .onChange(of: colorScheme) { _, newColorScheme in
      // System appearance changed - update theme if following system
      if UserDefaults.standard.string(forKey: "selectedTheme") == nil {
        let newTheme: ThemeMode = newColorScheme == .dark ? .dark : .light
        appState.currentTheme = newTheme
        print("🎨 [RootView] System appearance changed to: \(newTheme)")
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .openConversation)) { notification in
      handleOpenConversation(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .navigateToIssue)) { notification in
      handleNavigateToIssue(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openIssueDetail)) { notification in
      handleOpenIssueDetail(notification)
    }
    .sheet(item: $showingConversation) { conversation in
      ChatView(conversation: conversation)
        .environmentObject(appState)
    }
  }
  
  private func configureAppAppearance() {
    DispatchQueue.main.async {
      // Configure search bar appearance
      configureGlobalSearchBarAppearance()
    }
  }
  
  private func configureGlobalSearchBarAppearance() {
    let appearance = UISearchBar.appearance()
    
    // Clear any existing styling
    appearance.backgroundColor = UIColor.clear
    appearance.barTintColor = UIColor.clear
    appearance.isTranslucent = true
    
    // Configure for current theme
    appearance.searchTextField.backgroundColor = UIColor(KMTheme.cardBackground)
    appearance.searchTextField.textColor = UIColor(KMTheme.primaryText)
    appearance.searchTextField.tintColor = UIColor(KMTheme.accent)
    
    // Configure placeholder text
    appearance.searchTextField.attributedPlaceholder = NSAttributedString(
      string: "Search...",
      attributes: [NSAttributedString.Key.foregroundColor: UIColor(KMTheme.secondaryText)]
    )
    
    // Configure search bar style based on theme
    if KMTheme.currentTheme == .light {
      appearance.searchBarStyle = .minimal
      appearance.barStyle = .default
      appearance.keyboardAppearance = .light
    } else {
      appearance.searchBarStyle = .minimal  
      appearance.barStyle = .black
      appearance.keyboardAppearance = .dark
    }
  }
  
  private func handleOpenConversation(_ notification: Notification) {
    print("🚨🚨🚨 [RootView] ===== HANDLING OPEN CONVERSATION =====")
    
    guard let conversationId = notification.userInfo?["conversationId"] as? String else {
      print("❌ [RootView] No conversation ID in notification")
      return
    }
    
    print("🔔 [RootView] Opening conversation from notification: \(conversationId)")
    print("🔔 [RootView] Current tab: \(selectedTab)")
    
    // CRITICAL: Force complete onboarding flow first
    if showingOnboarding {
      print("⚠️ [RootView] Still in onboarding, completing flow first")
      hasCompletedFullFlow = true
      showingOnboarding = false
    }
    
    // Switch to messages tab (index 2)
    selectedTab = 2
    print("✅ [RootView] Switched to tab: \(selectedTab)")
    
    // Small delay to ensure tab switch completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      // Fetch and show the conversation
      Task {
        do {
          let conversation = try await MessagingService.shared.getConversation(conversationId: conversationId)
          await MainActor.run {
            print("✅ [RootView] Opening conversation sheet")
            self.showingConversation = conversation
          }
        } catch {
          print("❌ [RootView] Failed to fetch conversation: \(error)")
        }
      }
    }
    
    print("🚨🚨🚨 [RootView] ===== OPEN CONVERSATION HANDLING COMPLETE =====")
  }

  private func handleNavigateToIssue(_ notification: Notification) {
    print("🚨🚨🚨 [RootView] ===== HANDLING NAVIGATE TO ISSUE =====")
    guard let issueId = notification.userInfo?["issueId"] as? String else {
      print("❌ [RootView] No issue ID in navigate notification")
      return
    }
    if showingOnboarding {
      hasCompletedFullFlow = true
      showingOnboarding = false
    }
    selectedTab = 1
    selectedIssueId = issueId
    print("✅ [RootView] Navigated to issue: \(issueId) on tab \(selectedTab)")
  }

  private func handleOpenIssueDetail(_ notification: Notification) {
    print("🚨🚨🚨 [RootView] ===== HANDLING OPEN ISSUE DETAIL =====")
    guard let issueId = notification.userInfo?["issueId"] as? String else {
      print("❌ [RootView] No issue ID in openIssueDetail notification")
      return
    }
    if showingOnboarding {
      hasCompletedFullFlow = true
      showingOnboarding = false
    }
    selectedTab = 1
    selectedIssueId = issueId
    print("✅ [RootView] Opened issue detail for: \(issueId)")
  }
}

struct FullOnboardingFlow: View {
  @EnvironmentObject var appState: AppState
  @Binding var showingOnboarding: Bool
  @Binding var hasCompletedFullFlow: Bool
  @State private var currentStep: OnboardingStep = .welcome
  
  enum OnboardingStep {
    case welcome, complete
  }
  
  var body: some View {
    Group {
      switch currentStep {
      case .welcome:
        OnboardingView(isPresented: .constant(true))
          .environmentObject(appState)
          .onAppear { print("🎯 [FullOnboardingFlow] Showing welcome onboarding") }
          .onChange(of: appState.isAuthed) { _, isAuthed in
            if isAuthed {
              // Complete onboarding after authentication
              currentStep = .complete
            }
          }
          .onChange(of: appState.currentAppUser) { _, appUser in
            if appState.isAuthed && appUser != nil {
              // Complete onboarding after user creation
              currentStep = .complete
            }
          }
      case .complete:
        Color.clear
          .onAppear {
            print("🎯 [FullOnboardingFlow] Onboarding complete, transitioning to main app")
            hasCompletedFullFlow = true
            showingOnboarding = false
          }
      }
    }
    .onAppear {
      print("🎬 [FullOnboardingFlow] Flow appeared with step: \(currentStep)")
    }
    .onChange(of: currentStep) { _, newStep in
      print("🔄 [FullOnboardingFlow] Step changed to: \(newStep)")
    }
  }
  
  // Removed checkUserRoleAndProceed function
}



struct MainTabView: View {
  @EnvironmentObject var appState: AppState
  @Binding var selectedTab: Int
  @Binding var selectedIssueId: String?
  @State private var issuesFilter: IssueStatusFilter = .all
  @State private var showingActivityFeed = false
  
  private var isAdmin: Bool {
    guard let user = appState.currentAppUser,
          let email = user.email else { 
      print("🔍 [DEBUG RootView] isAdmin check failed - currentAppUser: \(String(describing: appState.currentAppUser))")
      return false 
    }
    let result = AdminConfig.isAdmin(email: email)
    print("🔍 [DEBUG RootView] isAdmin check - email: '\(email)', result: \(result)")
    print("🔍 [DEBUG RootView] currentAppUser role: \(user.role.rawValue)")
    return result
  }
  
  // Feature flag to hide Messages tab after migration to Issue Detail timeline
  private let hideMessagesTab = true
  
  private var tabs: [TabItem] {
    var tabItems = [
      TabItem(title: "AI Snap", systemImage: "sparkles"),
      TabItem(title: "Issues", systemImage: "list.bullet")
    ]
    
    // Legacy Messages tab (deprecated - functionality moved to Issue Detail timeline)
    if !hideMessagesTab {
      tabItems.append(TabItem(title: "Messages", systemImage: "message"))
    }
    
    tabItems.append(contentsOf: [
      TabItem(title: "Locations", systemImage: "building.2"),
      TabItem(title: "Profile", systemImage: "person.circle")
    ])
    
    return tabItems
  }
  
  var body: some View {
    VStack(spacing: 0) {
      LiquidGlassTabContainer(selectedTab: $selectedTab, tabs: tabs) {
        Group {
          switch selectedTab {
        case 0:
          ReportIssueView(selectedTab: $selectedTab, issuesFilter: $issuesFilter)
            .onAppear { print("📱 [MainTabView] AI Snap tab appeared") }
        case 1:
          IssuesListView(filterBinding: $issuesFilter, selectedTab: $selectedTab, selectedIssueId: $selectedIssueId)
            .onAppear { 
              print("📱 [MainTabView] Issues tab appeared")
            }
        case 2:
          if hideMessagesTab {
            // Messages tab hidden - show Locations
            SimpleLocationsView()
              .onAppear { 
                print("📱 [MainTabView] Locations tab appeared")
              }
          } else {
            // Legacy Messages tab (deprecated)
            MessagesView()
              .onAppear { print("📱 [MainTabView] Messages tab appeared (DEPRECATED)") }
          }
        case 3:
          if hideMessagesTab {
            // Messages tab hidden - show Profile
            ProfileView()
              .onAppear { print("📱 [MainTabView] Profile tab appeared") }
          } else {
            // Legacy tab layout
            SimpleLocationsView()
              .onAppear { 
                print("📱 [MainTabView] Locations tab appeared")
              }
          }
        case 4:
          // Only exists when Messages tab is visible
          if !hideMessagesTab {
            ProfileView()
              .onAppear { print("📱 [MainTabView] Profile tab appeared") }
          } else {
            // Fallback
            ReportIssueView(selectedTab: $selectedTab, issuesFilter: $issuesFilter)
          }
        default:
          ReportIssueView(selectedTab: $selectedTab, issuesFilter: $issuesFilter)
        }
      }
      }
    }
    .sheet(isPresented: $showingActivityFeed) {
      ActivityFeedView()
        .environmentObject(appState)
    }
    // Demo mode removed - app now works for everyone
    .onAppear {
      // Check if user has unread notifications on app launch
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        checkForUnreadNotifications()
      }
    }
  }
  
  private func handleOpenIssueDetail(_ notification: Notification) {
    print("🚨🚨🚨 [MainTabView] ===== HANDLING OPEN ISSUE DETAIL =====")
    
    guard let issueId = notification.userInfo?["issueId"] as? String else {
      print("❌ [MainTabView] No issue ID in notification")
      return
    }
    
    print("🔔 [MainTabView] Opening issue detail from notification: \(issueId)")
    print("🔔 [MainTabView] Current tab: \(selectedTab)")
    
    // Switch to issues tab, set filter to show open issues, and set the selected issue
    selectedTab = 1
    issuesFilter = .reported  // Ensure we're showing reported issues where new issues appear
    selectedIssueId = issueId
    
    print("✅ [MainTabView] Switched to tab: \(selectedTab), set issueId: \(issueId)")
    print("🚨🚨🚨 [MainTabView] ===== OPEN ISSUE DETAIL HANDLING COMPLETE =====")
  }
  
  private func handleNavigateToIssue(_ notification: Notification) {
    print("🚨🚨🚨 [MainTabView] ===== HANDLING NAVIGATE TO ISSUE =====")
    
    guard let issueId = notification.userInfo?["issueId"] as? String else {
      print("❌ [MainTabView] No issue ID in navigate notification")
      return
    }
    
    print("🔔 [MainTabView] Navigating to issue from push notification: \(issueId)")
    print("🔔 [MainTabView] Current tab: \(selectedTab)")
    
    // Switch to issues tab and navigate to the specific issue
    selectedTab = 1
    issuesFilter = .all  // Show all issues to ensure we can find the issue
    selectedIssueId = issueId
    
    print("✅ [MainTabView] Switched to tab: \(selectedTab), set issueId: \(issueId)")
    
    // Optional: Check if there's a specific tab to show (e.g., receipts)
    if let tab = notification.userInfo?["tab"] as? String {
      print("🔔 [MainTabView] Specific tab requested: \(tab)")
      // This could be used to show a specific tab in IssueDetailView
    }
    
    print("🚨🚨🚨 [MainTabView] ===== NAVIGATE TO ISSUE HANDLING COMPLETE =====")
  }
  
  private func checkForUnreadNotifications() {
    let badgeCount = UIApplication.shared.applicationIconBadgeNumber
    let unreadCount = NotificationHistoryService.shared.unreadCount
    
    print("🔔 [MainTabView] Checking notifications - Badge: \(badgeCount), Unread: \(unreadCount)")
    
    // Show activity feed if there are unread notifications
    if badgeCount > 0 || unreadCount > 0 {
      print("✅ [MainTabView] Opening activity feed with \(max(badgeCount, unreadCount)) notifications")
      showingActivityFeed = true
    }
  }
}

struct StatusBarStyleModifier: UIViewControllerRepresentable {
  let theme: ThemeMode
  
  func makeUIViewController(context: Context) -> StatusBarViewController {
    return StatusBarViewController(theme: theme)
  }
  
  func updateUIViewController(_ uiViewController: StatusBarViewController, context: Context) {
    uiViewController.updateTheme(theme)
  }
}

class StatusBarViewController: UIViewController {
  private var currentTheme: ThemeMode
  
  init(theme: ThemeMode) {
    self.currentTheme = theme
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return currentTheme == .dark ? .lightContent : .darkContent
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.clear
  }
  
  func updateTheme(_ theme: ThemeMode) {
    currentTheme = theme
    setNeedsStatusBarAppearanceUpdate()
  }
}

