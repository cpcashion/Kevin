#!/usr/bin/env swift

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// Simple script to list all businesses in Firebase
// This uses the existing FirebaseClient logic

struct Business {
    let id: String
    let name: String
    let businessType: String
    let address: String?
    let phone: String?
    let website: String?
    let ownerId: String
    let isActive: Bool
    let verificationStatus: String
    let createdAt: Date
}

class BusinessLister {
    private let db = Firestore.firestore()
    
    func listAllBusinesses() async throws -> [Business] {
        print("🔍 Querying Firebase for all businesses...")
        
        // Query both restaurants and businesses collections
        let restaurantsSnap = try await db.collection("restaurants")
            .order(by: "name", descending: false)
            .getDocuments()
        
        let businessesSnap = try await db.collection("businesses")
            .order(by: "name", descending: false)
            .getDocuments()
        
        var allBusinesses: [Business] = []
        
        print("📊 Found \(restaurantsSnap.documents.count) restaurants and \(businessesSnap.documents.count) businesses")
        
        // Process restaurants collection
        for doc in restaurantsSnap.documents {
            let data = doc.data()
            guard let name = data["name"] as? String else { continue }
            
            let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
            
            let business = Business(
                id: doc.documentID,
                name: name,
                businessType: "restaurant",
                address: data["address"] as? String,
                phone: data["phone"] as? String,
                website: data["website"] as? String,
                ownerId: data["ownerId"] as? String ?? "",
                isActive: data["isActive"] as? Bool ?? true,
                verificationStatus: data["verificationStatus"] as? String ?? "pending",
                createdAt: createdAtTimestamp.dateValue()
            )
            allBusinesses.append(business)
        }
        
        // Process businesses collection
        for doc in businessesSnap.documents {
            let data = doc.data()
            guard let name = data["name"] as? String else { continue }
            
            let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
            let businessType = data["businessType"] as? String ?? "other"
            
            let business = Business(
                id: doc.documentID,
                name: name,
                businessType: businessType,
                address: data["address"] as? String,
                phone: data["phone"] as? String,
                website: data["website"] as? String,
                ownerId: data["ownerId"] as? String ?? "",
                isActive: data["isActive"] as? Bool ?? true,
                verificationStatus: data["verificationStatus"] as? String ?? "pending",
                createdAt: createdAtTimestamp.dateValue()
            )
            allBusinesses.append(business)
        }
        
        return allBusinesses.sorted { $0.name < $1.name }
    }
    
    func printBusinessList(_ businesses: [Business]) {
        print("\n" + "="*80)
        print("📋 ALL BUSINESSES IN FIREBASE DATABASE")
        print("="*80)
        print("Total: \(businesses.count) businesses\n")
        
        for (index, business) in businesses.enumerated() {
            print("[\(index + 1)] \(business.name)")
            print("    Type: \(business.businessType.capitalized)")
            print("    ID: \(business.id)")
            if let address = business.address {
                print("    Address: \(address)")
            }
            if let phone = business.phone {
                print("    Phone: \(phone)")
            }
            if let website = business.website {
                print("    Website: \(website)")
            }
            print("    Owner ID: \(business.ownerId)")
            print("    Status: \(business.isActive ? "Active" : "Inactive")")
            print("    Verification: \(business.verificationStatus.capitalized)")
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            print("    Created: \(formatter.string(from: business.createdAt))")
            print("")
        }
        
        print("="*80)
        print("Summary by Type:")
        let groupedByType = Dictionary(grouping: businesses) { $0.businessType }
        for (type, businesses) in groupedByType.sorted(by: { $0.key < $1.key }) {
            print("  \(type.capitalized): \(businesses.count)")
        }
        
        print("\nSummary by Status:")
        let activeCount = businesses.filter { $0.isActive }.count
        let inactiveCount = businesses.count - activeCount
        print("  Active: \(activeCount)")
        print("  Inactive: \(inactiveCount)")
        
        print("\nSummary by Verification:")
        let verificationGroups = Dictionary(grouping: businesses) { $0.verificationStatus }
        for (status, businesses) in verificationGroups.sorted(by: { $0.key < $1.key }) {
            print("  \(status.capitalized): \(businesses.count)")
        }
        print("="*80)
    }
}

// Main execution
Task {
    do {
        let lister = BusinessLister()
        let businesses = try await lister.listAllBusinesses()
        lister.printBusinessList(businesses)
    } catch {
        print("❌ Error listing businesses: \(error)")
        print("Error details: \(error.localizedDescription)")
    }
}

// Keep the script running
RunLoop.main.run()
