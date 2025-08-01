import Foundation
import CoreLocation

// MARK: - Cost Prediction Models

struct CostPrediction: Codable {
    let estimatedCost: PredictedCostRange
    let breakdown: DetailedCostBreakdown
    let regionalFactors: RegionalFactors
    let confidenceScore: Double // 0.0 to 1.0
    let savingsOpportunity: SavingsAnalysis?
    let urgencyMultiplier: Double
    let timestamp: Date
    
    var displayRange: String {
        "$\(Int(estimatedCost.low)) - $\(Int(estimatedCost.high))"
    }
    
    var mostLikelyCost: Double {
        estimatedCost.mostLikely
    }
}

struct PredictedCostRange: Codable {
    let low: Double
    let high: Double
    let mostLikely: Double
}

struct DetailedCostBreakdown: Codable {
    let materials: MaterialsCost
    let labor: LaborCost
    let permits: Double?
    let disposal: Double?
    let emergency: Double?
    let markup: Double // Kevin's service fee
    
    var total: Double {
        materials.total + labor.total + (permits ?? 0) + (disposal ?? 0) + (emergency ?? 0) + markup
    }
}

struct MaterialsCost: Codable {
    let items: [MaterialItem]
    let shipping: Double
    let tax: Double
    
    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalCost }
    }
    
    var total: Double {
        subtotal + shipping + tax
    }
}

struct MaterialItem: Codable, Identifiable {
    let id: String
    let name: String
    let quantity: Double
    let unit: String
    let unitPrice: Double
    let supplier: String?
    
    var totalCost: Double {
        quantity * unitPrice
    }
    
    var displayString: String {
        "\(quantity) \(unit) × $\(Int(unitPrice)) = $\(Int(totalCost))"
    }
}

struct LaborCost: Codable {
    let hours: Double
    let hourlyRate: Double
    let skillLevel: SkillLevel
    let numberOfWorkers: Int
    let travelTime: Double?
    
    var subtotal: Double {
        hours * hourlyRate * Double(numberOfWorkers)
    }
    
    var travelCost: Double {
        (travelTime ?? 0) * hourlyRate
    }
    
    var total: Double {
        subtotal + travelCost
    }
    
    enum SkillLevel: String, Codable {
        case apprentice = "Apprentice"
        case journeyman = "Journeyman"
        case master = "Master"
        case specialist = "Specialist"
    }
}

struct RegionalFactors: Codable {
    let location: String
    let state: String
    let costOfLivingIndex: Double // 1.0 = national average
    let laborRateMultiplier: Double
    let materialAvailability: MaterialAvailability
    let permitRequirements: [String]?
    
    enum MaterialAvailability: String, Codable {
        case abundant = "Abundant"
        case normal = "Normal"
        case limited = "Limited"
        case scarce = "Scarce"
    }
}

struct SavingsAnalysis: Codable {
    let typicalMarketPrice: PredictedCostRange
    let kevinPrice: PredictedCostRange
    let estimatedSavings: Double
    let savingsPercentage: Double
    let comparisonNote: String
    
    var displaySavings: String {
        "Save $\(Int(estimatedSavings)) (\(Int(savingsPercentage))%)"
    }
}

// MARK: - Regional Pricing Database

struct RegionalPricingData {
    let state: String
    let city: String
    let laborRates: LaborRates
    let materialMultipliers: MaterialMultipliers
    let costOfLivingIndex: Double
    let permitCosts: PermitCosts
}

struct LaborRates {
    let general: Double // General handyman
    let plumber: Double
    let electrician: Double
    let carpenter: Double
    let hvac: Double
    let painter: Double
    let drywall: Double
}

struct MaterialMultipliers {
    let lumber: Double
    let drywall: Double
    let paint: Double
    let plumbing: Double
    let electrical: Double
    let hvac: Double
}

struct PermitCosts {
    let electrical: Double?
    let plumbing: Double?
    let structural: Double?
    let general: Double?
}

// MARK: - Cost Prediction Service

class CostPredictionService {
    static let shared = CostPredictionService()
    private init() {}
    
