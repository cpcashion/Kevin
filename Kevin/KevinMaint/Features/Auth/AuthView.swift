import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import AuthenticationServices
import CryptoKit

struct AuthView: View {
  @EnvironmentObject var appState: AppState
  @State private var isSigningIn = false
  @State private var showingError = false
  @State private var errorMessage = ""
  
  var body: some View {
    ZStack {
      // Background matching onboarding
      KMTheme.background
        .ignoresSafeArea()
      
      if appState.isAuthed {
        let _ = print("🔐 [AuthView] User is authenticated - showing welcome message")
        VStack(spacing: 16) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 48))
            .foregroundColor(.green)
          Text("Welcome!")
            .font(.headline)
          if let email = appState.currentUser?.email {
            Text(email)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Text("You're signed in and ready to report issues")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(32)
      } else {
        let _ = print("🔐 [AuthView] User NOT authenticated - showing sign-in options")
        VStack(spacing: 48) {
          Spacer()
          
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
          
          // Sign-in options
          VStack(spacing: 16) {
            let _ = print("🔐 [AuthView] Rendering sign-in buttons")
            // Apple Sign-In (Primary - Required by App Store)
            SignInWithAppleButton(
              onRequest: { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
              },
              onCompletion: { result in
                handleAppleSignIn(result)
              }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 64)
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(KMTheme.primaryText.opacity(0.3), lineWidth: 1)
            )
            
            // Google Sign-In (Alternative)
            Button(action: signInWithGoogle) {
              HStack(spacing: 16) {
                // Google "G" icon
                Image("google-g-logo")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 24, height: 24)
                
                Text("Sign in with Google")
                  .font(.headline)
                  .fontWeight(.medium)
                  .foregroundColor(KMTheme.primaryText)
                
                Spacer()
              }
              .padding(20)
              .background(.clear)
              .overlay(
                RoundedRectangle(cornerRadius: 16)
                  .stroke(KMTheme.primaryText.opacity(0.3), lineWidth: 1)
              )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSigningIn)
          }
          
          // Removed Demo Mode button - automatic geo-detection handles demo mode
          
          // Loading indicator
          if isSigningIn {
            HStack(spacing: 12) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.primaryText))
                .scaleEffect(0.8)
              
