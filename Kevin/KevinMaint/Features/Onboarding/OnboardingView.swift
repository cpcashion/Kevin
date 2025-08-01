import SwiftUI
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit

// Apple Sign-In Coordinator
class AppleSignInCoordinator: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign-In")
        }
        return window
    }
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var showingTypewriter = false
    @State private var typewriterText = ""
    @State private var hasCompletedOnboarding = false
    @State private var isSigningIn = false
    @State private var showingAuthSuccess = false
    // Removed restaurant onboarding
    @State private var showingSignInOptions = false
    @State private var showingError = false
    @State private var errorMessage = ""
    // Removed GMB selection state
    @State private var currentNonce: String?
    // Removed GMB service
    @StateObject private var appleSignInCoordinator = AppleSignInCoordinator()
    @Binding var isPresented: Bool
    
    private let pages = OnboardingPage.allPages
    private let kevinBrandColor = KMTheme.background
    
    var body: some View {
        ZStack {
            // Solid background
            kevinBrandColor
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // Welcome screen
                welcomeScreen
                    .tag(0)
                
                // Onboarding pages
                ForEach(Array(OnboardingPage.allPages.enumerated()), id: \.offset) { index, page in
                    if index > 0 && index < pages.count - 1 { // Skip the first empty page and last sign-in page
                        OnboardingPageView(page: page, currentPage: $currentPage, pageIndex: index)
                            .tag(index)
                            .id("\(index)-\(page.title)")
                    } else if index == pages.count - 1 { // Last page is sign-in
                        signInScreen
                            .tag(index)
                    }
                }
            }
            .onChange(of: currentPage) { _, newPage in
                print("📱 TabView changed to page \(newPage): '\(newPage < pages.count ? pages[newPage].title : "Unknown")'")
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.4), value: currentPage)
            .gesture(
                // Disable swipe gesture on auth page to prevent bypassing authentication
                currentPage == pages.count - 1 ? DragGesture() : nil
            )
            
            // Navigation controls
            VStack {
                Spacer()
                
                if currentPage == 0 {
                    // Welcome screen button
                    Button("Let's Get Started") {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentPage = 1
                        }
                    }
                    .buttonStyle(KevinPrimaryButtonStyle())
                    .opacity(showingTypewriter ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4).delay(2.5), value: showingTypewriter)
                } else if currentPage < pages.count - 1 {
                    // Page indicators and navigation for onboarding pages
                    HStack(spacing: 20) {
                        // Skip button
                        Button("Skip") {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentPage = pages.count - 1 // Go to sign-in screen
                            }
                        }
                        .foregroundColor(KMTheme.tertiaryText)
                        .font(.subheadline)
                        
                        Spacer()
                        
                        // Page indicators (excluding welcome and sign-in pages)
                        HStack(spacing: 8) {
                            ForEach(1..<pages.count-1, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? KMTheme.accent : KMTheme.accent.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.4), value: currentPage)
                            }
                        }
                        
                        Spacer()
                        
                        // Next button
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(KevinSecondaryButtonStyle())
                    }
                }
                // No navigation controls on sign-in screen
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .onAppear {
            startWelcomeAnimation()
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        // Removed GMB restaurant selection sheet
        // Removed restaurant onboarding sheet
    }
    
    private var welcomeScreen: some View {
        VStack(spacing: 60) {
            VStack(spacing: 40) {
                // Kevin wordmark - positioned higher
                KevinWordmark()
                    .scaleEffect(showingTypewriter ? 1.0 : 0.8)
                    .opacity(showingTypewriter ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.3), value: showingTypewriter)
                
                // Animated greeting - larger font
                TypingText(
                    text: "Hey, I'm Kevin! I'll take care of maintenance so you can focus on your customers.",
                    speed: 25,
                    pauses: [
                        TypingPause("Kevin!", 600),
                        TypingPause("customers.", 400)
                    ]
                )
                .frame(minHeight: 80)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 80)
    }
    
    private var signInScreen: some View {
        VStack(spacing: 48) {
            Spacer()
            
            // Icon with fade-in (matching other onboarding screens)
            Image(systemName: "person.crop.circle.badge.checkmark.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(KMTheme.currentTheme == .light ? .black : KMTheme.accent)
            
            // Header matching last onboarding screen
            VStack(spacing: 28) {
                Text("Choose Your Sign-In Method")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(KMTheme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Select how you'd like to get started with Kevin")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(KMTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            
            // Sign-in options with 2 buttons
            VStack(spacing: 16) {
                // Google Sign-In - Direct regular Google sign-in
                Button(action: { signInWithGoogle() }) {
                    HStack {
                        Image("google-g-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        
                        Text("Sign in with Google")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(KMTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KMTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSigningIn)
                
                // Apple Sign-In
                Button(action: {
                    handleAppleSignInTap()
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(KMTheme.primaryText)
                        
                        Text("Sign in with Apple")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(KMTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KMTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSigningIn)
            }
            .padding(.horizontal, 20)
            
            // Loading indicator
            if isSigningIn {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.primaryText))
                        .scaleEffect(0.7)
                    
                    Text("Signing in...")
                        .font(.system(size: 14))
                        .foregroundColor(KMTheme.secondaryText)
                }
                .padding(.top, 12)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private func startWelcomeAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingTypewriter = true
        }
    }
    
    
    private var buttonTitle: String {
        return "Next"
    }
    
    private func handleButtonTap() {
        if currentPage == pages.count - 1 { // Sign-in options page
            showingSignInOptions = true
        } else {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentPage += 1
            }
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        // Note: We intentionally don't save completion to UserDefaults 
        // to ensure onboarding shows every time for demo purposes
        
        // Close the onboarding view
        withAnimation(.easeInOut(duration: 0.4)) {
            isPresented = false
        }
    }
    
    // MARK: - Sign-In Methods
    
    private func signInWithGoogle() {
        print("🔄 [OnboardingView] Starting regular Google sign-in...")
        isSigningIn = true
        
        Task {
            do {
                try await performGoogleSignIn()
                
                await MainActor.run {
                    isSigningIn = false
                    // Skip restaurant onboarding - go straight to app
                    completeOnboarding()
                }
                
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                print("❌ [OnboardingView] Google sign-in failed: \(error)")
            }
        }
    }
    
    private func performGoogleSignIn() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw NSError(domain: "SignInError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller"])
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "SignInError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google ID token"])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                     accessToken: result.user.accessToken.tokenString)
        
        // Sign in to Firebase with Google credential
        try await Auth.auth().signIn(with: credential)
        
        print("✅ Successfully signed in with Google!")
    }
    
    private func handleAppleSignInTap() {
        print("🍎 [OnboardingView] Starting Apple Sign-In...")
        isSigningIn = true
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Set up completion handler
        appleSignInCoordinator.onCompletion = { result in
            DispatchQueue.main.async {
                self.handleAppleSignIn(result)
            }
        }
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInCoordinator
        authorizationController.presentationContextProvider = appleSignInCoordinator
        
        // Perform the request
        authorizationController.performRequests()
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    print("❌ Invalid state: A login callback was received, but no login request was sent.")
                    isSigningIn = false
                    errorMessage = "Invalid authentication state"
                    showingError = true
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("❌ Unable to fetch identity token")
                    isSigningIn = false
                    errorMessage = "Unable to fetch identity token"
                    showingError = true
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("❌ Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                    isSigningIn = false
                    errorMessage = "Unable to serialize token"
                    showingError = true
                    return
                }
                
                // Initialize a Firebase credential
                let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                             rawNonce: nonce,
                                                             fullName: appleIDCredential.fullName)
                
                // Sign in with Firebase
                Auth.auth().signIn(with: credential) { (authResult, error) in
                    DispatchQueue.main.async {
                        self.isSigningIn = false
                        
                        if let error = error {
                            print("❌ Apple Sign-In Firebase error: \(error.localizedDescription)")
                            self.errorMessage = error.localizedDescription
                            self.showingError = true
                            return
                        }
                        
                        print("✅ Successfully signed in with Apple!")
                        
                        // Skip restaurant onboarding - go straight to app
                        self.completeOnboarding()
                    }
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.isSigningIn = false
                print("❌ Apple Sign-In error: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
    
    // MARK: - Apple Sign-In Nonce
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
          Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
          let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
              fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
          }

          randoms.forEach { random in
            if remainingLength == 0 {
              return
            }

            if random < charset.count {
              result.append(charset[Int(random)])
              remainingLength -= 1
            }
          }
        }

        return result
    }
    
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
          String(format: "%02x", $0)
        }.joined()

        return hashString
    }
    
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var currentPage: Int
    let pageIndex: Int
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showDescription = false
    @State private var showFeatures = false
    @State private var animateStopHand = false
    
    var body: some View {
        VStack(spacing: 48) {
            Spacer()
            
            // Icon with fade-in
            if !page.icon.isEmpty {
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(KMTheme.currentTheme == .light ? .black : KMTheme.accent)
                    .opacity(showIcon ? 1.0 : 0.0)
                    .scaleEffect(showIcon ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 0.5), value: showIcon)
            }
            
            // Content with smooth flow
            VStack(spacing: 28) {
                // Title with fade-in
                Text(page.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(KMTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(showTitle ? 1.0 : 0.0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: showTitle)
                
                // Description with fade-in
                Text(page.description)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(KMTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineSpacing(6)
                    .opacity(showDescription ? 1.0 : 0.0)
                    .offset(y: showDescription ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: showDescription)
                
                // Features with staggered fade-in
                if !page.features.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(page.features.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(bulletColor(for: index))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(showFeatures ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: showFeatures)
                                
                                Text(feature)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(KMTheme.secondaryText)
                                
                                Spacer()
                            }
                            .opacity(showFeatures ? 1.0 : 0.0)
                            .offset(x: showFeatures ? 0 : -30)
                            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.1), value: showFeatures)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: 640, alignment: .center)
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            print("🎬 OnboardingPageView appeared for: '\(page.title)' (index: \(pageIndex))")
        }
        .onDisappear {
            print("🎬 OnboardingPageView disappeared for: '\(page.title)' (index: \(pageIndex))")
        }
        .onChange(of: currentPage) { _, newPage in
            print("🔄 Page \(pageIndex) ('\(page.title)') detected currentPage change to: \(newPage)")
            if newPage == pageIndex {
                print("✅ This page is now current - starting animation")
                resetAnimationState()
                startAnimation()
            } else {
                print("❌ This page is not current - resetting to hidden state")
                resetAnimationState()
            }
        }
        .id(page.title)
    }
    
    private func bulletColor(for index: Int) -> Color {
        let colors = [KMTheme.accent, KMTheme.success, KMTheme.danger]
        return colors[index % colors.count]
    }
    
    private func resetAnimationState() {
        print("🔄 Resetting animation state for: '\(page.title)'")
        showIcon = false
        showTitle = false
        showDescription = false
        showFeatures = false
        animateStopHand = false
        print("   ✅ All animation states reset to false")
    }
    
    private func startAnimation() {
        print("🚀 Starting animation sequence for: '\(page.title)'")
        
        // Start staggered animation sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("   🎯 Setting showIcon = true for '\(self.page.title)'")
            self.showIcon = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("   📝 Setting showTitle = true for '\(self.page.title)'")
            self.showTitle = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            print("   📄 Setting showDescription = true for '\(self.page.title)'")
            self.showDescription = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            print("   ✨ Setting showFeatures = true for '\(self.page.title)'")
            self.showFeatures = true
        }
    }
    
}

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let features: [String]
    
    static let allPages: [OnboardingPage] = [
        // Welcome page (index 0)
        OnboardingPage(
            title: "Welcome",
            description: "",
            icon: "",
            features: []
        ),
        
        // Page 1: The Problem
        OnboardingPage(
            title: "Stop Maintenance Headaches",
            description: "Kevin handles all your maintenance needs so you can focus on operations.",
            icon: "hand.raised.brakesignal",
            features: [
                "No more maintenance stress",
                "Kevin coordinates all repairs",
                "Get back to running your business"
            ]
        ),
        
        // Page 2: The Solution
        OnboardingPage(
            title: "Just Snap & Submit",
            description: "Take a photo and Kevin's team takes care of the rest",
            icon: "camera.shutter.button",
            features: [
                "Instant AI damage assessment",
                "Kevin schedules qualified technicians",
                "Professional repairs guaranteed"
            ]
        ),
        
        // Page 3: Track Everything
        OnboardingPage(
            title: "Complete Peace of Mind",
            description: "Track everything from your phone while Kevin handles the work",
            icon: "person.checkmark.and.xmark",
            features: [
                "Real-time repair updates",
                "Direct communication with Kevin's team",
                "All maintenance history in one place"
            ]
        ),
        
        // Page 4: Sign-In Options
        OnboardingPage(
            title: "Choose Your Sign-In Method",
            description: "Select how you'd like to get started with Kevin",
            icon: "person.2.circle.fill",
            features: [
                "Quick Google Sign-In for easy access",
                "Secure authentication & data sync"
            ]
        ),
        
    ]
}


struct KevinPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KMTheme.accent)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct KevinSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(KMTheme.accent.opacity(0.2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
