import SwiftUI

/// Card that displays service availability information to users
struct ServiceAvailabilityCard: View {
    let availability: ServiceAvailability
    let onContinue: () -> Void
    let onJoinWaitlist: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var showingWaitlistForm = false
    
    private var message: AvailabilityMessage {
        ServiceAvailabilityService.shared.getAvailabilityMessage(for: availability)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping backdrop for unavailable areas
                    if message.isAvailable {
                        onDismiss?()
                    }
                }
            
            // Card content
            VStack(spacing: 24) {
                // Icon and title
                VStack(spacing: 16) {
                    Image(systemName: message.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(message.isAvailable ? KMTheme.success : KMTheme.warning)
                    
                    Text(message.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(KMTheme.primaryText)
                        .multilineTextAlignment(.center)
                }
                
                // Message content
                Text(message.message)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(KMTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Warning banner for unavailable areas
                if message.showWarning {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(KMTheme.warning)
                            Text("Limited Functionality")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KMTheme.primaryText)
                        }
                        
                        Text("You can still create maintenance requests, but Kevin's team won't be able to service them until we expand to your area.")
                            .font(.system(size: 13))
                            .foregroundColor(KMTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(KMTheme.warning.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KMTheme.warning.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if message.isAvailable {
                        // Continue button for available areas
                        Button(action: onContinue) {
                            Text(message.actionText)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(KMTheme.accent)
                                .cornerRadius(12)
                        }
                    } else {
                        // Join waitlist button for unavailable areas
                        Button(action: {
                            showingWaitlistForm = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                Text("Join Waitlist")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(KMTheme.accent)
                            .cornerRadius(12)
                        }
                        
                        // Continue anyway button
                        Button(action: onContinue) {
                            Text("Continue Anyway")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(KMTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
            }
            .padding(24)
            .background(KMTheme.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingWaitlistForm) {
            WaitlistFormView(
                onSubmit: {
                    showingWaitlistForm = false
                    onJoinWaitlist?()
                }
            )
        }
    }
}

// MARK: - Waitlist Form

struct WaitlistFormView: View {
    let onSubmit: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var businessName = ""
    @State private var phoneNumber = ""
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 50))
                            .foregroundColor(KMTheme.accent)
                        
                        Text("Join the Waitlist")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(KMTheme.primaryText)
                        
                        Text("We'll notify you when Kevin expands to your area!")
                            .font(.system(size: 16))
                            .foregroundColor(KMTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    
                    // Form fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Business Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KMTheme.primaryText)
                            
                            TextField("Your restaurant or business", text: $businessName)
                                .textFieldStyle(WaitlistTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email Address")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KMTheme.primaryText)
                            
                            TextField("your@email.com", text: $email)
                                .textFieldStyle(WaitlistTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number (Optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KMTheme.primaryText)
                            
                            TextField("(555) 123-4567", text: $phoneNumber)
                                .textFieldStyle(WaitlistTextFieldStyle())
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        }
                    }
                    
                    // Submit button
                    Button(action: submitWaitlist) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Submitting...")
                            } else {
                                Text("Join Waitlist")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? KMTheme.accent : KMTheme.accent.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
                .padding(20)
            }
            .background(KMTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
            }
            .alert("You're on the List! 🎉", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                    onSubmit()
                }
            } message: {
                Text("We'll notify you as soon as Kevin expands to your area. Thanks for your interest!")
            }
        }
    }
    
    private var isFormValid: Bool {
        !businessName.isEmpty && !email.isEmpty && email.contains("@")
    }
    
    private func submitWaitlist() {
        isSubmitting = true
        
        // TODO: Submit to Firebase waitlist collection
        Task {
            do {
                try await FirebaseClient.shared.submitWaitlistEntry(
                    businessName: businessName,
                    email: email,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                    location: "Outside Charlotte, NC service area"
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                print("❌ Failed to submit waitlist entry: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    // Show error alert
                }
            }
        }
    }
}

struct WaitlistTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(KMTheme.inputBackground)
            .foregroundColor(KMTheme.inputText)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KMTheme.inputBorder, lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    ServiceAvailabilityCard(
        availability: .unavailable(distanceFromCenter: 150, nearestServiceCity: "Charlotte, NC"),
        onContinue: {},
        onJoinWaitlist: {},
        onDismiss: {}
    )
}
