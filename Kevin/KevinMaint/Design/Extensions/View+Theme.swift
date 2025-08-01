import SwiftUI

extension View {
    /// Applies Kevin Maint theme-aware navigation bar styling
    func kevinNavigationBarStyle() -> some View {
        self
            .toolbarBackground(KMTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(KMTheme.currentTheme == .dark ? .dark : .light, for: .navigationBar)
    }
    
    /// Applies Kevin Maint theme-aware tab bar styling
    func kevinTabBarStyle() -> some View {
        self
            .toolbarBackground(KMTheme.cardBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(KMTheme.currentTheme == .dark ? .dark : .light, for: .tabBar)
    }
    
    /// Configures search bar appearance for current theme
    func configureSearchBarAppearance() -> some View {
        self.onAppear {
            updateSearchBarAppearance()
        }
        .onChange(of: KMTheme.currentTheme) { _, _ in
            updateSearchBarAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSearchBars"))) { _ in
            updateSearchBarAppearance()
        }
    }
}

private func updateSearchBarAppearance() {
    DispatchQueue.main.async {
        // Create a new appearance proxy to override existing settings
        let appearance = UISearchBar.appearance()
        
        // Force clear existing appearance
        appearance.backgroundColor = nil
        appearance.barTintColor = nil
        
        // Set theme-appropriate colors
        appearance.backgroundColor = UIColor(KMTheme.background)
        appearance.barTintColor = UIColor(KMTheme.background)
        appearance.tintColor = UIColor(KMTheme.accent)
        
        // Configure search text field
        appearance.searchTextField.backgroundColor = UIColor(KMTheme.cardBackground)
        appearance.searchTextField.textColor = UIColor(KMTheme.primaryText)
        appearance.searchTextField.tintColor = UIColor(KMTheme.accent)
        
        // Set placeholder color
        let placeholderColor = UIColor(KMTheme.secondaryText)
        appearance.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search...",
            attributes: [.foregroundColor: placeholderColor]
        )
        
        // Configure appearance based on theme
        if KMTheme.currentTheme == .light {
            appearance.searchBarStyle = .minimal
            appearance.barStyle = .default
            appearance.keyboardAppearance = .light
        } else {
            appearance.searchBarStyle = .minimal
            appearance.barStyle = .black
            appearance.keyboardAppearance = .dark
        }
        
        // Force update existing search bars
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                window.subviews.forEach { view in
                    updateSearchBarsRecursively(in: view)
                }
            }
    }
}

private func updateSearchBarsRecursively(in view: UIView) {
    if let searchBar = view as? UISearchBar {
        searchBar.backgroundColor = UIColor(KMTheme.background)
        searchBar.barTintColor = UIColor(KMTheme.background)
        searchBar.searchTextField.backgroundColor = UIColor(KMTheme.cardBackground)
        searchBar.searchTextField.textColor = UIColor(KMTheme.primaryText)
        searchBar.tintColor = UIColor(KMTheme.accent)
        searchBar.setNeedsDisplay()
        searchBar.layoutIfNeeded()
    }
    
    view.subviews.forEach { subview in
        updateSearchBarsRecursively(in: subview)
    }
}