              Text("Signing in...")
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
            }
            .padding(.top, 16)
          }
          
          Spacer()
        }
        .padding(.horizontal, 32)
      }
    }
    .alert("Sign In Error", isPresented: $showingError) {
      Button("OK") { }
    } message: {
      Text(errorMessage)
    }
  }
  
  // MARK: - Sign-In Methods
  
  private func signInWithGoogle() {
    print("🔄 [AuthView] ===== GOOGLE SIGN-IN STARTED =====")
    print("🔄 [AuthView] Current Firebase Auth state: \(Auth.auth().currentUser?.uid ?? "nil")")
    isSigningIn = true
    
    Task {
      do {
        print("🔄 [AuthView] Calling performGoogleSignIn()...")
        try await performGoogleSignIn()
        
        print("✅ [AuthView] Google sign-in completed successfully")
        print("✅ [AuthView] New Firebase Auth user: \(Auth.auth().currentUser?.uid ?? "nil")")
        
        await MainActor.run {
          isSigningIn = false
          print("✅ [AuthView] Updated UI state - sign-in complete")
          // AppState will handle navigation to restaurant onboarding
        }
        
      } catch {
        print("❌ [AuthView] ===== GOOGLE SIGN-IN FAILED =====")
        print("❌ [AuthView] Error: \(error)")
        print("❌ [AuthView] Error description: \(error.localizedDescription)")
        print("❌ [AuthView] Error code: \((error as NSError).code)")
        print("❌ [AuthView] Error domain: \((error as NSError).domain)")
        
        await MainActor.run {
          isSigningIn = false
          errorMessage = error.localizedDescription
          showingError = true
        }
      }
    }
  }
  
  private func performGoogleSignIn() async throws {
    print("🔄 [AuthView] performGoogleSignIn() called")
    
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
      print("❌ [AuthView] Could not find window scene")
      throw NSError(domain: "SignInError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find window scene"])
    }
    
    guard let window = windowScene.windows.first else {
      print("❌ [AuthView] Could not find window")
      throw NSError(domain: "SignInError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find window"])
    }
    
    guard let rootViewController = window.rootViewController else {
      print("❌ [AuthView] Could not find root view controller")
      throw NSError(domain: "SignInError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller"])
    }
    
    print("✅ [AuthView] Found root view controller: \(type(of: rootViewController))")
    
    print("🔄 [AuthView] Calling GIDSignIn.sharedInstance.signIn()...")
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
    
    print("✅ [AuthView] Google sign-in result received")
    print("✅ [AuthView] User ID: \(result.user.userID ?? "nil")")
    print("✅ [AuthView] User email: \(result.user.profile?.email ?? "nil")")
    print("✅ [AuthView] User name: \(result.user.profile?.name ?? "nil")")
    
    guard let idToken = result.user.idToken?.tokenString else {
      print("❌ [AuthView] Failed to get Google ID token")
      throw NSError(domain: "SignInError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google ID token"])
    }
    
    print("✅ [AuthView] Got Google ID token: \(idToken.prefix(20))...")
    print("✅ [AuthView] Got Google access token: \(result.user.accessToken.tokenString.prefix(20))...")
    
    let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                 accessToken: result.user.accessToken.tokenString)
    
    print("✅ [AuthView] Created Firebase credential")
    
    // Sign in to Firebase with Google credential
    print("🔄 [AuthView] Signing in to Firebase with Google credential...")
    let authResult = try await Auth.auth().signIn(with: credential)
    
    print("✅ [AuthView] Successfully signed in with Google!")
    print("✅ [AuthView] Firebase user ID: \(authResult.user.uid)")
    print("✅ [AuthView] Firebase user email: \(authResult.user.email ?? "nil")")
    print("✅ [AuthView] Firebase user verified: \(authResult.user.isEmailVerified)")
  }
  
  private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
    isSigningIn = true
    
    switch result {
    case .success(let authorization):
      if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
        guard let nonce = currentNonce else {
          fatalError("Invalid state: A login callback was received, but no login request was sent.")
        }
        guard let appleIDToken = appleIDCredential.identityToken else {
          print("❌ Unable to fetch identity token")
          isSigningIn = false
          return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
          print("❌ Unable to serialize token string from data: \(appleIDToken.debugDescription)")
          isSigningIn = false
          return
        }
        
        // Initialize a Firebase credential
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                     rawNonce: nonce,
                                                     fullName: appleIDCredential.fullName)
        
        // Sign in with Firebase
        print("🔄 [AuthView] Signing in to Firebase with Apple credential...")
        Auth.auth().signIn(with: credential) { (authResult, error) in
          DispatchQueue.main.async {
            self.isSigningIn = false
            
            if let error = error {
              print("❌ [AuthView] ===== APPLE SIGN-IN FIREBASE ERROR =====")
              print("❌ [AuthView] Error: \(error)")
              print("❌ [AuthView] Error description: \(error.localizedDescription)")
              print("❌ [AuthView] Error code: \((error as NSError).code)")
              print("❌ [AuthView] Error domain: \((error as NSError).domain)")
              self.errorMessage = error.localizedDescription
              self.showingError = true
              return
            }
            
            print("✅ [AuthView] Successfully signed in with Apple!")
            if let authResult = authResult {
              print("✅ [AuthView] Firebase user ID: \(authResult.user.uid)")
              print("✅ [AuthView] Firebase user email: \(authResult.user.email ?? "nil")")
              print("✅ [AuthView] Firebase user verified: \(authResult.user.isEmailVerified)")
            }
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
  @State private var currentNonce: String?
  
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