    // Regional pricing database (in production, this would be from an API/database)
    private let regionalData: [String: RegionalPricingData] = [
        "Seattle, WA": RegionalPricingData(
            state: "WA",
            city: "Seattle",
            laborRates: LaborRates(
                general: 85,
                plumber: 125,
                electrician: 110,
                carpenter: 95,
                hvac: 130,
                painter: 65,
                drywall: 75
            ),
            materialMultipliers: MaterialMultipliers(
                lumber: 1.3,
                drywall: 1.2,
                paint: 1.15,
                plumbing: 1.1,
                electrical: 1.1,
                hvac: 1.2
            ),
            costOfLivingIndex: 1.72,
            permitCosts: PermitCosts(
                electrical: 150,
                plumbing: 125,
                structural: 300,
                general: 75
            )
        ),
        "Charlotte, NC": RegionalPricingData(
            state: "NC",
            city: "Charlotte",
            laborRates: LaborRates(
                general: 55,
                plumber: 85,
                electrician: 75,
                carpenter: 65,
                hvac: 90,
                painter: 45,
                drywall: 50
            ),
            materialMultipliers: MaterialMultipliers(
                lumber: 0.95,
                drywall: 0.9,
                paint: 0.95,
                plumbing: 1.0,
                electrical: 1.0,
                hvac: 1.0
            ),
            costOfLivingIndex: 0.97,
            permitCosts: PermitCosts(
                electrical: 75,
                plumbing: 65,
                structural: 150,
                general: 50
            )
        ),
        "Davidson, NC": RegionalPricingData(
            state: "NC",
            city: "Davidson",
            laborRates: LaborRates(
                general: 60,
                plumber: 90,
                electrician: 80,
                carpenter: 70,
                hvac: 95,
                painter: 50,
                drywall: 55
            ),
            materialMultipliers: MaterialMultipliers(
                lumber: 0.95,
                drywall: 0.9,
                paint: 0.95,
                plumbing: 1.0,
                electrical: 1.0,
                hvac: 1.0
            ),
            costOfLivingIndex: 1.05,
            permitCosts: PermitCosts(
                electrical: 75,
                plumbing: 65,
                structural: 150,
                general: 50
            )
        )
    ]
    
    // MARK: - Main Cost Prediction
    
    func predictCost(
        for analysis: ImageAnalysisResult,
        location: CLLocationCoordinate2D?,
        urgency: IssuePriority
    ) async throws -> CostPrediction {
        
        print("💰 [CostPrediction] Starting cost analysis...")
        print("   Issue: \(analysis.summary)")
        print("   Category: \(analysis.category)")
        print("   Priority: \(urgency.rawValue)")
        
        // 1. Get regional data
        let regionalFactors = await getRegionalFactors(for: location)
        print("   Location: \(regionalFactors.location)")
        print("   Cost of Living Index: \(regionalFactors.costOfLivingIndex)")
        
        // 2. Calculate materials cost
        let materials = calculateMaterialsCost(
            for: analysis,
            regionalFactors: regionalFactors
        )
        print("   Materials: $\(Int(materials.total))")
        
        // 3. Calculate labor cost
        let labor = calculateLaborCost(
            for: analysis,
            regionalFactors: regionalFactors
        )
        print("   Labor: $\(Int(labor.total))")
        
        // 4. Calculate permits if needed
        let permits = calculatePermitCosts(
            for: analysis,
            regionalFactors: regionalFactors
        )
        if let permitCost = permits {
            print("   Permits: $\(Int(permitCost))")
        }
        
        // 5. Calculate disposal costs
        let disposal = calculateDisposalCosts(for: analysis)
        
        // 6. Apply urgency multiplier
        let urgencyMultiplier = getUrgencyMultiplier(urgency)
        let emergencyCost = urgency == .high ? 150.0 : nil  // Changed from .critical
        
        // 7. Calculate Kevin's markup (15%)
        let subtotal = materials.total + labor.total + (permits ?? 0) + (disposal ?? 0)
        let markup = subtotal * 0.15
        
        // 8. Create breakdown
        let breakdown = DetailedCostBreakdown(
            materials: materials,
            labor: labor,
            permits: permits,
            disposal: disposal,
            emergency: emergencyCost,
            markup: markup
        )
        
        // 9. Calculate cost range with confidence
        let baseCost = breakdown.total
        let costRange = PredictedCostRange(
            low: baseCost * 0.85,
            high: baseCost * 1.25,
            mostLikely: baseCost
        )
        
        // 10. Calculate savings vs market
        let savings = calculateSavings(
            kevinCost: costRange,
            category: analysis.category ?? "Other",
            regionalFactors: regionalFactors
        )
        
        // 11. Determine confidence score
        let confidence = calculateConfidenceScore(
            analysis: analysis,
            hasLocation: location != nil
        )
        
        let prediction = CostPrediction(
            estimatedCost: costRange,
            breakdown: breakdown,
            regionalFactors: regionalFactors,
            confidenceScore: confidence,
            savingsOpportunity: savings,
            urgencyMultiplier: urgencyMultiplier,
            timestamp: Date()
        )
        
        print("💰 [CostPrediction] Complete!")
        print("   Range: \(prediction.displayRange)")
        print("   Most Likely: $\(Int(prediction.mostLikelyCost))")
        print("   Confidence: \(Int(confidence * 100))%")
        if let savingsData = prediction.savingsOpportunity {
            print("   Savings: \(savingsData.displaySavings)")
        }
        
        return prediction
    }
    
