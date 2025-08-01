import SwiftUI

struct DemoModeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(KMTheme.accent)

                Text("Demo Mode")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(KMTheme.primaryText)

                Text("Explore Kevin without signing in. This is a placeholder demo screen — customize it with the flows and sample data you want to showcase.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(KMTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KMTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

#Preview {
    DemoModeView()
        .environmentObject(AppState())
}
