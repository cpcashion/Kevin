import SwiftUI

struct HelpView: View {
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []
    
    let faqSections: [FAQSection] = [
        FAQSection(
            title: "Getting Started",
            items: [
                FAQItem(
                    question: "How do I report a maintenance issue?",
                    answer: "Tap the camera icon in the Issues tab, take a photo of the problem, and our AI will automatically analyze it. Confirm the location and submit - it's that simple!"
                ),
                FAQItem(
                    question: "What happens after I submit an issue?",
                    answer: "Kevin's team receives your request immediately. You'll get real-time updates as we review, schedule, and complete the work. You can track everything in the Issues tab."
                ),
                FAQItem(
                    question: "How do I check the status of my requests?",
                    answer: "Go to the Issues tab to see all your maintenance requests. Each issue shows its current status: Reported, In Progress, or Completed."
                )
            ]
        ),
        FAQSection(
            title: "AI Analysis",
            items: [
                FAQItem(
                    question: "How accurate is the AI analysis?",
                    answer: "Our AI uses advanced computer vision to identify maintenance issues with high accuracy. It provides estimates for repair time, materials needed, and potential costs based on thousands of similar cases."
                ),
                FAQItem(
                    question: "Can I edit the AI's analysis?",
                    answer: "Yes! The AI analysis is a starting point. You can always add your own description, notes, or corrections when submitting an issue."
                ),
                FAQItem(
                    question: "What if the AI doesn't recognize the problem?",
                    answer: "No problem! You can manually describe the issue and add any relevant details. Our team will review and handle it just the same."
                )
            ]
        ),
        FAQSection(
            title: "Locations & Restaurants",
            items: [
                FAQItem(
                    question: "How does location detection work?",
                    answer: "When you take a photo, the app uses your GPS location to automatically suggest the nearest restaurant. You can confirm or change the location before submitting."
                ),
                FAQItem(
                    question: "Can I manage multiple locations?",
                    answer: "Yes! If you manage multiple restaurants, you can view and track maintenance for all locations in the Locations tab."
                ),
                FAQItem(
                    question: "How do I view a location on the map?",
                    answer: "In the Locations tab, tap any location card to see details, then tap the map icon to view it on an interactive map."
                )
            ]
        ),
        FAQSection(
            title: "Messaging & Communication",
            items: [
                FAQItem(
                    question: "How do I contact Kevin's team?",
                    answer: "Use the Messages tab to chat directly with our team. You can also message about specific issues from the issue detail page."
                ),
                FAQItem(
                    question: "Will I get notifications for updates?",
                    answer: "Yes! You'll receive push notifications when there are updates to your issues, new messages, or work completions. You can customize these in Settings."
                ),
                FAQItem(
                    question: "Can I attach photos to messages?",
                    answer: "Absolutely! Tap the camera icon in any conversation to share additional photos or documentation."
                )
            ]
        ),
        FAQSection(
            title: "Account & Billing",
            items: [
                FAQItem(
                    question: "How do I update my account information?",
                    answer: "Go to Profile → Account Settings to update your name, phone number, and preferences."
                ),
                FAQItem(
                    question: "How does billing work?",
                    answer: "If you're a restaurant owner, you can manage your subscription and view billing history in Profile → Subscription."
                ),
                FAQItem(
                    question: "How do I cancel my subscription?",
                    answer: "Go to Profile → Subscription → Manage Plan. You can cancel anytime, and you'll retain access until the end of your billing period."
                )
            ]
        )
    ]
    
    var filteredSections: [FAQSection] {
        if searchText.isEmpty {
            return faqSections
        }
        
        return faqSections.compactMap { section in
            let filteredItems = section.items.filter {
                $0.question.localizedCaseInsensitiveContains(searchText) ||
                $0.answer.localizedCaseInsensitiveContains(searchText)
            }
            
            if filteredItems.isEmpty {
                return nil
            }
            
            return FAQSection(title: section.title, items: filteredItems)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(KMTheme.tertiaryText)
                    
                    TextField("Search help articles...", text: $searchText)
                        .foregroundColor(KMTheme.primaryText)
                }
                .padding(12)
                .background(KMTheme.cardBackground)
                .cornerRadius(10)
                
                // FAQ Sections
                VStack(alignment: .leading, spacing: 16) {
                    Text("Frequently Asked Questions")
                        .font(.headline)
                        .foregroundColor(KMTheme.primaryText)
                    
                    ForEach(filteredSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(KMTheme.accent)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            
                            VStack(spacing: 1) {
                                ForEach(section.items) { item in
                                    FAQItemView(
                                        item: item,
                                        isExpanded: expandedSections.contains(item.id)
                                    ) {
                                        toggleSection(item.id)
                                    }
                                }
                            }
                        }
                        .background(KMTheme.cardBackground)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(20)
        }
        .background(KMTheme.background)
        .navigationTitle("Help & FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .kevinNavigationBarStyle()
    }
    
    private func toggleSection(_ id: String) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }
}

struct FAQSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [FAQItem]
}

struct FAQItem: Identifiable {
    let id = UUID().uuidString
    let question: String
    let answer: String
}

struct FAQItemView: View {
    let item: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.question)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(KMTheme.primaryText)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KMTheme.tertiaryText)
                }
                
                if isExpanded {
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundColor(KMTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .background(KMTheme.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}
