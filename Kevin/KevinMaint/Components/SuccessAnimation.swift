import SwiftUI

struct SuccessAnimation: View {
  let message: String
  let restaurantName: String?
  @Binding var isShowing: Bool
  
  @State private var checkmarkScale: CGFloat = 0
  @State private var checkmarkRotation: Double = 0
  @State private var rippleScale: CGFloat = 0
  @State private var rippleOpacity: Double = 0
  @State private var messageOpacity: Double = 0
  @State private var messageOffset: CGFloat = 20
  
  var body: some View {
    ZStack {
      // Solid dark blue background - no transparency
      KMTheme.background
        .ignoresSafeArea()
        .opacity(isShowing ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isShowing)
      
      VStack(spacing: 48) {
        // Success icon with ripple effect
        ZStack {
          // Ripple circles
          ForEach(0..<3) { index in
            Circle()
              .stroke(KMTheme.success.opacity(0.3), lineWidth: 2)
              .frame(width: 90, height: 90)
              .scaleEffect(rippleScale)
              .opacity(rippleOpacity)
              .animation(
                .easeOut(duration: 1.5)
                  .delay(Double(index) * 0.2)
                  .repeatCount(2, autoreverses: false),
                value: rippleScale
              )
          }
          
          // Main success circle
          Circle()
            .fill(KMTheme.success)
            .frame(width: 60, height: 60)
            .scaleEffect(checkmarkScale)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: checkmarkScale)
          
          // Checkmark
          Image(systemName: "checkmark")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .scaleEffect(checkmarkScale)
            .rotationEffect(.degrees(checkmarkRotation))
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: checkmarkScale)
        }
        
        // Success message
        VStack(spacing: 8) {
          Text("✅ Issue Created!")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .opacity(messageOpacity)
            .offset(y: messageOffset)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: messageOpacity)
          
          if let restaurantName = restaurantName {
            Text("at \(restaurantName)")
              .font(.subheadline)
              .foregroundColor(.white.opacity(0.8))
              .opacity(messageOpacity)
              .offset(y: messageOffset)
              .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: messageOpacity)
          }
        }
        
        // Shimmer effect for extra magic
        shimmerEffect
          .opacity(messageOpacity)
          .animation(.easeInOut(duration: 1.0).delay(0.6), value: messageOpacity)
      }
    }
    .onAppear {
      startAnimation()
    }
    .onChange(of: isShowing) { _, newValue in
      if newValue {
        startAnimation()
      } else {
        resetAnimation()
      }
    }
  }
  
  private var shimmerEffect: some View {
    HStack(spacing: 4) {
      ForEach(0..<5) { index in
        Circle()
          .fill(LinearGradient(
            colors: [.white.opacity(0.3), .white.opacity(0.8), .white.opacity(0.3)],
            startPoint: .leading,
            endPoint: .trailing
          ))
          .frame(width: 6, height: 6)
          .scaleEffect(1.0)
          .animation(
            .easeInOut(duration: 0.8)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.1),
            value: messageOpacity
          )
      }
    }
  }
  
  private func startAnimation() {
    // Reset all values
    resetAnimation()
    
    // Start the animation sequence
    withAnimation {
      checkmarkScale = 1.0
      checkmarkRotation = 360
      rippleScale = 2.0
      rippleOpacity = 1.0
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      withAnimation {
        messageOpacity = 1.0
        messageOffset = 0
      }
    }
    
    // Auto-dismiss after 4 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
      withAnimation(.easeOut(duration: 0.3)) {
        isShowing = false
      }
    }
  }
  
  private func resetAnimation() {
    checkmarkScale = 0
    checkmarkRotation = 0
    rippleScale = 0
    rippleOpacity = 0
    messageOpacity = 0
    messageOffset = 20
  }
}

// MARK: - Toast Notification
struct MagicalToast: View {
  let message: String
  let icon: String
  let color: Color
  @Binding var isShowing: Bool
  
  @State private var offset: CGFloat = 100
  @State private var opacity: Double = 0
  
  var body: some View {
    VStack {
      Spacer()
      
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.title3)
          .foregroundColor(color)
        
        Text(message)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(KMTheme.cardBackground)
          .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
      )
      .padding(.horizontal, 16)
      .offset(y: offset)
      .opacity(opacity)
      .onAppear {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
          offset = -100 // Move up from bottom
          opacity = 1
        }
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          withAnimation(.easeOut(duration: 0.3)) {
            offset = 100
            opacity = 0
          }
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
          }
        }
      }
    }
  }
}

// MARK: - Loading Shimmer for Location Detection
struct LocationDetectionLoader: View {
  @State private var shimmerOffset: CGFloat = -200
  @State private var pulseScale: CGFloat = 1.0
  
  var body: some View {
    VStack(spacing: 16) {
      // Subtle location icon with minimal animation
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(KMTheme.accent.opacity(0.15))
            .frame(width: 40, height: 40)
            .scaleEffect(pulseScale)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseScale)
          
          Image(systemName: "location.fill")
            .font(.title3)
            .foregroundColor(KMTheme.accent)
        }
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Finding your location...")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
          
          Text("Detecting nearby restaurants")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        Spacer()
        
        // Simple loading dots
        HStack(spacing: 4) {
          ForEach(0..<3) { index in
            Circle()
              .fill(KMTheme.accent)
              .frame(width: 6, height: 6)
              .scaleEffect(pulseScale)
              .animation(
                .easeInOut(duration: 0.8)
                  .repeatForever(autoreverses: true)
                  .delay(Double(index) * 0.2),
                value: pulseScale
              )
          }
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border.opacity(0.3), lineWidth: 1)
    )
    .onAppear {
      shimmerOffset = 200
      pulseScale = 1.1
    }
  }
}

// MARK: - Preview
struct SuccessAnimation_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      SuccessAnimation(
        message: "Issue created successfully!",
        restaurantName: "Kindred Restaurant",
        isShowing: .constant(true)
      )
      .preferredColorScheme(.dark)
      
      LocationDetectionLoader()
        .preferredColorScheme(.dark)
        .padding()
    }
  }
}
