import Foundation
import FirebaseAuth

@MainActor
final class AppState: ObservableObject {
  @Published var isAuthed = false
  @Published var currentUser: User?
  @Published var currentAppUser: AppUser?
  @Published var currentRestaurant: Restaurant?
  @Published var currentTheme: ThemeMode = .dark {
    didSet {
      KMTheme.currentTheme = currentTheme
      UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
      print("🎨 [AppState] Theme changed to: \(currentTheme)")
    }
  }
  
  let firebaseClient = FirebaseClient.shared
  
  // Shared locations service for instant loading
  @Published var locationsService: SimpleLocationsService
  
  // Theme switching methods
  func setLightTheme() {
    print("🎨 [AppState] Setting light theme")
    currentTheme = .light
  }
  
  func setDarkTheme() {
    print("🎨 [AppState] Setting dark theme")
    currentTheme = .dark
  }
  
  func toggleTheme() {
    let newTheme = currentTheme == .light ? ThemeMode.dark : ThemeMode.light
    print("🎨 [AppState] Toggling theme from \(currentTheme) to \(newTheme)")
    currentTheme = newTheme
  }
  
  var requiresRestaurantSetup: Bool {
    // Smart location detection handles restaurant context for all users
    print("🏪 [AppState] requiresRestaurantSetup: false (smart location detection enabled)")
    return false
  }
  
  @MainActor
  init() {
    let instanceId = UUID().uuidString.prefix(8)
    print("🏗️ [AppState] New instance created: \(instanceId)")
    
    self.locationsService = SimpleLocationsService(firebaseClient: firebaseClient, appState: nil)
    
    // Set the appState reference after initialization
    self.locationsService.setAppState(self)
    
    // Start by detecting system appearance
    KMTheme.setSystemTheme()
    let systemTheme = KMTheme.currentTheme
    LaunchTimeProfiler.shared.checkpoint("Theme system detected")
    
    // Load saved theme preference if it exists, otherwise use system theme
    if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
       let themeMode = ThemeMode(rawValue: savedTheme) {
      self.currentTheme = themeMode
      KMTheme.currentTheme = themeMode
      print("🎨 [AppState] Loaded saved theme: \(themeMode)")
    } else {
      // No saved preference - use detected system theme
      self.currentTheme = systemTheme
      print("🎨 [AppState] Using system theme: \(systemTheme)")
    }
    LaunchTimeProfiler.shared.checkpoint("Theme configured")
    
    // Removed LocationService
    
    // Defer auth check to avoid blocking startup
    DispatchQueue.main.async {
      LaunchTimeProfiler.shared.checkpoint("Auth check dispatched")
      self.checkAuthState()
    }
    
    LaunchTimeProfiler.shared.checkpoint("AppState init completed")
    
    // Removed preload task - locations will load when needed after authentication
    // This prevents privacy issues and improves startup performance
  }
  
  private func checkAuthState() {
    // Check current auth state
    if let user = Auth.auth().currentUser {
      self.currentUser = user
      self.isAuthed = true
      print("✅ User already signed in: \(user.uid)")
      print("📧 [DEBUG] Current user email: \(user.email ?? "NO EMAIL")")
      
      // Create AppUser for existing signed-in user
      createAppUser(from: user)
    }
    
    // Listen for auth state changes
    _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      DispatchQueue.main.async {
        self?.currentUser = user
        self?.isAuthed = user != nil
        
        if let user = user {
          print("✅ Auth state changed - User signed in: \(user.uid)")
          if let email = user.email {
            print("📧 Email: \(email)")
          }
          
          // Create AppUser with proper role assignment
          self?.createAppUser(from: user)
        } else {
          print("❌ Auth state changed - User signed out")
          self?.currentAppUser = nil
        }
      }
    }
  }
  
  func signOut() {
    do {
      print("🚪 [AppState] Signing out user...")
      try Auth.auth().signOut()
      print("✅ [AppState] User signed out successfully")
      
      // Clear app state
      self.currentUser = nil
      self.currentAppUser = nil
      self.currentRestaurant = nil
      
      // Clear locations cache to prevent privacy issues
      self.locationsService.clearCache()
      print("🧹 [AppState] Cleared app state and locations cache")
      
      // Reset to show onboarding when user signs out
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        print("📢 [AppState] Posted userDidSignOut notification")
      }
    } catch {
      print("❌ [AppState] Sign out failed: \(error.localizedDescription)")
    }
  }
  
  private func createAppUser(from user: User) {
    // Prevent duplicate user creation for the same user
    if let currentUser = currentAppUser, currentUser.id == user.uid {
      print("🔍 [DEBUG] Skipping duplicate createAppUser for: \(user.uid)")
      return
    }
    
    let email = user.email
    let displayName = user.displayName ?? ""
    
    print("🔍 [DEBUG] createAppUser called")
    print("🔍 [DEBUG] User email: '\(email ?? "NIL")'")
    print("🔍 [DEBUG] User displayName: '\(displayName)'")
    print("🔍 [DEBUG] User uid: '\(user.uid)'")
    
    // Test admin config directly
    print("🔍 [DEBUG] AdminConfig.adminEmails: \(AdminConfig.adminEmails)")
    print("🔍 [DEBUG] AdminConfig.isAdmin(email:) result: \(AdminConfig.isAdmin(email: email))")
    
    // Determine role based on email
    let role: Role = AdminConfig.isAdmin(email: email) ? .admin : .owner
    
    let appUser = AppUser(
      id: user.uid,
      role: role,
      name: displayName,
      phone: user.phoneNumber,
      email: email
    )
    
    self.currentAppUser = appUser
    
    print("✅ [AppState] Created AppUser: \(appUser.name) (\(appUser.role))")
    
    // CRITICAL: Save user to Firestore so other users can look them up
    Task {
      do {
        try await firebaseClient.saveUser(appUser)
        print("✅ [AppState] Saved user to Firestore: \(appUser.id)")
      } catch {
        print("❌ [AppState] Failed to save user to Firestore: \(error)")
      }
    }
    
    // NO restaurant loading for ANY users
    // - Admins: See all issues across all businesses (no restaurant filter)
    // - Regular users: Use location detection (no restaurant ownership)
    print("🔍 [DEBUG] currentAppUser set to: \(String(describing: self.currentAppUser))")
    
    if role == .admin {
      print("🔑 [AppState] Admin privileges granted for: \(email ?? "unknown")")
      print("👁️ [AppState] Admin sees all issues (no restaurant assignment)")
    } else {
      print("👤 [AppState] Regular user role assigned for: \(email ?? "unknown")")
      print("📍 [AppState] Using location detection (no restaurant assignment)")
    }
    
  }
  
  private func loadUserRestaurant(userId: String) {
    Task {
      do {
        let restaurants = try await firebaseClient.getRestaurants(ownerId: userId)
        await MainActor.run {
          if let restaurant = restaurants.first {
            self.currentRestaurant = restaurant
            print("✅ [AppState] Loaded existing restaurant: \(restaurant.name)")
          } else {
            print("🏪 [AppState] No restaurant found for user, will need setup")
          }
        }
      } catch {
        print("❌ [AppState] Failed to load user restaurant: \(error)")
      }
    }
  }
}

extension Notification.Name {
  static let userDidSignOut = Notification.Name("userDidSignOut")
}

extension ThemeMode: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .light: return "light"
    case .dark: return "dark"
    }
  }
  
  public init?(rawValue: String) {
    switch rawValue {
    case "light": self = .light
    case "dark": self = .dark
    default: return nil
    }
  }
}
