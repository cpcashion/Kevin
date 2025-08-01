import SwiftUI

struct KevinWordmark: View {
    var body: some View {
        Image(KMTheme.currentTheme == .light ? "kevin-wordmark-beta-light" : "kevin-wordmark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 240)
    }
}

struct KevinWordmarkSmall: View {
    var body: some View {
        Image(KMTheme.currentTheme == .light ? "kevin-wordmark-beta-light" : "kevin-wordmark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 32)
    }
}

#Preview {
    ZStack {
      Color("5F3BFF")
            .ignoresSafeArea()
        
        KevinWordmark()
    }
}
