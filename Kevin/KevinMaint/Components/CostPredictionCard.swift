import SwiftUI

struct CostPredictionCard: View {
    let prediction: CostPrediction
    @State private var showingBreakdown = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main cost display
            mainCostSection
            
            // Savings banner
            if let savings = prediction.savingsOpportunity {
                savingsBanner(savings)
            }
            
            // Expandable breakdown
            if showingBreakdown {
                detailedBreakdown
            }
            
            // Toggle button
            toggleButton
        }
        .background(KMTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
    }
    
    private var mainCostSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(KMTheme.accent)
                
                Text("Estimated Cost")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
                
                // Confidence indicator
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(confidenceColor)
                    Text("\(Int(prediction.confidenceScore * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(confidenceColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Cost range
            VStack(spacing: 8) {
                Text(prediction.displayRange)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(KMTheme.primaryText)
                
                Text("Most likely: $\(Int(prediction.mostLikelyCost))")
                    .font(.subheadline)
                    .foregroundColor(KMTheme.secondaryText)
            }
            
            // Quick summary
            HStack(spacing: 20) {
                costSummaryItem(
                    icon: "hammer.fill",
                    label: "Labor",
                    value: "$\(Int(prediction.breakdown.labor.total))"
                )
                
                Divider()
                    .frame(height: 30)
                
                costSummaryItem(
                    icon: "shippingbox.fill",
                    label: "Materials",
                    value: "$\(Int(prediction.breakdown.materials.total))"
                )
                
                Divider()
                    .frame(height: 30)
                
                costSummaryItem(
                    icon: "clock.fill",
                    label: "Time",
                    value: "\(String(format: "%.1f", prediction.breakdown.labor.hours))h"
                )
            }
            .padding(.top, 8)
        }
        .padding(20)
    }
    
    private func savingsBanner(_ savings: SavingsAnalysis) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.title3)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(savings.displaySavings)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("vs typical market price")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var detailedBreakdown: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 16) {
                // Materials breakdown
                breakdownSection(
                    title: "Materials",
                    icon: "shippingbox.fill",
                    color: .blue
                ) {
                    ForEach(prediction.breakdown.materials.items) { item in
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundColor(KMTheme.primaryText)
                            Spacer()
                            Text(item.displayString)
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                        }
                    }
                    
                    if prediction.breakdown.materials.shipping > 0 {
                        HStack {
                            Text("Shipping")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.primaryText)
                            Spacer()
                            Text("$\(Int(prediction.breakdown.materials.shipping))")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                        }
                    }
                    
                    HStack {
                        Text("Tax")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text("$\(Int(prediction.breakdown.materials.tax))")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Materials Total")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text("$\(Int(prediction.breakdown.materials.total))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(KMTheme.accent)
                    }
                }
                
                // Labor breakdown
                breakdownSection(
                    title: "Labor",
                    icon: "hammer.fill",
                    color: .orange
                ) {
                    HStack {
                        Text("Skill Level")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text(prediction.breakdown.labor.skillLevel.rawValue)
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    HStack {
                        Text("Hours")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text("\(String(format: "%.1f", prediction.breakdown.labor.hours))h × $\(Int(prediction.breakdown.labor.hourlyRate))/hr")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    HStack {
                        Text("Workers")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text("\(prediction.breakdown.labor.numberOfWorkers)")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    if let travelTime = prediction.breakdown.labor.travelTime, travelTime > 0 {
                        HStack {
                            Text("Travel Time")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.primaryText)
                            Spacer()
                            Text("$\(Int(prediction.breakdown.labor.travelCost))")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Labor Total")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text("$\(Int(prediction.breakdown.labor.total))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(KMTheme.accent)
                    }
                }
                
                // Additional costs
                if prediction.breakdown.permits != nil || prediction.breakdown.disposal != nil || prediction.breakdown.emergency != nil {
                    breakdownSection(
                        title: "Additional Costs",
                        icon: "doc.text.fill",
                        color: .purple
                    ) {
                        if let permits = prediction.breakdown.permits {
                            HStack {
                                Text("Permits")
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.primaryText)
                                Spacer()
                                Text("$\(Int(permits))")
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.secondaryText)
                            }
                        }
                        
                        if let disposal = prediction.breakdown.disposal {
                            HStack {
                                Text("Disposal")
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.primaryText)
                                Spacer()
                                Text("$\(Int(disposal))")
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.secondaryText)
                            }
                        }
                        
                        if let emergency = prediction.breakdown.emergency {
                            HStack {
                                Text("Emergency Fee")
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.primaryText)
                                Spacer()
                                Text("$\(Int(emergency))")
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.secondaryText)
                            }
                        }
                    }
                }
                
                // Kevin's service fee
                breakdownSection(
                    title: "Kevin Service Fee",
                    icon: "star.fill",
                    color: KMTheme.accent
                ) {
                    HStack {
                        Text("Coordination & Management")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.primaryText)
                        Spacer()
                        Text("$\(Int(prediction.breakdown.markup))")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    Text("Includes contractor vetting, scheduling, quality assurance, and warranty")
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                        .padding(.top, 4)
                }
                
                // Regional info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(KMTheme.accent)
                        Text("Regional Pricing")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    Text("\(prediction.regionalFactors.location) • Cost of Living Index: \(String(format: "%.2f", prediction.regionalFactors.costOfLivingIndex))")
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
    
    private var toggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingBreakdown.toggle()
            }
        }) {
            HStack {
                Text(showingBreakdown ? "Hide Breakdown" : "Show Detailed Breakdown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.accent)
                
                Image(systemName: showingBreakdown ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(KMTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(KMTheme.accent.opacity(0.1))
        }
    }
    
    private func costSummaryItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(KMTheme.accent)
            
            Text(label)
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func breakdownSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.leading, 24)
        }
    }
    
    private var confidenceColor: Color {
        if prediction.confidenceScore >= 0.8 {
            return .green
        } else if prediction.confidenceScore >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

struct CostPredictionCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                CostPredictionCard(prediction: samplePrediction)
                    .padding()
            }
        }
        .background(KMTheme.background)
    }
    
    static var samplePrediction: CostPrediction {
        CostPrediction(
            estimatedCost: PredictedCostRange(low: 250, high: 400, mostLikely: 325),
            breakdown: DetailedCostBreakdown(
                materials: MaterialsCost(
                    items: [
                        MaterialItem(
                            id: "1",
                            name: "Drywall Sheet (4x8)",
                            quantity: 2,
                            unit: "sheets",
                            unitPrice: 15,
                            supplier: "Home Depot"
                        ),
                        MaterialItem(
                            id: "2",
                            name: "Joint Compound",
                            quantity: 1,
                            unit: "bucket",
                            unitPrice: 18,
                            supplier: "Home Depot"
                        )
                    ],
                    shipping: 0,
                    tax: 4.16
                ),
                labor: LaborCost(
                    hours: 3.5,
                    hourlyRate: 65,
                    skillLevel: .journeyman,
                    numberOfWorkers: 1,
                    travelTime: 0.5
                ),
                permits: nil,
                disposal: 75,
                emergency: nil,
                markup: 45
            ),
            regionalFactors: RegionalFactors(
                location: "Davidson, NC",
                state: "NC",
                costOfLivingIndex: 1.05,
                laborRateMultiplier: 1.05,
                materialAvailability: .normal,
                permitRequirements: nil
            ),
            confidenceScore: 0.85,
            savingsOpportunity: SavingsAnalysis(
                typicalMarketPrice: PredictedCostRange(low: 350, high: 560, mostLikely: 455),
                kevinPrice: PredictedCostRange(low: 250, high: 400, mostLikely: 325),
                estimatedSavings: 130,
                savingsPercentage: 28.6,
                comparisonNote: "Kevin coordinates directly with contractors"
            ),
            urgencyMultiplier: 1.0,
            timestamp: Date()
        )
    }
}
