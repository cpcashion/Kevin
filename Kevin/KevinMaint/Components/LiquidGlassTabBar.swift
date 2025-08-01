import SwiftUI

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Liquid Glass Tab Bar
struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    
    @State private var dragOffset: CGFloat = 0
    @Namespace private var tabSelection
    
    private var liquidGlassBackground: some View {
        RoundedRectangle(cornerRadius: 32)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.cyan.opacity(0.2),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 25, x: 0, y: 15)
            .shadow(color: Color.blue.opacity(0.1), radius: 40, x: 0, y: 20)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.title) { index, tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == index,
                    namespace: tabSelection
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(liquidGlassBackground)
        .frame(height: 72)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    
                    // Switch tabs if dragged far enough
                    if abs(dragOffset) > 60 {
                        let newTab = dragOffset > 0 ? max(0, selectedTab - 1) : min(tabs.count - 1, selectedTab + 1)
                        if newTab != selectedTab {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                selectedTab = newTab
                            }
                            dragOffset = 0
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // Icon only - no title
            Group {
                if let customIcon = tab.customIcon {
                    customIcon
                } else if !tab.systemImage.isEmpty {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 24, weight: .medium))
                }
            }
            .opacity(isSelected ? 1.0 : 0.6)
            .frame(width: 28, height: 28)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                // Selection indicator with larger bubble and more padding
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                            )
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Tab Item Model
struct TabItem {
    let title: String
    let systemImage: String
    let customIcon: AnyView?
    
    init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
        self.customIcon = nil
    }
    
    init<Content: View>(title: String, customIcon: Content) {
        self.title = title
        self.systemImage = ""
        self.customIcon = AnyView(customIcon)
    }
}

// MARK: - Liquid Glass Tab Container
struct LiquidGlassTabContainer<Content: View>: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    let content: Content
    
    init(selectedTab: Binding<Int>, tabs: [TabItem], @ViewBuilder content: () -> Content) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Main content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                Spacer()
                
                // Liquid Glass Tab Bar
                LiquidGlassTabBar(selectedTab: $selectedTab, tabs: tabs)
                    .padding(.horizontal, 24)
                    .padding(.bottom, -15) // Lower positioning
            }
        }
    }
}

// MARK: - Preview
struct LiquidGlassTabBar_Previews: PreviewProvider {
    static var previews: some View {
        LiquidGlassTabContainer(
            selectedTab: .constant(0),
            tabs: [
                TabItem(title: "AI Snap", systemImage: "camera.fill"),
                TabItem(title: "Issues", systemImage: "list.bullet"),
                TabItem(title: "Messages", systemImage: "message"),
                TabItem(title: "Locations", systemImage: "building.2"),
                TabItem(title: "Profile", systemImage: "person.circle")
            ]
        ) {
            ZStack {
                // Beautiful gradient background like in the attachment
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.8),
                        Color.cyan.opacity(0.6),
                        Color.blue.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Text("Liquid Glass Tab Bar")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Beautiful Liquid Glass Design")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