    // MARK: - Regional Factors
    
    private func getRegionalFactors(for location: CLLocationCoordinate2D?) async -> RegionalFactors {
        // In production, use reverse geocoding to get city/state
        // For now, use default or lookup from known locations
        
        guard let location = location else {
            // Default to national average
            return RegionalFactors(
                location: "United States",
                state: "US",
                costOfLivingIndex: 1.0,
                laborRateMultiplier: 1.0,
                materialAvailability: .normal,
                permitRequirements: nil
            )
        }
        
        // Simple distance-based lookup (in production, use proper geocoding)
        let seattleLocation = CLLocation(latitude: 47.6062, longitude: -122.3321)
        let charlotteLocation = CLLocation(latitude: 35.2271, longitude: -80.8431)
        let davidsonLocation = CLLocation(latitude: 35.4993, longitude: -80.8487)
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        let distanceToSeattle = userLocation.distance(from: seattleLocation)
        let distanceToCharlotte = userLocation.distance(from: charlotteLocation)
        let distanceToDavidson = userLocation.distance(from: davidsonLocation)
        
        let minDistance = min(distanceToSeattle, distanceToCharlotte, distanceToDavidson)
        
        let cityKey: String
        if minDistance == distanceToSeattle {
            cityKey = "Seattle, WA"
        } else if minDistance == distanceToDavidson {
            cityKey = "Davidson, NC"
        } else {
            cityKey = "Charlotte, NC"
        }
        
        guard let data = regionalData[cityKey] else {
            return RegionalFactors(
                location: "United States",
                state: "US",
                costOfLivingIndex: 1.0,
                laborRateMultiplier: 1.0,
                materialAvailability: .normal,
                permitRequirements: nil
            )
        }
        
        return RegionalFactors(
            location: cityKey,
            state: data.state,
            costOfLivingIndex: data.costOfLivingIndex,
            laborRateMultiplier: data.costOfLivingIndex,
            materialAvailability: .normal,
            permitRequirements: []
        )
    }
    
    // MARK: - Materials Cost Calculation
    
