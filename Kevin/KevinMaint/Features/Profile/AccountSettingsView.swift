import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var showingSaveSuccess = false
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var isDeleting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Information Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile Information")
                        .font(.headline)
                        .foregroundColor(KMTheme.primaryText)
                    
                    VStack(spacing: 16) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                            
                            TextField("Your name", text: $name)
                                .textFieldStyle(AccountKMTextFieldStyle())
                        }
                        
                        // Email Field (Read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                            
                            TextField("Email address", text: $email)
                                .textFieldStyle(AccountKMTextFieldStyle())
                                .disabled(true)
                                .opacity(0.6)
                            
                            Text("Email cannot be changed")
                                .font(.caption)
                                .foregroundColor(KMTheme.tertiaryText)
                        }
                        
                        // Phone Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                            
                            TextField("Phone number", text: $phone)
                                .textFieldStyle(AccountKMTextFieldStyle())
                                .keyboardType(.phonePad)
                        }
                    }
                    .padding(16)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                }
                
                // Account Information Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Account Information")
                        .font(.headline)
                        .foregroundColor(KMTheme.primaryText)
                    
                    VStack(spacing: 0) {
                        if let user = appState.currentAppUser {
                            AccountInfoRow(label: "Role", value: user.role.rawValue.capitalized)
                            
                            if let restaurant = appState.currentRestaurant {
                                Divider().background(KMTheme.border)
                                AccountInfoRow(label: "Restaurant", value: restaurant.name)
                            }
                        }
                    }
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                }
                
                // Save Button
                Button(action: saveSettings) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KMTheme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
                .opacity(isSaving ? 0.6 : 1.0)
                
                // Delete Account Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Danger Zone")
                        .font(.headline)
                        .foregroundColor(KMTheme.danger)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delete Account")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                        
                        Text("Permanently delete your account and all associated data. This action cannot be undone.")
                            .font(.caption)
                            .foregroundColor(KMTheme.secondaryText)
                        
                        Button(action: { showingDeleteConfirmation = true }) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Delete My Account")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(KMTheme.danger)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isDeleting)
                        .opacity(isDeleting ? 0.6 : 1.0)
                    }
                    .padding(16)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KMTheme.danger.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top, 32)
            }
            .padding(20)
        }
        .background(KMTheme.background)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .kevinNavigationBarStyle()
        .onAppear(perform: loadUserData)
        .alert("Settings Saved", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your account settings have been updated successfully.")
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This will delete all your data including issues, conversations, and photos. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
    }
    
    private func loadUserData() {
        if let user = appState.currentAppUser {
            name = user.name
            email = user.email ?? ""
            phone = user.phone ?? ""
        }
    }
    
    private func saveSettings() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isSaving = true
        
        Task {
            do {
                // Update user data in Firestore
                let db = Firestore.firestore()
                try await db.collection("users").document(userId).updateData([
                    "name": name,
                    "phone": phone
                ])
                
                // Update local app state
                if var user = appState.currentAppUser {
                    user.name = name
                    user.phone = phone
                    appState.currentAppUser = user
                }
                
                await MainActor.run {
                    isSaving = false
                    showingSaveSuccess = true
                }
            } catch {
                print("❌ Error saving settings: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func deleteAccount() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeleting = true
        
        Task {
            do {
                let db = Firestore.firestore()
                
                // Delete user's data from Firestore
                // Note: In production, this should be done via Cloud Function for security
                // For now, we'll delete the user document and let Firebase Auth handle the rest
                
                // Delete user document
                try await db.collection("users").document(userId).delete()
                
                // Delete Firebase Auth account
                try await Auth.auth().currentUser?.delete()
                
                // Sign out and reset app state
                await MainActor.run {
                    appState.signOut()
                    isDeleting = false
                }
            } catch let error as NSError {
                print("❌ Error deleting account: \(error)")
                
                await MainActor.run {
                    isDeleting = false
                    
                    // Check if re-authentication is required
                    if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        deleteErrorMessage = "For security reasons, please sign out and sign back in before deleting your account."
                    } else {
                        deleteErrorMessage = "Failed to delete account. Please try again or contact support."
                    }
                    
                    showingDeleteError = true
                }
            }
        }
    }
}

struct AccountInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(KMTheme.primaryText)
                .fontWeight(.medium)
        }
        .padding(16)
    }
}

struct AccountKMTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(KMTheme.inputBackground)
            .foregroundColor(KMTheme.inputText)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KMTheme.inputBorder, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
            .environmentObject(AppState())
    }
}
