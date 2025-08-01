import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirebasePermissionTest {
  static let shared = FirebasePermissionTest()
  
  func testIssueUpdatePermissions() async {
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [PermissionTest] No authenticated user")
      return
    }
    
    print("🧪 [PermissionTest] Testing Firebase permissions...")
    print("🧪 [PermissionTest] User: \(currentUser.uid)")
    print("🧪 [PermissionTest] Email: \(currentUser.email ?? "no email")")
    
    // Create a test document
    let testIssueId = "permission-test-\(UUID().uuidString)"
    let testData: [String: Any] = [
      "id": testIssueId,
      "restaurantId": "test-restaurant",
      "locationId": "test-location", 
      "reporterId": currentUser.uid,
      "title": "Permission Test Issue",
      "description": "Testing Firebase permissions",
      "type": "test",
      "priority": "low",
      "status": "reported",
      "createdAt": Timestamp(date: Date()),
      "updatedAt": Timestamp(date: Date())
    ]
    
    do {
      // Test create
      print("🧪 [PermissionTest] Testing CREATE permission...")
      try await Firestore.firestore().collection("issues").document(testIssueId).setData(testData)
      print("✅ [PermissionTest] CREATE successful")
      
      // Test update
      print("🧪 [PermissionTest] Testing UPDATE permission...")
      try await Firestore.firestore().collection("issues").document(testIssueId).updateData([
        "status": "completed",
        "updatedAt": Timestamp(date: Date())
      ])
      print("✅ [PermissionTest] UPDATE successful")
      
      // Test delete (cleanup)
      print("🧪 [PermissionTest] Cleaning up test document...")
      try await Firestore.firestore().collection("issues").document(testIssueId).delete()
      print("✅ [PermissionTest] DELETE successful")
      
      print("🎉 [PermissionTest] All permission tests PASSED!")
      
    } catch {
      print("❌ [PermissionTest] Permission test FAILED: \(error)")
      print("❌ [PermissionTest] Error code: \((error as NSError).code)")
      print("❌ [PermissionTest] Error domain: \((error as NSError).domain)")
    }
  }
  
  func testProblematicDocument() async {
    let problematicId = "D8E494C1-622E-43FE-A105-E461086DDCAC"
    
    print("🧪 [PermissionTest] Testing problematic document: \(problematicId)")
    
    do {
      // Try to read the document first
      let docRef = Firestore.firestore().collection("issues").document(problematicId)
      let document = try await docRef.getDocument()
      
      if document.exists {
        print("✅ [PermissionTest] Document exists and is readable")
        print("🔍 [PermissionTest] Document data: \(document.data() ?? [:])")
        
        // Try to update it
        try await docRef.updateData([
          "updatedAt": Timestamp(date: Date()),
          "testUpdate": true
        ])
        print("✅ [PermissionTest] Document update successful")
        
      } else {
        print("❌ [PermissionTest] Document does not exist")
      }
      
    } catch {
      print("❌ [PermissionTest] Failed to access problematic document: \(error)")
      print("❌ [PermissionTest] Error code: \((error as NSError).code)")
      print("❌ [PermissionTest] Error domain: \((error as NSError).domain)")
    }
  }
}