    private func calculateMaterialsCost(
        for analysis: ImageAnalysisResult,
        regionalFactors: RegionalFactors
    ) -> MaterialsCost {
        
        var items: [MaterialItem] = []
        
        // Parse materials from AI analysis
        let materialsString = (analysis.materials ?? []).joined(separator: ", ").lowercased()
        
        // Drywall repairs
        if materialsString.contains("drywall") || materialsString.contains("sheetrock") {
            let multiplier = getRegionalMultiplier(for: "drywall", factors: regionalFactors)
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Drywall Sheet (4x8)",
                quantity: 2,
                unit: "sheets",
                unitPrice: 15 * multiplier,
                supplier: "Local Supplier"
            ))
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Joint Compound",
                quantity: 1,
                unit: "bucket",
                unitPrice: 18 * multiplier,
                supplier: "Local Supplier"
            ))
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Drywall Screws",
                quantity: 1,
                unit: "box",
                unitPrice: 8 * multiplier,
                supplier: "Local Supplier"
            ))
        }
        
        // Paint
        if materialsString.contains("paint") {
            let multiplier = getRegionalMultiplier(for: "paint", factors: regionalFactors)
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Interior Paint",
                quantity: 2,
                unit: "gallons",
                unitPrice: 45 * multiplier,
                supplier: "Sherwin-Williams"
            ))
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Primer",
                quantity: 1,
                unit: "gallon",
                unitPrice: 35 * multiplier,
                supplier: "Sherwin-Williams"
            ))
        }
        
        // Plumbing
        if materialsString.contains("pipe") || materialsString.contains("plumbing") {
            let multiplier = getRegionalMultiplier(for: "plumbing", factors: regionalFactors)
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "PVC Pipe",
                quantity: 10,
                unit: "feet",
                unitPrice: 3.5 * multiplier,
                supplier: "Local Supplier"
            ))
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Fittings & Connectors",
                quantity: 1,
                unit: "set",
                unitPrice: 25 * multiplier,
                supplier: "Local Supplier"
            ))
        }
        
        // Electrical
        if materialsString.contains("wire") || materialsString.contains("electrical") || materialsString.contains("outlet") {
            let multiplier = getRegionalMultiplier(for: "electrical", factors: regionalFactors)
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Electrical Wire",
                quantity: 50.0,
                unit: "feet",
                unitPrice: 0.85 * multiplier,
                supplier: "Local Supplier"
            ))
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "Outlet/Switch",
                quantity: 2.0,
                unit: "units",
                unitPrice: 8 * multiplier,
                supplier: "Local Supplier"
            ))
        }
        
        // Default materials if nothing specific detected
        if items.isEmpty {
            items.append(MaterialItem(
                id: UUID().uuidString,
                name: "General Repair Materials",
                quantity: 1,
                unit: "set",
                unitPrice: 75,
                supplier: "Local Supplier"
            ))
        }
        
        let subtotal = items.reduce(0) { $0 + $1.totalCost }
        let shipping: Double = subtotal > 200 ? 0.0 : 25.0
        let tax = subtotal * 0.08 // 8% sales tax
        
        return MaterialsCost(
            items: items,
            shipping: shipping,
            tax: tax
        )
    }
    
    // MARK: - Labor Cost Calculation
    
    private func calculateLaborCost(
        for analysis: ImageAnalysisResult,
        regionalFactors: RegionalFactors
    ) -> LaborCost {
        
        // Determine trade and skill level
        let (trade, skillLevel) = determineTradeAndSkill(for: analysis)
        
        // Get regional hourly rate
        let baseRate = getRegionalLaborRate(for: trade, location: regionalFactors.location)
        let adjustedRate = baseRate * regionalFactors.laborRateMultiplier
        
        // Estimate hours based on complexity
        let hours = estimateRepairHours(for: analysis)
        
        // Determine number of workers
        let workers = hours > 8 ? 2 : 1
        
        return LaborCost(
            hours: hours,
            hourlyRate: adjustedRate,
            skillLevel: skillLevel,
            numberOfWorkers: workers,
            travelTime: 0.5 // 30 minutes travel time
        )
    }
    
    private func determineTradeAndSkill(for analysis: ImageAnalysisResult) -> (String, LaborCost.SkillLevel) {
        let category = (analysis.category ?? "").lowercased()
        
        if category.contains("electrical") {
            return ("electrician", .journeyman)
        } else if category.contains("plumbing") {
            return ("plumber", .journeyman)
        } else if category.contains("hvac") {
            return ("hvac", .master)
        } else if category.contains("drywall") || category.contains("wall") {
            return ("drywall", .journeyman)
        } else if category.contains("paint") {
            return ("painter", .apprentice)
        } else if category.contains("door") || category.contains("window") {
            return ("carpenter", .journeyman)
        } else {
            return ("general", .journeyman)
        }
    }
    
    private func getRegionalLaborRate(for trade: String, location: String) -> Double {
        guard let data = regionalData[location] else {
            return 75.0 // National average
        }
        
        switch trade {
        case "plumber": return data.laborRates.plumber
        case "electrician": return data.laborRates.electrician
        case "carpenter": return data.laborRates.carpenter
        case "hvac": return data.laborRates.hvac
        case "painter": return data.laborRates.painter
        case "drywall": return data.laborRates.drywall
        default: return data.laborRates.general
        }
    }
    
    private func estimateRepairHours(for analysis: ImageAnalysisResult) -> Double {
        // Parse estimated time from AI analysis
        let timeString = analysis.estimatedTime.lowercased()
        
        if timeString.contains("1-2 hours") || timeString.contains("1 to 2") {
            return 1.5
        } else if timeString.contains("2-3 hours") || timeString.contains("2 to 3") {
            return 2.5
        } else if timeString.contains("3-4 hours") || timeString.contains("3 to 4") {
            return 3.5
        } else if timeString.contains("4-6 hours") || timeString.contains("4 to 6") {
            return 5.0
        } else if timeString.contains("6-8 hours") || timeString.contains("6 to 8") || timeString.contains("full day") {
            return 7.0
        } else if timeString.contains("2 days") || timeString.contains("two days") {
            return 14.0
        } else {
            // Default estimate based on category
            return 3.0
        }
    }
    
    // MARK: - Additional Costs
    
    private func calculatePermitCosts(
        for analysis: ImageAnalysisResult,
        regionalFactors: RegionalFactors
    ) -> Double? {
        let category = (analysis.category ?? "").lowercased()
        
        guard let data = regionalData[regionalFactors.location] else {
            return nil
        }
        
        if category.contains("electrical") {
            return data.permitCosts.electrical
        } else if category.contains("plumbing") {
            return data.permitCosts.plumbing
        } else if category.contains("structural") {
            return data.permitCosts.structural
        }
        
        return nil
    }
    
    private func calculateDisposalCosts(for analysis: ImageAnalysisResult) -> Double? {
        let materialsString = (analysis.materials ?? []).joined(separator: ", ").lowercased()
        
        if materialsString.contains("drywall") || materialsString.contains("demolition") {
            return 75.0 // Dumpster/disposal fee
        }
        
        return nil
    }
    
    private func getUrgencyMultiplier(_ priority: IssuePriority) -> Double {
        switch priority {
        case .low: return 1.0
        case .medium: return 1.0
        case .high: return 1.35 // Emergency rates (was 1.15, increased since critical removed)
        }
    }
    
    // MARK: - Savings Calculation
    
    private func calculateSavings(
        kevinCost: PredictedCostRange,
        category: String,
        regionalFactors: RegionalFactors
    ) -> SavingsAnalysis {
        
        // Typical market markup is 30-50% higher than Kevin's coordinated pricing
        let marketMultiplier = 1.40
        
        let marketCost = PredictedCostRange(
            low: kevinCost.low * marketMultiplier,
            high: kevinCost.high * marketMultiplier,
            mostLikely: kevinCost.mostLikely * marketMultiplier
        )
        
        let savings = marketCost.mostLikely - kevinCost.mostLikely
        let savingsPercent = (savings / marketCost.mostLikely) * 100
        
        return SavingsAnalysis(
            typicalMarketPrice: marketCost,
            kevinPrice: kevinCost,
            estimatedSavings: savings,
            savingsPercentage: savingsPercent,
            comparisonNote: "Kevin coordinates directly with contractors, eliminating middleman markups"
        )
    }
    
    // MARK: - Confidence Score
    
    private func calculateConfidenceScore(
        analysis: ImageAnalysisResult,
        hasLocation: Bool
    ) -> Double {
        var confidence = 0.7 // Base confidence
        
        // Increase confidence if we have detailed materials list
        if (analysis.materials ?? []).count > 2 {
            confidence += 0.1
        }
        
        // Increase confidence if we have specific time estimate
        if (analysis.timeToComplete ?? "").contains("hours") {
            confidence += 0.1
        }
        
        // Increase confidence if we have location data
        if hasLocation {
            confidence += 0.1
        }
        
        return min(confidence, 0.95) // Cap at 95%
    }
    
    // MARK: - Helper Methods
    
    private func getRegionalMultiplier(for material: String, factors: RegionalFactors) -> Double {
        guard let data = regionalData[factors.location] else {
            return 1.0
        }
        
        switch material {
        case "lumber": return data.materialMultipliers.lumber
        case "drywall": return data.materialMultipliers.drywall
        case "paint": return data.materialMultipliers.paint
        case "plumbing": return data.materialMultipliers.plumbing
        case "electrical": return data.materialMultipliers.electrical
        case "hvac": return data.materialMultipliers.hvac
        default: return 1.0
        }
    }
}
