import Foundation

// Simple script to query Firebase using the Firebase CLI
// This will use the Firebase Admin SDK to query the database directly

print("🔍 Querying Firebase for all businesses...")
print("📋 Listing all businesses in the Kevin Maint database:")
print("")

// Use Firebase CLI to query the database
let task = Process()
task.launchPath = "/usr/bin/env"
task.arguments = ["firebase", "firestore:query", "restaurants", "--project", "kevin-maint"]

let pipe = Pipe()
task.standardOutput = pipe
task.standardError = pipe

do {
    try task.run()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print("Restaurants Collection:")
        print(output)
    }
} catch {
    print("❌ Error running Firebase CLI: \(error)")
}

// Query businesses collection too
let businessTask = Process()
businessTask.launchPath = "/usr/bin/env"
businessTask.arguments = ["firebase", "firestore:query", "businesses", "--project", "kevin-maint"]

let businessPipe = Pipe()
businessTask.standardOutput = businessPipe
businessTask.standardError = businessPipe

do {
    try businessTask.run()
    businessTask.waitUntilExit()
    
    let data = businessPipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print("\nBusinesses Collection:")
        print(output)
    }
} catch {
    print("❌ Error running Firebase CLI for businesses: \(error)")
}
