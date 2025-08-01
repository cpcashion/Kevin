//
//  ContentView.swift
//  Kevin
//
//  Created by Christopher Cashion on 9/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Full screen background that covers all safe areas
            KMTheme.background
                .ignoresSafeArea(.all)
            
            RootView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
