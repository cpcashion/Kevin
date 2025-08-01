import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine

final class FirebaseClient: ObservableObject {
  static let shared = FirebaseClient()
  
  private let db = Firestore.firestore()
  private let storage = Storage.storage()
  
  init() {
    print("🔥 [FirebaseClient] Initializing Firebase client...")
    
    // Print current auth state
    if let currentUser = Auth.auth().currentUser {
      print("🔥 [FirebaseClient] Current Firebase Auth user: \(currentUser.uid)")
      print("🔥 [FirebaseClient] User email: \(currentUser.email ?? "No email")")
      print("🔥 [FirebaseClient] User verified: \(currentUser.isEmailVerified)")
      print("🔥 [FirebaseClient] User anonymous: \(currentUser.isAnonymous)")
    } else {
      print("🔥 [FirebaseClient] No authenticated user")
    }
  }
  
  // Helper function to safely create document references
  private func safeDocumentReference(collection: String, documentId: String) throws -> DocumentReference {
    guard !documentId.isEmpty else {
      let error = NSError(domain: "FirebaseClient", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Document ID cannot be empty for collection '\(collection)'"
      ])
      print("❌ [FirebaseClient] \(error.localizedDescription)")
      throw error
    }
    return db.collection(collection).document(documentId)
  }

  // MARK: - Issues
  func createIssue(_ issue: Issue, images: [UIImage], restaurantName: String? = nil) async throws {
    print("📝 [FirebaseClient] ===== CREATE ISSUE STARTED =====")
    print("📝 [FirebaseClient] Issue ID: \(issue.id)")
    print("📝 [FirebaseClient] Restaurant ID: \(issue.restaurantId)")
    print("📝 [FirebaseClient] Reporter ID: \(issue.reporterId)")
    print("📝 [FirebaseClient] Title: \(issue.title)")
    
    // Track network request performance
    let networkTraceId = PerformanceMonitoringService.shared.trackNetworkRequest(
      url: "firestore://issues/\(issue.id)",
      method: "CREATE"
    )
    
    // Check Firebase Auth state
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [FirebaseClient] No authenticated user for issue creation")
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated. Please sign in again."
      ])
    }
    
    print("✅ [FirebaseClient] Authenticated user: \(currentUser.uid)")
    
    // Validate that images exist - every issue must have at least one photo
    guard !images.isEmpty else {
      print("❌ [FirebaseClient] No images provided for issue creation")
      throw NSError(domain: "FirebaseClient", code: 1001, userInfo: [
        NSLocalizedDescriptionKey: "Cannot create issue without photos. Every issue requires at least one photo."
      ])
    }
    
    print("📝 [FirebaseClient] Creating issue with \(images.count) photos")
    
    // ATOMIC OPERATION: Upload photos FIRST, then create issue document
    // This ensures we never have issues without photos
    
    var uploadedPhotoUrls: [String] = []
    var uploadedPhotoDocuments: [DocumentReference] = []
    
    do {
      // 1) Upload all images to Firebase Storage first
      print("📸 [FirebaseClient] Starting photo uploads...")
      for (idx, img) in images.enumerated() {
        guard let data = img.jpegData(compressionQuality: 0.8) else { 
          print("❌ [FirebaseClient] Failed to convert image \(idx) to JPEG data")
          throw NSError(domain: "FirebaseClient", code: 1002, userInfo: [
            NSLocalizedDescriptionKey: "Failed to process image \(idx). Please try again."
          ])
        }
        
        let path = "issue-photos/\(issue.id)/photo_\(idx).jpg"
        let ref = storage.reference().child(path)
        
        // Upload image to Storage
        _ = try await ref.putDataAsync(data, metadata: nil)
        let url = try await ref.downloadURL()
        uploadedPhotoUrls.append(url.absoluteString)
        
        // Create photo document in Firestore
        let photoDoc = db.collection("issuePhotos").document()
        try await photoDoc.setData([
          "id": photoDoc.documentID,
          "issueId": issue.id,
          "url": url.absoluteString,
          "thumbUrl": url.absoluteString,
          "uploaderId": currentUser.uid,
          "takenAt": Timestamp(date: Date())
        ])
        uploadedPhotoDocuments.append(photoDoc)
        
        print("✅ [FirebaseClient] Photo \(idx) uploaded successfully: \(url.absoluteString)")
      }
      
      print("✅ [FirebaseClient] All \(images.count) photos uploaded successfully")
      
      // 2) Create issue document with photo URLs - only after ALL photos are uploaded
      var issueData: [String: Any] = [
        "id": issue.id,
        "restaurantId": issue.restaurantId,
        "locationId": issue.locationId,
        "reporterId": issue.reporterId,
        "title": issue.title,
        "description": issue.description ?? "",
        "type": issue.type ?? "",
        "priority": issue.priority.rawValue,
        "status": issue.status.rawValue,
        "photoUrls": uploadedPhotoUrls, // Include photo URLs in issue document
        "createdAt": Timestamp(date: issue.createdAt),
        "updatedAt": Timestamp(date: issue.updatedAt),
        "archived": false
      ]
      
      // Add AI analysis if available
      if let aiAnalysis = issue.aiAnalysis {
        let analysisData = try JSONEncoder().encode(aiAnalysis)
        issueData["aiAnalysis"] = String(data: analysisData, encoding: .utf8)
      }
      
      // Add voice notes if available
      if let voiceNotes = issue.voiceNotes, !voiceNotes.isEmpty {
        issueData["voiceNotes"] = voiceNotes
      }
      
      let documentRef = try safeDocumentReference(collection: "issues", documentId: issue.id)
      try await documentRef.setData(issueData)
      print("✅ [FirebaseClient] Issue document created with \(uploadedPhotoUrls.count) photo URLs")
      
    } catch {
      print("❌ [FirebaseClient] Issue creation failed - performing cleanup")
      print("❌ [FirebaseClient] Error: \(error)")
      
      // ROLLBACK: Clean up any uploaded photos if issue creation failed
      await cleanupFailedIssueCreation(issueId: issue.id, photoDocuments: uploadedPhotoDocuments)
      
      // Track failed network request
      PerformanceMonitoringService.shared.completeNetworkRequest(networkTraceId, statusCode: 500)
      CrashReportingService.shared.recordNetworkError(error, url: "firestore://issues/\(issue.id)", method: "CREATE")
      
      throw error
    }
    
    print("✅ [FirebaseClient] Issue creation completed successfully with \(images.count) photos")
    
    // Complete network request tracking
    PerformanceMonitoringService.shared.completeNetworkRequest(networkTraceId, statusCode: 200)
    
    // 3) Send notification to admins about new issue
    Task {
      do {
        // Use provided restaurant name or try to look it up
        let finalRestaurantName: String
        if let providedName = restaurantName {
          finalRestaurantName = providedName
          print("📍 [FirebaseClient] Using provided restaurant name: \(providedName)")
        } else {
          // Fallback to Firebase lookup (for legacy restaurants)
          let restaurantDoc = try await safeDocumentReference(collection: "restaurants", documentId: issue.restaurantId).getDocument()
          finalRestaurantName = restaurantDoc.data()?["name"] as? String ?? "Unknown Restaurant"
          print("📍 [FirebaseClient] Looked up restaurant name: \(finalRestaurantName)")
        }
        
        // Send notification to admins
        await NotificationService.shared.sendIssueNotification(
          to: try await getAdminUserIds(),
          issueTitle: issue.title,
          restaurantName: finalRestaurantName,
          priority: issue.priority.rawValue,
          issueId: issue.id
        )
      } catch {
        print("⚠️ [FirebaseClient] Failed to send issue notification: \(error)")
      }
    }
  }
  
  // Helper function to get admin user IDs (reused from MessagingService)
  private func getAdminUserIds() async throws -> [String] {
    let usersQuery = db.collection("users").whereField("role", isEqualTo: Role.admin.rawValue)
    let snapshot = try await usersQuery.getDocuments()
    let adminIds = snapshot.documents.map { $0.documentID }
    
    // Return empty array if no admins found - don't use hardcoded fallbacks
    if adminIds.isEmpty {
      print("⚠️ [FirebaseClient] No admin users found in database")
      return []
    }
    return adminIds
  }
  
  // Helper function to clean up failed issue creation
  private func cleanupFailedIssueCreation(issueId: String, photoDocuments: [DocumentReference]) async {
    print("🧹 [FirebaseClient] Starting cleanup for failed issue creation: \(issueId)")
    
    // Clean up uploaded photo documents from Firestore
    for photoDoc in photoDocuments {
      do {
        try await photoDoc.delete()
        print("🗑️ [FirebaseClient] Deleted photo document: \(photoDoc.documentID)")
      } catch {
        print("⚠️ [FirebaseClient] Failed to delete photo document \(photoDoc.documentID): \(error)")
      }
    }
    
    // Clean up uploaded files from Firebase Storage
    do {
      let storageRef = storage.reference().child("issue-photos/\(issueId)")
      let listResult = try await storageRef.listAll()
      
      for item in listResult.items {
        do {
          try await item.delete()
          print("🗑️ [FirebaseClient] Deleted storage file: \(item.fullPath)")
        } catch {
          print("⚠️ [FirebaseClient] Failed to delete storage file \(item.fullPath): \(error)")
        }
      }
    } catch {
      print("⚠️ [FirebaseClient] Failed to list/delete storage files for issue \(issueId): \(error)")
    }
    
    print("✅ [FirebaseClient] Cleanup completed for issue: \(issueId)")
  }

  func fetchIssue(byId issueId: String) async throws -> Issue? {
    print("🔍 [fetchIssue] Fetching single issue: \(issueId)")
    let doc = try await db.collection("issues").document(issueId).getDocument()
    
    guard doc.exists, let data = doc.data() else {
      print("❌ [fetchIssue] Issue not found: \(issueId)")
      print("🔍 [fetchIssue] Document exists: \(doc.exists)")
      if let data = doc.data() {
        print("🔍 [fetchIssue] Document data keys: \(Array(data.keys))")
      }
      return nil
    }
    
    // Filter out archived issues
    if let archived = data["archived"] as? Bool, archived {
      print("⚠️ [fetchIssue] Issue is archived: \(issueId)")
      return nil
    }
    
    // Use document ID as fallback if id field is missing
    let id = (data["id"] as? String)?.isEmpty == false ? data["id"] as! String : doc.documentID
    
    guard let reporterId = data["reporterId"] as? String,
          let title = data["title"] as? String,
          let statusRaw = data["status"] as? String,
          let status = IssueStatus(rawValue: statusRaw),
          let createdAtTimestamp = data["createdAt"] as? Timestamp else {
      print("❌ [fetchIssue] Missing required fields for issue: \(issueId)")
      print("🔍 [fetchIssue] Available fields: \(Array(data.keys))")
      return nil
    }
    
    // Make locationId optional with fallback
    let locationId = data["locationId"] as? String ?? ""
    let priority = data["priority"] as? String ?? "medium"
    
    // Parse AI analysis if available
    var aiAnalysis: AIAnalysis?
    if let analysisString = data["aiAnalysis"] as? String,
       let analysisData = analysisString.data(using: .utf8) {
      do {
        aiAnalysis = try JSONDecoder().decode(AIAnalysis.self, from: analysisData)
        print("✅ [fetchIssue] Successfully decoded AI analysis for issue: \(id)")
      } catch {
        print("❌ [fetchIssue] Failed to decode AI analysis for issue \(id): \(error)")
      }
    }
    
    let issue = Issue(
      id: id,
      restaurantId: "", // Will be updated when restaurant context is added
      locationId: locationId,
      reporterId: reporterId,
      title: title,
      description: data["description"] as? String,
      type: data["type"] as? String,
      priority: IssuePriority(rawValue: priority) ?? .medium,
      status: status,
      aiAnalysis: aiAnalysis,
      createdAt: createdAtTimestamp.dateValue()
    )
    
    print("✅ [fetchIssue] Successfully fetched issue: \(issue.title)")
    return issue
  }
  
  func fetchIssues() async throws -> [Issue] {
    let snapshot = try await db.collection("issues").getDocuments()
    return snapshot.documents.compactMap { doc in
      let data = doc.data()
      
      // Filter out archived issues
      if let archived = data["archived"] as? Bool, archived {
        return nil
      }
      
      guard let id = data["id"] as? String,
            let locationId = data["locationId"] as? String,
            let reporterId = data["reporterId"] as? String,
            let title = data["title"] as? String,
            let priority = data["priority"] as? String,
            let statusRaw = data["status"] as? String,
            let status = IssueStatus(rawValue: statusRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp else {
        return nil
      }
      
      // Parse AI analysis if available
      var aiAnalysis: AIAnalysis?
      if let analysisString = data["aiAnalysis"] as? String,
         let analysisData = analysisString.data(using: .utf8) {
        do {
          aiAnalysis = try JSONDecoder().decode(AIAnalysis.self, from: analysisData)
          print("✅ [fetchIssues] Successfully decoded AI analysis for issue: \(id)")
        } catch {
          print("❌ [fetchIssues] Failed to decode AI analysis for issue \(id): \(error)")
          print("❌ [fetchIssues] AI analysis string: \(analysisString)")
        }
      } else {
        print("🔍 [fetchIssues] No AI analysis found for issue: \(id)")
      }
      
      return Issue(
        id: id,
        restaurantId: "", // Will be updated when restaurant context is added
        locationId: locationId,
        reporterId: reporterId,
        title: title,
        description: data["description"] as? String,
        type: data["type"] as? String,
        priority: IssuePriority(rawValue: priority) ?? .medium,
        status: status,
        aiAnalysis: aiAnalysis,
        createdAt: createdAtTimestamp.dateValue()
      )
    }
  }
  
  func fetchMaintenanceRequest(id: String) async throws -> MaintenanceRequest {
    print("🔍 [fetchMaintenanceRequest] Fetching from maintenance_requests: \(id)")
    let doc = try await db.collection("maintenance_requests").document(id).getDocument()
    
    guard doc.exists else {
      print("❌ [fetchMaintenanceRequest] Not found: \(id)")
      throw NSError(domain: "FirebaseClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Maintenance request not found"])
    }
    
    // Use Firestore's built-in decoder which handles Timestamps properly
    do {
      var request = try doc.data(as: MaintenanceRequest.self)
      print("✅ [fetchMaintenanceRequest] Found: \(request.title)")
      return request
    } catch let DecodingError.typeMismatch(type, context) where context.codingPath.last?.stringValue == "aiAnalysis" {
      // Handle legacy aiAnalysis stored as JSON string
      print("⚠️ [fetchMaintenanceRequest] aiAnalysis is stored as string, attempting manual decode")
      
      guard let data = doc.data() else {
        throw NSError(domain: "FirebaseClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get document data"])
      }
      
      // Extract and decode aiAnalysis separately
      var aiAnalysis: AIAnalysis?
      if let aiAnalysisString = data["aiAnalysis"] as? String,
         let aiAnalysisData = aiAnalysisString.data(using: .utf8) {
        aiAnalysis = try? JSONDecoder().decode(AIAnalysis.self, from: aiAnalysisData)
        print("✅ [fetchMaintenanceRequest] Decoded aiAnalysis from JSON string")
      }
      
      // Build MaintenanceRequest manually from the data
      guard let id = data["id"] as? String,
            let businessId = data["businessId"] as? String,
            let reporterId = data["reporterId"] as? String,
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let categoryRaw = data["category"] as? String,
            let category = MaintenanceCategory(rawValue: categoryRaw),
            let priorityRaw = data["priority"] as? String,
            let priority = MaintenancePriority(rawValue: priorityRaw),
            let statusRaw = data["status"] as? String,
            let status = RequestStatus(rawValue: statusRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
        throw NSError(domain: "FirebaseClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing required fields"])
      }
      
      let request = MaintenanceRequest(
        id: id,
        businessId: businessId,
        locationId: data["locationId"] as? String,
        reporterId: reporterId,
        assigneeId: data["assigneeId"] as? String,
        title: title,
        description: description,
        category: category,
        priority: priority,
        status: status,
        aiAnalysis: aiAnalysis,
        estimatedCost: data["estimatedCost"] as? Double,
        estimatedTime: data["estimatedTime"] as? String,
        photoUrls: data["photoUrls"] as? [String],
        scheduledAt: (data["scheduledAt"] as? Timestamp)?.dateValue(),
        startedAt: (data["startedAt"] as? Timestamp)?.dateValue(),
        completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
        quotedCost: data["quotedCost"] as? Double,
        actualCost: data["actualCost"] as? Double,
        createdAt: createdAtTimestamp.dateValue(),
        updatedAt: updatedAtTimestamp.dateValue()
      )
      
      print("✅ [fetchMaintenanceRequest] Manually decoded: \(request.title)")
      return request
    }
  }
  
  // MARK: - Work Orders
  func createWorkOrder(_ workOrder: WorkOrder) async throws {
    let scheduledTimestamp = workOrder.scheduledAt.map { Timestamp(date: $0) } ?? NSNull()
    let startedTimestamp = workOrder.startedAt.map { Timestamp(date: $0) } ?? NSNull()
    let completedTimestamp = workOrder.completedAt.map { Timestamp(date: $0) } ?? NSNull()
    
    let workOrderData: [String: Any] = [
      "id": workOrder.id,
      "restaurantId": workOrder.restaurantId,
      "issueId": workOrder.issueId,
      "assigneeId": workOrder.assigneeId ?? "",
      "scheduledAt": scheduledTimestamp,
      "startedAt": startedTimestamp,
      "completedAt": completedTimestamp,
      "status": workOrder.status.rawValue,
      "createdAt": Timestamp(date: workOrder.createdAt)
    ]
    
    try await db.collection("workOrders").document(workOrder.id).setData(workOrderData)
  }
  
  // MARK: - Issue Photos
  func uploadIssuePhoto(issueId: String, photoId: String, image: UIImage) async throws -> String {
    guard let data = image.jpegData(compressionQuality: 0.8) else {
      throw NSError(domain: "FirebaseClient", code: 1002, userInfo: [
        NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"
      ])
    }
    
    let path = "issue-photos/\(issueId)/\(photoId).jpg"
    let ref = storage.reference().child(path)
    _ = try await ref.putDataAsync(data, metadata: nil)
    let url = try await ref.downloadURL()
    
    // Save photo metadata to Firestore
    guard let currentUser = Auth.auth().currentUser else {
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated. Please sign in again."
      ])
    }
    
    try await db.collection("issuePhotos").document(photoId).setData([
      "id": photoId,
      "issueId": issueId,
      "url": url.absoluteString,
      "uploaderId": currentUser.uid,
      "takenAt": Timestamp(date: Date()),  // Use consistent field name
      "uploadedAt": Timestamp(date: Date()) // Keep for backward compatibility
    ])
    
    return url.absoluteString
  }
  
  func fetchIssuePhotos(issueId: String) async throws -> [IssuePhoto] {
    print("🔍 [fetchIssuePhotos] Querying for issueId: \(issueId)")
    let snapshot = try await db.collection("issuePhotos")
      .whereField("issueId", isEqualTo: issueId)
      .getDocuments()
    
    print("🔍 [fetchIssuePhotos] Found \(snapshot.documents.count) documents for issue \(issueId)")
    
    let photos = snapshot.documents.compactMap { doc -> IssuePhoto? in
      let data = doc.data()
      print("🔍 [fetchIssuePhotos] Document \(doc.documentID) data: \(data)")
      
      // Use document ID as fallback if the id field is empty
      let idFromData = data["id"] as? String ?? ""
      let effectiveId = idFromData.isEmpty ? doc.documentID : idFromData
      
      guard !effectiveId.isEmpty,
            let issueId = data["issueId"] as? String, !issueId.isEmpty,
            let url = data["url"] as? String, !url.isEmpty else {
        print("❌ [fetchIssuePhotos] Missing or empty required fields in document: \(doc.documentID)")
        print("❌ [fetchIssuePhotos] Available fields: \(data.keys.sorted())")
        print("❌ [fetchIssuePhotos] id: '\(idFromData)', issueId: '\(data["issueId"] as? String ?? "nil")', url: '\(data["url"] as? String ?? "nil")'")
        print("❌ [fetchIssuePhotos] Using document ID as fallback: \(doc.documentID)")
        return nil
      }
      
      // Handle both old 'takenAt' and new 'uploadedAt' field names for backward compatibility
      let timestamp = (data["takenAt"] as? Timestamp) ?? (data["uploadedAt"] as? Timestamp) ?? Timestamp(date: Date())
      
      print("✅ [fetchIssuePhotos] Successfully parsed photo: \(effectiveId) with URL: \(url)")
      
      return IssuePhoto(
        id: effectiveId,
        issueId: issueId,
        url: url,
        thumbUrl: data["thumbUrl"] as? String,
        takenAt: timestamp.dateValue()
      )
    }
    
    print("📸 [fetchIssuePhotos] Returning \(photos.count) photos for issue \(issueId)")
    return photos
  }
  
  // MARK: - Work Logs
  func fetchWorkLogs(issueId: String) async throws -> [WorkLog] {
    // Query work logs directly by issueId
    let workLogsSnapshot = try await db.collection("workLogs")
      .whereField("issueId", isEqualTo: issueId)
      .getDocuments()
    
    let workLogs = workLogsSnapshot.documents.compactMap { doc -> WorkLog? in
      let data = doc.data()
      // Use document ID as fallback if the id field is empty
      let idFromData = data["id"] as? String ?? ""
      let effectiveId = idFromData.isEmpty ? doc.documentID : idFromData
      
      guard !effectiveId.isEmpty,
            let issueId = data["issueId"] as? String, !issueId.isEmpty,
            let authorId = data["authorId"] as? String, !authorId.isEmpty,
            let message = data["message"] as? String,
            let createdAtTimestamp = data["createdAt"] as? Timestamp else {
        print("❌ [fetchWorkLogs] Missing or empty required fields in document: \(doc.documentID)")
        print("❌ [fetchWorkLogs] Available fields: \(data.keys.sorted())")
        print("❌ [fetchWorkLogs] id: '\(idFromData)', issueId: '\(data["issueId"] as? String ?? "nil")', authorId: '\(data["authorId"] as? String ?? "nil")'")
        return nil
      }
      
      return WorkLog(
        id: effectiveId,
        issueId: issueId,
        authorId: authorId,
        message: message,
        createdAt: createdAtTimestamp.dateValue()
      )
    }
    
    return workLogs.sorted { $0.createdAt < $1.createdAt }
  }
  
  func addWorkLog(_ workLog: WorkLog) async throws {
    let documentRef = try safeDocumentReference(collection: "workLogs", documentId: workLog.id)
    try await documentRef.setData([
      "id": workLog.id,
      "issueId": workLog.issueId,
      "authorId": workLog.authorId,
      "message": workLog.message,
      "createdAt": Timestamp(date: workLog.createdAt)
    ])
    
    // Update issue status based on work log content
    try await updateIssueStatusFromWorkLog(workLog)
  }
  
  func completeWorkOrder(_ workOrderId: String, completionNotes: String, completionPhotos: [UIImage]) async throws {
    print("🏁 Completing work order: \(workOrderId)")
    
    // 1. Upload completion photos if any
    var photoUrls: [String] = []
    for (idx, photo) in completionPhotos.enumerated() {
      guard let data = photo.jpegData(compressionQuality: 0.8) else { continue }
      let path = "completion-photos/\(workOrderId)/photo_\(idx).jpg"
      let ref = storage.reference().child(path)
      _ = try await ref.putDataAsync(data, metadata: nil)
      let url = try await ref.downloadURL()
      photoUrls.append(url.absoluteString)
      print("📸 Completion photo uploaded: \(url.absoluteString)")
    }
    
    // 2. Update work order status
    var updateData: [String: Any] = [
      "status": WorkOrderStatus.completed.rawValue,
      "completedAt": Timestamp(date: Date()),
      "completionNotes": completionNotes
    ]
    
    if !photoUrls.isEmpty {
      updateData["completionPhotos"] = photoUrls
    }
    
    try await db.collection("workOrders").document(workOrderId).updateData(updateData)
    print("✅ Work order marked as completed")
    
    // 3. Update associated issue status
    let workOrderDoc = try await db.collection("workOrders").document(workOrderId).getDocument()
    if let workOrderData = workOrderDoc.data(),
       let issueId = workOrderData["issueId"] as? String {
      try await safeDocumentReference(collection: "issues", documentId: issueId).updateData([
        "status": IssueStatus.completed.rawValue
      ])
      print("✅ Issue \(issueId) marked as completed")
    }
  }
  
  func archiveIssue(_ issueId: String) async throws {
    print("📦 Archiving issue: \(issueId)")
    
    try await safeDocumentReference(collection: "issues", documentId: issueId).updateData([
      "archived": true,
      "archivedAt": Timestamp(date: Date())
    ])
    
    print("✅ Issue archived successfully")
  }
  
  private func updateIssueStatusFromWorkLog(_ workLog: WorkLog) async throws {
    // Validate workLog.issueId is not empty
    guard !workLog.issueId.isEmpty else {
      print("❌ [FirebaseClient] Cannot update issue status: issueId is empty")
      return
    }
    
    // Determine new status based on work log message
    let message = workLog.message.lowercased()
    var newStatus: IssueStatus?
    
    if message.contains("started") || message.contains("beginning") || message.contains("working on") {
      newStatus = .in_progress
    } else if message.contains("completed") || message.contains("finished") || message.contains("done") || message.contains("resolved") {
      newStatus = .completed
    } else if message.contains("scheduled") || message.contains("planning") {
      newStatus = .in_progress
    } else if message.contains("blocked") || message.contains("waiting") || message.contains("delayed") {
      newStatus = .reported // Send back to reported for review
    }
    
    // Update issue status if determined
    if let newStatus = newStatus {
      try await safeDocumentReference(collection: "issues", documentId: workLog.issueId).updateData([
        "status": newStatus.rawValue
      ])
      print("✅ [FirebaseClient] Updated issue \(workLog.issueId) status to \(newStatus.rawValue)")
    }
  }
  
  func fetchWorkOrders() async throws -> [WorkOrder] {
    let snapshot = try await db.collection("workOrders").getDocuments()
    return snapshot.documents.compactMap { doc -> WorkOrder? in
      let data = doc.data()
      guard let id = data["id"] as? String,
            let issueId = data["issueId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = WorkOrderStatus(rawValue: statusRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp else {
        return nil
      }
      
      return WorkOrder(
        id: id,
        restaurantId: data["restaurantId"] as? String ?? "",
        issueId: issueId,
        assigneeId: data["assigneeId"] as? String,
        status: status,
        scheduledAt: (data["scheduledAt"] as? Timestamp)?.dateValue(),
        startedAt: (data["startedAt"] as? Timestamp)?.dateValue(),
        completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
        createdAt: createdAtTimestamp.dateValue()
      )
    }
  }
  
  func fetchWorkOrders(for issueId: String) async throws -> [WorkOrder] {
    let snapshot = try await db.collection("workOrders")
      .whereField("issueId", isEqualTo: issueId)
      .getDocuments()
    
    return snapshot.documents.compactMap { doc -> WorkOrder? in
      let data = doc.data()
      guard let id = data["id"] as? String,
            let issueId = data["issueId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = WorkOrderStatus(rawValue: statusRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp else {
        return nil
      }
      
      return WorkOrder(
        id: id,
        restaurantId: data["restaurantId"] as? String ?? "",
        issueId: issueId,
        assigneeId: data["assigneeId"] as? String,
        status: status,
        scheduledAt: (data["scheduledAt"] as? Timestamp)?.dateValue(),
        startedAt: (data["startedAt"] as? Timestamp)?.dateValue(),
        completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
        createdAt: createdAtTimestamp.dateValue()
      )
    }
  }
  
  // MARK: - Restaurants
  func fetchRestaurant(id: String) async throws -> Restaurant? {
    // Handle empty restaurant ID (older issues from early September)
    guard !id.isEmpty else {
      print("🔍 [FirebaseClient] Skipping restaurant fetch for empty ID - this is an older issue")
      return nil
    }
    
    let doc = try await safeDocumentReference(collection: "restaurants", documentId: id).getDocument()
    guard let data = doc.data(), let name = data["name"] as? String else {
      return nil
    }
    
    let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
    
    return Business(
      id: doc.documentID,
      name: name,
      businessType: .restaurant,
      address: data["address"] as? String,
      phone: data["phone"] as? String,
      website: data["website"] as? String,
      logoUrl: data["logoUrl"] as? String,
      placeId: data["placeId"] as? String,
      latitude: data["latitude"] as? Double,
      longitude: data["longitude"] as? Double,
      businessHours: data["businessHours"] as? [String: String],
      category: data["cuisine"] as? String,
      priceLevel: data["priceLevel"] as? Int,
      rating: data["rating"] as? Double,
      totalRatings: data["totalRatings"] as? Int,
      ownerId: data["ownerId"] as? String ?? "",
      createdAt: createdAtTimestamp.dateValue(),
      isActive: data["isActive"] as? Bool ?? true,
      verificationStatus: VerificationStatus(rawValue: data["verificationStatus"] as? String ?? "pending") ?? .pending,
      verificationMethod: data["verificationMethod"] as? String != nil ? VerificationMethod(rawValue: data["verificationMethod"] as! String) : nil,
      verifiedAt: (data["verifiedAt"] as? Timestamp)?.dateValue(),
      verificationData: data["verificationData"] as? [String: String]
    )
  }
  
  // Batch fetch restaurants by IDs for performance optimization
  func fetchRestaurants(ids: [String]) async throws -> [Restaurant] {
    guard !ids.isEmpty else { return [] }
    
    print("🔄 [FirebaseClient] Batch fetching \(ids.count) restaurants...")
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // Firestore 'in' queries are limited to 10 items, so we need to batch
    let batchSize = 10
    var allRestaurants: [Restaurant] = []
    
    for i in stride(from: 0, to: ids.count, by: batchSize) {
      let endIndex = min(i + batchSize, ids.count)
      let batchIds = Array(ids[i..<endIndex])
      
      let snapshot = try await db.collection("restaurants")
        .whereField(FieldPath.documentID(), in: batchIds)
        .getDocuments()
      
      for doc in snapshot.documents {
        let data = doc.data()
        guard let name = data["name"] as? String else { continue }
        
        let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
        
        let restaurant = Business(
          id: doc.documentID,
          name: name,
          businessType: .restaurant,
          address: data["address"] as? String,
          phone: data["phone"] as? String,
          website: data["website"] as? String,
          logoUrl: data["logoUrl"] as? String,
          placeId: data["placeId"] as? String,
          latitude: data["latitude"] as? Double,
          longitude: data["longitude"] as? Double,
          businessHours: data["businessHours"] as? [String: String],
          category: data["cuisine"] as? String,
          priceLevel: data["priceLevel"] as? Int,
          rating: data["rating"] as? Double,
          totalRatings: data["totalRatings"] as? Int,
          ownerId: data["ownerId"] as? String ?? "",
          createdAt: createdAtTimestamp.dateValue(),
          isActive: data["isActive"] as? Bool ?? true,
          verificationStatus: VerificationStatus(rawValue: data["verificationStatus"] as? String ?? "pending") ?? .pending,
          verificationMethod: data["verificationMethod"] as? String != nil ? VerificationMethod(rawValue: data["verificationMethod"] as! String) : nil,
          verifiedAt: (data["verifiedAt"] as? Timestamp)?.dateValue(),
          verificationData: data["verificationData"] as? [String: String]
        )
        
        allRestaurants.append(restaurant)
      }
    }
    
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("✅ [FirebaseClient] Batch fetched \(allRestaurants.count) restaurants in \(elapsed)s")
    
    return allRestaurants
  }
  
  func getRestaurants(ownerId: String) async throws -> [Restaurant] {
    let snapshot = try await db.collection("restaurants")
      .whereField("ownerId", isEqualTo: ownerId)
      .getDocuments()
    
    return snapshot.documents.compactMap { doc -> Restaurant? in
      let data = doc.data()
      guard let name = data["name"] as? String else { return nil }
      
      let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
      
      return Business(
        id: doc.documentID,
        name: name,
        businessType: .restaurant,
        address: data["address"] as? String,
        phone: data["phone"] as? String,
        website: data["website"] as? String,
        logoUrl: data["logoUrl"] as? String,
        placeId: data["placeId"] as? String,
        latitude: data["latitude"] as? Double,
        longitude: data["longitude"] as? Double,
        businessHours: data["businessHours"] as? [String: String],
        category: data["cuisine"] as? String,
        priceLevel: data["priceLevel"] as? Int,
        rating: data["rating"] as? Double,
        totalRatings: data["totalRatings"] as? Int,
        ownerId: data["ownerId"] as? String ?? "",
        createdAt: createdAtTimestamp.dateValue(),
        isActive: data["isActive"] as? Bool ?? true,
        verificationStatus: VerificationStatus(rawValue: data["verificationStatus"] as? String ?? "pending") ?? .pending,
        verificationMethod: data["verificationMethod"] as? String != nil ? VerificationMethod(rawValue: data["verificationMethod"] as! String) : nil,
        verifiedAt: (data["verifiedAt"] as? Timestamp)?.dateValue(),
        verificationData: data["verificationData"] as? [String: String]
      )
    }
  }
  
  func listBusinesses() async throws -> [Business] {
    // Query both restaurants and businesses collections
    let restaurantsSnap = try await db.collection("restaurants")
      .order(by: "name", descending: false)
      .getDocuments()
    
    let businessesSnap = try await db.collection("businesses")
      .order(by: "name", descending: false)
      .getDocuments()
    
    var allBusinesses: [Business] = []
    
    // Process restaurants collection (convert to Business objects)
    let restaurants = restaurantsSnap.documents.compactMap { doc -> Business? in
      let data = doc.data()
      guard let name = data["name"] as? String else { return nil }
      
      let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
      
      return Business(
        id: doc.documentID,
        name: name,
        businessType: .restaurant,
        address: data["address"] as? String,
        phone: data["phone"] as? String,
        website: data["website"] as? String,
        logoUrl: data["logoUrl"] as? String,
        placeId: data["placeId"] as? String,
        latitude: data["latitude"] as? Double,
        longitude: data["longitude"] as? Double,
        businessHours: data["businessHours"] as? [String: String],
        category: data["cuisine"] as? String,
        priceLevel: data["priceLevel"] as? Int,
        rating: data["rating"] as? Double,
        totalRatings: data["totalRatings"] as? Int,
        ownerId: data["ownerId"] as? String ?? "",
        createdAt: createdAtTimestamp.dateValue(),
        isActive: data["isActive"] as? Bool ?? true,
        verificationStatus: VerificationStatus(rawValue: data["verificationStatus"] as? String ?? "pending") ?? .pending,
        verificationMethod: data["verificationMethod"] as? String != nil ? VerificationMethod(rawValue: data["verificationMethod"] as! String) : nil,
        verifiedAt: (data["verifiedAt"] as? Timestamp)?.dateValue(),
        verificationData: data["verificationData"] as? [String: String]
      )
    }
    allBusinesses.append(contentsOf: restaurants)
    
    // Process businesses collection
    let businesses = businessesSnap.documents.compactMap { doc -> Business? in
      let data = doc.data()
      guard let name = data["name"] as? String else { return nil }
      
      let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
      let businessTypeString = data["businessType"] as? String ?? "other"
      let businessType = BusinessType(rawValue: businessTypeString) ?? .other
      
      return Business(
        id: doc.documentID,
        name: name,
        businessType: businessType,
        address: data["address"] as? String,
        phone: data["phone"] as? String,
        website: data["website"] as? String,
        logoUrl: data["logoUrl"] as? String,
        placeId: data["placeId"] as? String,
        latitude: data["latitude"] as? Double,
        longitude: data["longitude"] as? Double,
        businessHours: data["businessHours"] as? [String: String],
        category: data["category"] as? String,
        priceLevel: data["priceLevel"] as? Int,
        rating: data["rating"] as? Double,
        totalRatings: data["totalRatings"] as? Int,
        ownerId: data["ownerId"] as? String ?? "",
        createdAt: createdAtTimestamp.dateValue(),
        isActive: data["isActive"] as? Bool ?? true,
        verificationStatus: VerificationStatus(rawValue: data["verificationStatus"] as? String ?? "pending") ?? .pending,
        verificationMethod: data["verificationMethod"] as? String != nil ? VerificationMethod(rawValue: data["verificationMethod"] as! String) : nil,
        verifiedAt: (data["verifiedAt"] as? Timestamp)?.dateValue(),
        verificationData: data["verificationData"] as? [String: String]
      )
    }
    allBusinesses.append(contentsOf: businesses)
    
    // Deduplicate businesses by name and address to avoid showing duplicates
    var uniqueBusinesses: [Business] = []
    var seenKeys: Set<String> = []
    
    for business in allBusinesses {
      let key = "\(business.name.lowercased())_\(business.address?.lowercased() ?? "")"
      if !seenKeys.contains(key) {
        seenKeys.insert(key)
        uniqueBusinesses.append(business)
      }
    }
    
    return uniqueBusinesses
  }
  
  // Keep listRestaurants for backward compatibility
  func listRestaurants() async throws -> [Restaurant] {
    return try await listBusinesses()
  }
  
  
  func listUsers(restaurantId: String? = nil) async throws -> [AppUser] {
    var query = db.collection("users")
      .order(by: "createdAt", descending: false)
    
    // Filter by restaurant if specified
    if let restaurantId = restaurantId {
      query = query.whereField("restaurantId", isEqualTo: restaurantId)
    }
    
    let snap = try await query.getDocuments()
    return snap.documents.compactMap { doc in
      let data = doc.data()
      guard let email = data["email"] as? String,
            let roleRaw = data["role"] as? String,
            let role = Role(rawValue: roleRaw) else { return nil }
      
      let _ = data["createdAt"] as? Timestamp ?? Timestamp()
      
      return AppUser(
        id: doc.documentID,
        role: role,
        name: data["name"] as? String ?? "",
        phone: data["phone"] as? String,
        email: email
      )
    }
  }
  
  func updateIssueStatus(issueId: String, status: IssueStatus) async throws {
    try await safeDocumentReference(collection: "issues", documentId: issueId).updateData([
      "status": status.rawValue,
      "updatedAt": Timestamp(date: Date())
    ])
  }

  func listWorkOrders(restaurantId: String? = nil) async throws -> [WorkOrder] {
    var query = db.collection("workOrders")
      .order(by: "scheduledAt", descending: false)
    
    // Filter by restaurant if specified (for restaurant owners)
    if let restaurantId = restaurantId {
      query = query.whereField("restaurantId", isEqualTo: restaurantId)
    }
    
    let snap = try await query.getDocuments()
    return snap.documents.compactMap { doc in
      let data = doc.data()
      guard let restaurantId = data["restaurantId"] as? String,
            let issueId = data["issueId"] as? String,
            let statusStr = data["status"] as? String,
            let status = WorkOrderStatus(rawValue: statusStr) else { return nil }
      
      let scheduledTs = data["scheduledAt"] as? Timestamp
      let startedTs = data["startedAt"] as? Timestamp
      let completedTs = data["completedAt"] as? Timestamp
      
      let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
      
      return WorkOrder(
        id: doc.documentID,
        restaurantId: restaurantId,
        issueId: issueId,
        assigneeId: data["assigneeId"] as? String,
        status: status,
        scheduledAt: scheduledTs?.dateValue(),
        startedAt: startedTs?.dateValue(),
        completedAt: completedTs?.dateValue(),
        estimatedCost: data["estimatedCost"] as? Double,
        actualCost: data["actualCost"] as? Double,
        notes: data["notes"] as? String,
        createdAt: createdAtTimestamp.dateValue()
      )
    }
  }
  
  // MARK: - Quote Management
  func saveQuoteEstimate(_ quote: QuoteEstimate) async throws {
    let data: [String: Any] = [
      "id": quote.id,
      "issueId": quote.issueId,
      "restaurantId": quote.restaurantId,
      "aiAnalysisId": quote.aiAnalysisId as Any,
      "status": quote.status.rawValue,
      "laborHours": quote.costBreakdown.laborHours,
      "laborRate": quote.costBreakdown.laborRate,
      "materials": quote.costBreakdown.materials.map { material in
        [
          "id": material.id,
          "name": material.name,
          "quantity": material.quantity,
          "unitPrice": material.unitPrice,
          "unit": material.unit
        ]
      },
      "additionalFees": quote.costBreakdown.additionalFees.map { fee in
        [
          "id": fee.id,
          "name": fee.name,
          "amount": fee.amount,
          "description": fee.description as Any
        ]
      },
      "aiConfidence": quote.aiConfidence as Any,
      "notes": quote.notes as Any,
      "validUntil": quote.validUntil.map { Timestamp(date: $0) } as Any,
      "createdBy": quote.createdBy,
      "createdAt": Timestamp(date: quote.createdAt),
      "updatedAt": Timestamp(date: quote.updatedAt),
      "sentAt": quote.sentAt.map { Timestamp(date: $0) } as Any,
      "approvedAt": quote.approvedAt.map { Timestamp(date: $0) } as Any
    ]
    
    try await db.collection("quotes").document(quote.id).setData(data)
  }
  
  func fetchQuoteEstimates(for issueId: String) async throws -> [QuoteEstimate] {
    let snapshot = try await db.collection("quotes")
      .whereField("issueId", isEqualTo: issueId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return snapshot.documents.compactMap { doc -> QuoteEstimate? in
      let data = doc.data()
      
      guard let id = data["id"] as? String,
            let issueId = data["issueId"] as? String,
            let restaurantId = data["restaurantId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = QuoteStatus(rawValue: statusRaw),
            let laborHours = data["laborHours"] as? Double,
            let laborRate = data["laborRate"] as? Double,
            let materialsData = data["materials"] as? [[String: Any]],
            let feesData = data["additionalFees"] as? [[String: Any]],
            let createdBy = data["createdBy"] as? String,
            let createdAtTimestamp = data["createdAt"] as? Timestamp else {
        return nil
      }
      
      let materials = materialsData.compactMap { materialData -> MaterialCost? in
        guard let id = materialData["id"] as? String,
              let name = materialData["name"] as? String,
              let quantity = materialData["quantity"] as? Double,
              let unitPrice = materialData["unitPrice"] as? Double,
              let unit = materialData["unit"] as? String else {
          return nil
        }
        return MaterialCost(id: id, name: name, quantity: quantity, unitPrice: unitPrice, unit: unit)
      }
      
      let fees = feesData.compactMap { feeData -> AdditionalFee? in
        guard let id = feeData["id"] as? String,
              let name = feeData["name"] as? String,
              let amount = feeData["amount"] as? Double else {
          return nil
        }
        let description = feeData["description"] as? String
        return AdditionalFee(id: id, name: name, amount: amount, description: description)
      }
      
      let costBreakdown = CostBreakdown(
        laborHours: laborHours,
        laborRate: laborRate,
        materials: materials,
        additionalFees: fees
      )
      
      return QuoteEstimate(
        id: id,
        issueId: issueId,
        restaurantId: restaurantId,
        aiAnalysisId: data["aiAnalysisId"] as? String,
        status: status,
        costBreakdown: costBreakdown,
        aiConfidence: data["aiConfidence"] as? Double,
        notes: data["notes"] as? String,
        validUntil: (data["validUntil"] as? Timestamp)?.dateValue(),
        createdBy: createdBy,
        createdAt: createdAtTimestamp.dateValue(),
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAtTimestamp.dateValue(),
        sentAt: (data["sentAt"] as? Timestamp)?.dateValue(),
        approvedAt: (data["approvedAt"] as? Timestamp)?.dateValue()
      )
    }
  }
  
  // MARK: - Issues
  func listIssues(restaurantId: String? = nil) async throws -> [Issue] {
    print("🔍 [FirebaseClient] ===== LIST ISSUES STARTED =====")
    print("🔍 [FirebaseClient] Restaurant ID filter: \(restaurantId ?? "nil")")
    
    // Check cache first for nil restaurant queries (most common case)
    if restaurantId == nil, let cachedIssues = FirebaseCache.shared.getCachedIssues() {
      print("🚀 [FirebaseClient] Returning cached issues - PERFORMANCE BOOST!")
      return cachedIssues
    }
    
    // Check Firebase Auth state
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [FirebaseClient] No authenticated user for listing issues")
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated. Please sign in again."
      ])
    }
    
    print("✅ [FirebaseClient] Authenticated user: \(currentUser.uid)")
    print("🔍 [FirebaseClient] Cache miss - fetching from Firebase...")
    
    var query = db.collection("issues")
      .order(by: "createdAt", descending: true)
    
    // Filter by restaurant if specified (for restaurant owners)
    if let restaurantId = restaurantId {
      query = query.whereField("restaurantId", isEqualTo: restaurantId)
    }
    
    do {
      print("🔍 [FirebaseClient] Executing Firestore query...")
      let snap = try await query.getDocuments()
      print("✅ [FirebaseClient] Successfully fetched \(snap.documents.count) issues")
      print("✅ [FirebaseClient] Query metadata - from cache: \(snap.metadata.isFromCache)")
      
      let issues = snap.documents.compactMap { doc -> Issue? in
        let data = doc.data()
        // Reduced logging for performance
        
        // Essential fields - only document ID and title are truly required
        guard let title = data["title"] as? String else { 
          print("❌ [FirebaseClient] Failed to parse issue document: \(doc.documentID) - missing title")
          return nil 
        }
        
        // Fields with defaults for backward compatibility
        let restaurantId = data["restaurantId"] as? String ?? ""
        let locationId = data["locationId"] as? String ?? ""
        let reporterId = data["reporterId"] as? String ?? ""
        let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp()
        
        // Optional fields with defaults
        let description = data["description"] as? String
        let type = data["type"] as? String
        let priorityStr = data["priority"] as? String ?? "medium"
        let priority = IssuePriority(rawValue: priorityStr) ?? .medium
        let statusStr = data["status"] as? String ?? "reported"
        let status = IssueStatus(rawValue: statusStr) ?? .reported
        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? createdAtTimestamp
      
      let photoUrls = data["photoUrls"] as? [String]
      
      // Parse AI analysis if present
      var aiAnalysis: AIAnalysis?
      if let analysisString = data["aiAnalysis"] as? String,
         let analysisData = analysisString.data(using: .utf8) {
        do {
          aiAnalysis = try JSONDecoder().decode(AIAnalysis.self, from: analysisData)
          // Reduced logging for performance - only log failures
        } catch {
          print("❌ [listIssues] Failed to decode AI analysis for issue \(doc.documentID): \(error)")
        }
      }
      // Removed "No AI analysis" logging to reduce console spam
      
      let issue = Issue(
        id: doc.documentID,
        restaurantId: restaurantId,
        locationId: locationId,
        reporterId: reporterId,
        title: title,
        description: description,
        type: type,
        priority: priority,
        status: status,
        photoUrls: photoUrls,
        aiAnalysis: aiAnalysis,
        voiceNotes: data["voiceNotes"] as? String,
        createdAt: createdAtTimestamp.dateValue(),
        updatedAt: updatedAtTimestamp.dateValue()
      )
      return issue
    }
      
      // Cache the results if this was a general query (no restaurant filter)
      if restaurantId == nil {
        FirebaseCache.shared.cacheIssues(issues)
      }
      
      return issues
    } catch {
      print("❌ [FirebaseClient] ===== LIST ISSUES FAILED =====")
      print("❌ [FirebaseClient] Error: \(error.localizedDescription)")
      print("❌ [FirebaseClient] Error code: \((error as NSError).code)")
      print("❌ [FirebaseClient] Error domain: \((error as NSError).domain)")
      
      if let firestoreError = error as NSError?, firestoreError.domain == FirestoreErrorDomain {
        print("❌ [FirebaseClient] Firestore error code: \(firestoreError.code)")
      }
      
      throw error
    }
  }
  
  func createLocation(_ location: Location) async throws {
    try await db.collection("locations").document(location.id).setData([
      "id": location.id,
      "restaurantId": location.restaurantId,
      "name": location.name,
      "address": location.address ?? ""
    ])
  }
  
  // MARK: - Restaurants
  func createRestaurant(_ restaurant: Restaurant) async throws {
    let restaurantData: [String: Any] = [
      "id": restaurant.id,
      "name": restaurant.name,
      "address": restaurant.address ?? "",
      "phone": restaurant.phone ?? "",
      "website": restaurant.website ?? "",
      "logoUrl": restaurant.logoUrl ?? "",
      "placeId": restaurant.placeId ?? "",
      "latitude": restaurant.latitude ?? 0.0,
      "longitude": restaurant.longitude ?? 0.0,
      "businessHours": restaurant.businessHours ?? [:],
      "cuisine": restaurant.category ?? "",
      "priceLevel": restaurant.priceLevel ?? 0,
      "rating": restaurant.rating ?? 0.0,
      "totalRatings": restaurant.totalRatings ?? 0,
      "ownerId": restaurant.ownerId,
      "createdAt": Timestamp(date: restaurant.createdAt),
      "isActive": restaurant.isActive
    ]
    
    try await db.collection("restaurants").document(restaurant.id).setData(restaurantData)
  }
  
  func createUser(_ user: AppUser) async throws {
    print("👤 [FirebaseClient] ===== CREATE USER STARTED =====")
    print("👤 [FirebaseClient] User ID: \(user.id)")
    print("👤 [FirebaseClient] User email: \(user.email ?? "nil")")
    print("👤 [FirebaseClient] User role: \(user.role.rawValue)")
    
    // Check Firebase Auth state
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [FirebaseClient] No authenticated user for creating user document")
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated. Please sign in again."
      ])
    }
    
    print("✅ [FirebaseClient] Authenticated user: \(currentUser.uid)")
    
    do {
      try await db.collection("users").document(user.id).setData([
        "id": user.id,
        "role": user.role.rawValue,
        "name": user.name,
        "phone": user.phone ?? "",
        "email": user.email ?? "",
        "createdAt": Timestamp(date: Date())
      ])
      print("✅ [FirebaseClient] User document created successfully")
    } catch {
      print("❌ [FirebaseClient] Failed to create user document: \(error)")
      print("❌ [FirebaseClient] Error code: \((error as NSError).code)")
      print("❌ [FirebaseClient] Error domain: \((error as NSError).domain)")
      throw error
    }
  }
  
  // MARK: - Locations
  func listLocations(restaurantId: String? = nil, createdAfter: Date? = nil) async throws -> [Location] {
    print("🏢 [FirebaseClient] listLocations called with restaurantId: \(restaurantId ?? "nil")")
    var query = db.collection("locations")
      .order(by: "name", descending: false)
    
    // Filter by restaurant if specified (for restaurant owners)
    if let restaurantId = restaurantId {
      query = query.whereField("restaurantId", isEqualTo: restaurantId)
    }
    
    // TESTING MODE: Filter by creation date
    if let createdAfter = createdAfter {
      query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: createdAfter))
      print("🧪 [TESTING MODE] Filtering locations created after \(createdAfter)")
    }
    
    do {
      let snap = try await query.getDocuments()
      print("✅ [FirebaseClient] Successfully fetched \(snap.documents.count) locations")
      var processedCount = 0
      return snap.documents.compactMap { doc in
        let data = doc.data()
        processedCount += 1
        // Only log first few locations to reduce spam
        if processedCount <= 3 {
          print("🏢 [FirebaseClient] Processing location document: \(doc.documentID)")
        }
        guard let restaurantId = data["restaurantId"] as? String,
              let name = data["name"] as? String else { 
          if processedCount <= 3 {
            print("❌ [FirebaseClient] Failed to parse location document: \(doc.documentID)")
          }
          return nil 
        }
        
        let location = Location(
          id: doc.documentID,
          restaurantId: restaurantId,
          name: name,
          address: data["address"] as? String
        )
        if processedCount <= 3 {
          print("✅ [FirebaseClient] Successfully parsed location: \(location.name)")
        }
        return location
      }
    } catch {
      print("❌ [FirebaseClient] Error fetching locations: \(error)")
      throw error
    }
  }
  
  // MARK: - Push Notifications
  
  func updateUserFCMToken(userId: String, fcmToken: String) async throws {
    // PERFORMANCE: Add timeout to prevent app hanging
    guard let currentUser = Auth.auth().currentUser else {
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated"
      ])
    }
    
    let tokenData: [String: Any] = [
      "fcmToken": fcmToken,
      "tokenUpdatedAt": Timestamp(date: Date())
    ]
    
    // Use withTimeout to prevent blocking
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await self.db.collection("users").document(userId).updateData(tokenData)
      }
      
      group.addTask {
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
        throw NSError(domain: "FirebaseClient", code: 408, userInfo: [
          NSLocalizedDescriptionKey: "FCM token update timed out"
        ])
      }
      
      // Return on first completion (success or timeout)
      try await group.next()
      group.cancelAll()
    }
  }
  
  func sendNotificationTrigger(
    userIds: [String],
    title: String,
    body: String,
    data: [String: Any]
  ) async throws {
    let notificationDoc: [String: Any] = [
      "userIds": userIds,
      "title": title,
      "body": body,
      "data": data,
      "createdAt": Timestamp(date: Date()),
      "processed": false
    ]
    
    try await db.collection("notificationTriggers").addDocument(data: notificationDoc)
    print("✅ [FirebaseClient] Created notification trigger for \(userIds.count) users")
  }
  
  func getUserFCMTokens(userIds: [String]) async throws -> [String: String] {
    var tokens: [String: String] = [:]
    
    for userId in userIds {
      do {
        let doc = try await db.collection("users").document(userId).getDocument()
        if let fcmToken = doc.data()?["fcmToken"] as? String {
          tokens[userId] = fcmToken
        }
      } catch {
        print("⚠️ [FirebaseClient] Failed to get FCM token for user \(userId): \(error)")
      }
    }
    
    return tokens
  }
  
  func getAdminUserIds(adminEmails: [String]) async throws -> [String] {
    var adminUserIds: [String] = []
    
    for email in adminEmails {
      do {
        // Query users collection by email
        let query = db.collection("users").whereField("email", isEqualTo: email)
        let snapshot = try await query.getDocuments()
        
        for document in snapshot.documents {
          adminUserIds.append(document.documentID)
          print("🔔 [FirebaseClient] Found admin user: \(email) -> \(document.documentID)")
        }
      } catch {
        print("⚠️ [FirebaseClient] Failed to find user with email \(email): \(error)")
      }
    }
    
    print("🔔 [FirebaseClient] Total admin users found: \(adminUserIds.count)")
    return adminUserIds
  }
  
  func getAllUsers() async throws -> [AppUser] {
    let snapshot = try await db.collection("users").getDocuments()
    var users: [AppUser] = []
    
    for document in snapshot.documents {
      do {
        let user = try document.data(as: AppUser.self)
        users.append(user)
      } catch {
        print("⚠️ [FirebaseClient] Failed to decode user \(document.documentID): \(error)")
      }
    }
    
    print("🔔 [FirebaseClient] Retrieved \(users.count) total users")
    return users
  }
  
  // MARK: - User Management
  
  /// Save or update user document in Firestore
  func saveUser(_ user: AppUser) async throws {
    try db.collection("users").document(user.id).setData(from: user, merge: true)
    print("✅ [FirebaseClient] Saved user to Firestore: \(user.name) (\(user.id))")
  }
  
  // MARK: - Fetch Single User
  func fetchUser(userId: String) async throws -> AppUser? {
    let document = try await db.collection("users").document(userId).getDocument()
    
    guard document.exists else {
      print("⚠️ [FirebaseClient] User not found: \(userId)")
      return nil
    }
    
    do {
      let user = try document.data(as: AppUser.self)
      print("✅ [FirebaseClient] Fetched user: \(user.name) (\(userId))")
      return user
    } catch {
      print("❌ [FirebaseClient] Failed to decode user \(userId): \(error)")
      return nil
    }
  }
  
  func getIssue(issueId: String) async throws -> Issue {
    let document = try await db.collection("issues").document(issueId).getDocument()
    guard document.exists else {
      throw NSError(domain: "FirebaseClient", code: 404, userInfo: [
        NSLocalizedDescriptionKey: "Issue not found"
      ])
    }
    return try document.data(as: Issue.self)
  }
  
  // MARK: - Issue Updates with Retry Logic
  private func updateIssueWithRetry(_ issue: Issue, maxRetries: Int) async throws {
    var lastError: Error?
    
    for attempt in 0..<maxRetries {
      do {
        try await performIssueUpdate(issue)
        return // Success, exit retry loop
      } catch {
        lastError = error
        let nsError = error as NSError
        
        // Only retry on permission errors (code 7)
        if nsError.code == 7 && attempt < maxRetries - 1 {
          let delay = pow(2.0, Double(attempt)) // Exponential backoff: 1s, 2s, 4s
          print("⏳ [FirebaseClient] Permission error, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } else {
          throw error // Non-permission error or max retries reached
        }
      }
    }
    
    if let lastError = lastError {
      throw lastError
    }
  }
  
  func updateIssue(_ issue: Issue) async throws {
    print("📝 [FirebaseClient] ===== UPDATE ISSUE STARTED =====")
    print("📝 [FirebaseClient] Issue ID: \(issue.id)")
    print("📝 [FirebaseClient] New Status: \(issue.status.rawValue)")
    
    // Retry logic for permission errors (Firebase rules propagation delay)
    try await updateIssueWithRetry(issue, maxRetries: 3)
  }
  
  private func performIssueUpdate(_ issue: Issue) async throws {
    
    // Check Firebase Auth state
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [FirebaseClient] No authenticated user for issue update")
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated. Please sign in again."
      ])
    }
    
    print("✅ [FirebaseClient] Authenticated user: \(currentUser.uid)")
    
    var issueData: [String: Any] = [
      "restaurantId": issue.restaurantId,
      "locationId": issue.locationId,
      "reporterId": issue.reporterId,
      "title": issue.title,
      "description": issue.description ?? "",
      "type": issue.type ?? "",
      "priority": issue.priority.rawValue,
      "status": issue.status.rawValue,
      "updatedAt": Timestamp(date: Date())
    ]
    
    // Add AI analysis if available
    if let aiAnalysis = issue.aiAnalysis {
      let analysisData = try JSONEncoder().encode(aiAnalysis)
      issueData["aiAnalysis"] = String(data: analysisData, encoding: .utf8)
    }
    
    // Add voice notes if available
    if let voiceNotes = issue.voiceNotes, !voiceNotes.isEmpty {
      issueData["voiceNotes"] = voiceNotes
    }
    
    // Add photo URLs if available
    if let photoUrls = issue.photoUrls, !photoUrls.isEmpty {
      issueData["photoUrls"] = photoUrls
    }
    
    do {
      try await safeDocumentReference(collection: "issues", documentId: issue.id).updateData(issueData)
      print("✅ [FirebaseClient] Issue updated successfully: \(issue.id)")
    } catch {
      print("❌ [FirebaseClient] Failed to update issue: \(error)")
      print("❌ [FirebaseClient] Error code: \((error as NSError).code)")
      print("❌ [FirebaseClient] Error domain: \((error as NSError).domain)")
      
      // Add specific handling for permissions errors
      if (error as NSError).code == 7 { // PERMISSION_DENIED
        print("🔍 [FirebaseClient] Permission denied error detected")
        print("🔍 [FirebaseClient] Current user: \(currentUser.uid)")
        print("🔍 [FirebaseClient] User email: \(currentUser.email ?? "no email")")
        print("🔍 [FirebaseClient] Issue ID: \(issue.id)")
        print("🔍 [FirebaseClient] Issue reporter: \(issue.reporterId)")
        
        // Check if this is a specific problematic document
        if issue.id == "D8E494C1-622E-43FE-A105-E461086DDCAC" {
          print("⚠️ [FirebaseClient] This is the problematic document from logs - may have corrupted data")
        }
      }
      
      throw error
    }
  }
  
  // MARK: - Work Logs
  func createWorkLog(_ workLog: WorkLog) async throws {
    print("📝 [FirebaseClient] ===== CREATE WORK LOG STARTED =====")
    print("📝 [FirebaseClient] Work Log ID: \(workLog.id)")
    print("📝 [FirebaseClient] Issue ID: \(workLog.issueId)")
    print("📝 [FirebaseClient] Author ID: \(workLog.authorId)")
    
    // Check Firebase Auth state
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [FirebaseClient] No authenticated user for work log creation")
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated. Please sign in again."
      ])
    }
    
    print("✅ [FirebaseClient] Authenticated user: \(currentUser.uid)")
    
    let workLogData: [String: Any] = [
      "id": workLog.id,
      "issueId": workLog.issueId,
      "authorId": workLog.authorId,
      "message": workLog.message,
      "createdAt": Timestamp(date: workLog.createdAt)
    ]
    
    do {
      try await db.collection("workLogs").document(workLog.id).setData(workLogData)
      print("✅ [FirebaseClient] Work log created successfully: \(workLog.id)")
    } catch {
      print("❌ [FirebaseClient] Failed to create work log: \(error)")
      print("❌ [FirebaseClient] Error code: \((error as NSError).code)")
      print("❌ [FirebaseClient] Error domain: \((error as NSError).domain)")
      throw error
    }
  }
  
  // MARK: - Receipt Management
  func createReceipt(_ receipt: Receipt, receiptImage: UIImage) async throws {
    print("🧾 [FirebaseClient] Creating receipt: \(receipt.id)")
    
    guard Auth.auth().currentUser != nil else {
      throw NSError(domain: "FirebaseClient", code: 1000, userInfo: [
        NSLocalizedDescriptionKey: "User not authenticated"
      ])
    }
    
    // 1. Upload receipt image
    guard let imageData = receiptImage.jpegData(compressionQuality: 0.8) else {
      throw NSError(domain: "FirebaseClient", code: 1001, userInfo: [
        NSLocalizedDescriptionKey: "Failed to convert receipt image to data"
      ])
    }
    
    let imagePath = "receipts/\(receipt.id)/receipt.jpg"
    let imageRef = storage.reference().child(imagePath)
    
    let _ = try await imageRef.putDataAsync(imageData)
    let imageUrl = try await imageRef.downloadURL().absoluteString
    
    // 2. Create thumbnail (smaller version)
    let thumbnailData = receiptImage.jpegData(compressionQuality: 0.3)
    let thumbnailPath = "receipts/\(receipt.id)/thumbnail.jpg"
    let thumbnailRef = storage.reference().child(thumbnailPath)
    
    var thumbnailUrl: String? = nil
    if let thumbnailData = thumbnailData {
      let _ = try await thumbnailRef.putDataAsync(thumbnailData)
      thumbnailUrl = try await thumbnailRef.downloadURL().absoluteString
    }
    
    // 3. Create receipt document with image URLs
    var updatedReceipt = receipt
    updatedReceipt.receiptImageUrl = imageUrl
    updatedReceipt.thumbnailUrl = thumbnailUrl
    
    let receiptData: [String: Any] = [
      "id": updatedReceipt.id,
      "issueId": updatedReceipt.issueId,
      "workOrderId": updatedReceipt.workOrderId as Any,
      "restaurantId": updatedReceipt.restaurantId,
      "submittedBy": updatedReceipt.submittedBy,
      "vendor": updatedReceipt.vendor,
      "category": updatedReceipt.category.rawValue,
      "amount": updatedReceipt.amount,
      "taxAmount": updatedReceipt.taxAmount as Any,
      "description": updatedReceipt.description,
      "purchaseDate": Timestamp(date: updatedReceipt.purchaseDate),
      "receiptImageUrl": updatedReceipt.receiptImageUrl,
      "thumbnailUrl": updatedReceipt.thumbnailUrl as Any,
      "status": updatedReceipt.status.rawValue,
      "reviewedBy": updatedReceipt.reviewedBy as Any,
      "reviewedAt": updatedReceipt.reviewedAt.map { Timestamp(date: $0) } as Any,
      "reviewNotes": updatedReceipt.reviewNotes as Any,
      "reimbursedAt": updatedReceipt.reimbursedAt.map { Timestamp(date: $0) } as Any,
      "createdAt": Timestamp(date: updatedReceipt.createdAt),
      "updatedAt": Timestamp(date: updatedReceipt.updatedAt)
    ]
    
    try await db.collection("receipts").document(receipt.id).setData(receiptData)
    print("✅ [FirebaseClient] Receipt created successfully: \(receipt.id)")
  }
  
  func getReceipts(for issueId: String) async throws -> [Receipt] {
    print("🧾 [FirebaseClient] Fetching receipts for issue: \(issueId)")
    
    let snapshot = try await db.collection("receipts")
      .whereField("issueId", isEqualTo: issueId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return snapshot.documents.compactMap { doc in
      try? parseReceiptDocument(doc)
    }
  }
  
  func getReceiptsForRestaurant(_ restaurantId: String) async throws -> [Receipt] {
    print("🧾 [FirebaseClient] Fetching receipts for restaurant: \(restaurantId)")
    
    let snapshot = try await db.collection("receipts")
      .whereField("restaurantId", isEqualTo: restaurantId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return snapshot.documents.compactMap { doc in
      try? parseReceiptDocument(doc)
    }
  }
  
  func updateReceiptStatus(_ receiptId: String, status: ReceiptStatus, reviewedBy: String?, reviewNotes: String?) async throws {
    print("🧾 [FirebaseClient] Updating receipt status: \(receiptId) -> \(status.rawValue)")
    
    var updateData: [String: Any] = [
      "status": status.rawValue,
      "updatedAt": Timestamp(date: Date())
    ]
    
    if let reviewedBy = reviewedBy {
      updateData["reviewedBy"] = reviewedBy
      updateData["reviewedAt"] = Timestamp(date: Date())
    }
    
    if let reviewNotes = reviewNotes {
      updateData["reviewNotes"] = reviewNotes
    }
    
    if status == .reimbursed {
      updateData["reimbursedAt"] = Timestamp(date: Date())
    }
    
    try await db.collection("receipts").document(receiptId).updateData(updateData)
    print("✅ [FirebaseClient] Receipt status updated successfully")
  }
  
  private func parseReceiptDocument(_ document: QueryDocumentSnapshot) throws -> Receipt {
    let data = document.data()
    
    // Use document ID as fallback if the id field is empty
    let idFromData = data["id"] as? String ?? ""
    let effectiveId = idFromData.isEmpty ? document.documentID : idFromData
    
    guard !effectiveId.isEmpty,
          let issueId = data["issueId"] as? String,
          let restaurantId = data["restaurantId"] as? String,
          let submittedBy = data["submittedBy"] as? String,
          let vendor = data["vendor"] as? String,
          let categoryRaw = data["category"] as? String,
          let category = ReceiptCategory(rawValue: categoryRaw),
          let amount = data["amount"] as? Double,
          let description = data["description"] as? String,
          let purchaseDateTimestamp = data["purchaseDate"] as? Timestamp,
          let receiptImageUrl = data["receiptImageUrl"] as? String,
          let statusRaw = data["status"] as? String,
          let status = ReceiptStatus(rawValue: statusRaw),
          let createdAtTimestamp = data["createdAt"] as? Timestamp,
          let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
      print("❌ [parseReceiptDocument] Missing or empty required fields in document: \(document.documentID)")
      print("❌ [parseReceiptDocument] Available fields: \(data.keys.sorted())")
      print("❌ [parseReceiptDocument] id: '\(idFromData)', issueId: '\(data["issueId"] as? String ?? "nil")'")
      throw NSError(domain: "FirebaseClient", code: 1002, userInfo: [
        NSLocalizedDescriptionKey: "Failed to parse receipt document: \(document.documentID)"
      ])
    }
    
    return Receipt(
      id: effectiveId,
      issueId: issueId,
      workOrderId: data["workOrderId"] as? String,
      restaurantId: restaurantId,
      submittedBy: submittedBy,
      vendor: vendor,
      category: category,
      amount: amount,
      taxAmount: data["taxAmount"] as? Double,
      description: description,
      purchaseDate: purchaseDateTimestamp.dateValue(),
      receiptImageUrl: receiptImageUrl,
      thumbnailUrl: data["thumbnailUrl"] as? String,
      status: status,
      reviewedBy: data["reviewedBy"] as? String,
      reviewedAt: (data["reviewedAt"] as? Timestamp)?.dateValue(),
      reviewNotes: data["reviewNotes"] as? String,
      reimbursedAt: (data["reimbursedAt"] as? Timestamp)?.dateValue(),
      createdAt: createdAtTimestamp.dateValue(),
      updatedAt: updatedAtTimestamp.dateValue()
    )
  }
  
  // MARK: - Subscription Management
  func createSubscription(_ subscription: Subscription) async throws {
    print("💳 [FirebaseClient] Creating subscription: \(subscription.id)")
    
    let subscriptionData: [String: Any] = [
      "id": subscription.id,
      "restaurantId": subscription.restaurantId,
      "plan": subscription.plan.rawValue,
      "status": subscription.status.rawValue,
      "stripeSubscriptionId": subscription.stripeSubscriptionId as Any,
      "stripeCustomerId": subscription.stripeCustomerId as Any,
      "currentPeriodStart": Timestamp(date: subscription.currentPeriodStart),
      "currentPeriodEnd": Timestamp(date: subscription.currentPeriodEnd),
      "cancelAtPeriodEnd": subscription.cancelAtPeriodEnd,
      "cancelledAt": subscription.cancelledAt.map { Timestamp(date: $0) } as Any,
      "trialEnd": subscription.trialEnd.map { Timestamp(date: $0) } as Any,
      "issuesUsedThisMonth": subscription.issuesUsedThisMonth,
      "createdAt": Timestamp(date: subscription.createdAt),
      "updatedAt": Timestamp(date: subscription.updatedAt)
    ]
    
    try await db.collection("subscriptions").document(subscription.id).setData(subscriptionData)
    print("✅ [FirebaseClient] Subscription created successfully")
  }
  
  func getSubscription(for restaurantId: String) async throws -> Subscription? {
    print("💳 [FirebaseClient] Fetching subscription for restaurant: \(restaurantId)")
    
    let snapshot = try await db.collection("subscriptions")
      .whereField("restaurantId", isEqualTo: restaurantId)
      .limit(to: 1)
      .getDocuments()
    
    guard let document = snapshot.documents.first else {
      return nil
    }
    
    return try parseSubscriptionDocument(document)
  }
  
  func updateSubscription(_ subscription: Subscription) async throws {
    print("💳 [FirebaseClient] Updating subscription: \(subscription.id)")
    
    let subscriptionData: [String: Any] = [
      "plan": subscription.plan.rawValue,
      "status": subscription.status.rawValue,
      "stripeSubscriptionId": subscription.stripeSubscriptionId as Any,
      "stripeCustomerId": subscription.stripeCustomerId as Any,
      "currentPeriodStart": Timestamp(date: subscription.currentPeriodStart),
      "currentPeriodEnd": Timestamp(date: subscription.currentPeriodEnd),
      "cancelAtPeriodEnd": subscription.cancelAtPeriodEnd,
      "cancelledAt": subscription.cancelledAt.map { Timestamp(date: $0) } as Any,
      "trialEnd": subscription.trialEnd.map { Timestamp(date: $0) } as Any,
      "issuesUsedThisMonth": subscription.issuesUsedThisMonth,
      "updatedAt": Timestamp(date: Date())
    ]
    
    try await db.collection("subscriptions").document(subscription.id).updateData(subscriptionData)
    print("✅ [FirebaseClient] Subscription updated successfully")
  }
  
  func incrementIssueUsage(for restaurantId: String) async throws {
    print("💳 [FirebaseClient] Incrementing issue usage for restaurant: \(restaurantId)")
    
    let subscriptionRef = db.collection("subscriptions").whereField("restaurantId", isEqualTo: restaurantId)
    let snapshot = try await subscriptionRef.getDocuments()
    
    guard let document = snapshot.documents.first else {
      print("⚠️ [FirebaseClient] No subscription found for restaurant: \(restaurantId)")
      return
    }
    
    try await document.reference.updateData([
      "issuesUsedThisMonth": FieldValue.increment(Int64(1)),
      "updatedAt": Timestamp(date: Date())
    ])
    
    print("✅ [FirebaseClient] Issue usage incremented successfully")
  }
  
  private func parseSubscriptionDocument(_ document: QueryDocumentSnapshot) throws -> Subscription {
    let data = document.data()
    
    // Use document ID as fallback if the id field is empty
    let idFromData = data["id"] as? String ?? ""
    let effectiveId = idFromData.isEmpty ? document.documentID : idFromData
    
    guard !effectiveId.isEmpty,
          let restaurantId = data["restaurantId"] as? String,
          let planRaw = data["plan"] as? String,
          let plan = SubscriptionPlan(rawValue: planRaw),
          let statusRaw = data["status"] as? String,
          let status = SubscriptionStatus(rawValue: statusRaw),
          let currentPeriodStartTimestamp = data["currentPeriodStart"] as? Timestamp,
          let currentPeriodEndTimestamp = data["currentPeriodEnd"] as? Timestamp,
          let cancelAtPeriodEnd = data["cancelAtPeriodEnd"] as? Bool,
          let issuesUsedThisMonth = data["issuesUsedThisMonth"] as? Int,
          let createdAtTimestamp = data["createdAt"] as? Timestamp,
          let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
      print("❌ [parseSubscriptionDocument] Missing or empty required fields in document: \(document.documentID)")
      print("❌ [parseSubscriptionDocument] Available fields: \(data.keys.sorted())")
      print("❌ [parseSubscriptionDocument] id: '\(idFromData)'")
      throw NSError(domain: "FirebaseClient", code: 1003, userInfo: [
        NSLocalizedDescriptionKey: "Failed to parse subscription document: \(document.documentID)"
      ])
    }
    
    return Subscription(
      id: effectiveId,
      restaurantId: restaurantId,
      plan: plan,
      status: status,
      stripeSubscriptionId: data["stripeSubscriptionId"] as? String,
      stripeCustomerId: data["stripeCustomerId"] as? String,
      currentPeriodStart: currentPeriodStartTimestamp.dateValue(),
      currentPeriodEnd: currentPeriodEndTimestamp.dateValue(),
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      cancelledAt: (data["cancelledAt"] as? Timestamp)?.dateValue(),
      trialEnd: (data["trialEnd"] as? Timestamp)?.dateValue(),
      issuesUsedThisMonth: issuesUsedThisMonth,
      createdAt: createdAtTimestamp.dateValue(),
      updatedAt: updatedAtTimestamp.dateValue()
    )
  }
  
  // MARK: - Payment Management
  func createPayment(_ payment: Payment) async throws {
    print("💰 [FirebaseClient] Creating payment: \(payment.id)")
    
    let paymentData: [String: Any] = [
      "id": payment.id,
      "restaurantId": payment.restaurantId,
      "subscriptionId": payment.subscriptionId as Any,
      "amount": payment.amount,
      "currency": payment.currency,
      "status": payment.status.rawValue,
      "stripePaymentIntentId": payment.stripePaymentIntentId as Any,
      "stripeChargeId": payment.stripeChargeId as Any,
      "description": payment.description,
      "receiptUrl": payment.receiptUrl as Any,
      "failureReason": payment.failureReason as Any,
      "createdAt": Timestamp(date: payment.createdAt),
      "updatedAt": Timestamp(date: payment.updatedAt)
    ]
    
    try await db.collection("payments").document(payment.id).setData(paymentData)
    print("✅ [FirebaseClient] Payment created successfully")
  }
  
  func getPayments(for restaurantId: String) async throws -> [Payment] {
    print("💰 [FirebaseClient] Fetching payments for restaurant: \(restaurantId)")
    
    let snapshot = try await db.collection("payments")
      .whereField("restaurantId", isEqualTo: restaurantId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    return snapshot.documents.compactMap { doc in
      try? parsePaymentDocument(doc)
    }
  }
  
  func updatePaymentStatus(_ paymentId: String, status: PaymentStatus, stripeChargeId: String? = nil, receiptUrl: String? = nil, failureReason: String? = nil) async throws {
    print("💰 [FirebaseClient] Updating payment status: \(paymentId) -> \(status.rawValue)")
    
    var updateData: [String: Any] = [
      "status": status.rawValue,
      "updatedAt": Timestamp(date: Date())
    ]
    
    if let stripeChargeId = stripeChargeId {
      updateData["stripeChargeId"] = stripeChargeId
    }
    
    if let receiptUrl = receiptUrl {
      updateData["receiptUrl"] = receiptUrl
    }
    
    if let failureReason = failureReason {
      updateData["failureReason"] = failureReason
    }
    
    try await db.collection("payments").document(paymentId).updateData(updateData)
    print("✅ [FirebaseClient] Payment status updated successfully")
  }
  
  private func parsePaymentDocument(_ document: QueryDocumentSnapshot) throws -> Payment {
    let data = document.data()
    
    // Use document ID as fallback if the id field is empty
    let idFromData = data["id"] as? String ?? ""
    let effectiveId = idFromData.isEmpty ? document.documentID : idFromData
    
    guard !effectiveId.isEmpty,
          let restaurantId = data["restaurantId"] as? String,
          let amount = data["amount"] as? Double,
          let currency = data["currency"] as? String,
          let statusRaw = data["status"] as? String,
          let status = PaymentStatus(rawValue: statusRaw),
          let description = data["description"] as? String,
          let createdAtTimestamp = data["createdAt"] as? Timestamp,
          let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
      print("❌ [parsePaymentDocument] Missing or empty required fields in document: \(document.documentID)")
      print("❌ [parsePaymentDocument] Available fields: \(data.keys.sorted())")
      print("❌ [parsePaymentDocument] id: '\(idFromData)'")
      throw NSError(domain: "FirebaseClient", code: 1004, userInfo: [
        NSLocalizedDescriptionKey: "Failed to parse payment document: \(document.documentID)"
      ])
    }

    return Payment(
      id: effectiveId,
      restaurantId: restaurantId,
      subscriptionId: data["subscriptionId"] as? String,
      amount: amount,
      currency: currency,
      status: status,
      stripePaymentIntentId: data["stripePaymentIntentId"] as? String,
      stripeChargeId: data["stripeChargeId"] as? String,
      description: description,
      receiptUrl: data["receiptUrl"] as? String,
      failureReason: data["failureReason"] as? String,
      createdAt: createdAtTimestamp.dateValue(),
      updatedAt: updatedAtTimestamp.dateValue()
    )
  }
  
  // MARK: - Diagnostic Functions
  
  func diagnoseConversationIssueMapping() async throws {
    print("🔍 [DiagnosticTool] ===== CONVERSATION-ISSUE MAPPING DIAGNOSIS =====")
    
    // Get all conversations
    let conversationsSnapshot = try await db.collection("conversations").getDocuments()
    print("🔍 [DiagnosticTool] Found \(conversationsSnapshot.documents.count) conversations")
    
    // Get all issues
    let issuesSnapshot = try await db.collection("issues").getDocuments()
    print("🔍 [DiagnosticTool] Found \(issuesSnapshot.documents.count) issues")
    
    let issueIds = Set(issuesSnapshot.documents.compactMap { $0.data()["id"] as? String })
    print("🔍 [DiagnosticTool] Issue IDs in database: \(Array(issueIds).prefix(10))...")
    
    var orphanedConversations = 0
    var validConversations = 0
    var fixedConversations = 0
    
    for doc in conversationsSnapshot.documents {
      let data = doc.data()
      if let conversationIssueId = data["issueId"] as? String,
         let title = data["title"] as? String {
        
        if issueIds.contains(conversationIssueId) {
          validConversations += 1
          print("✅ [DiagnosticTool] Valid: \(conversationIssueId) -> \(title.prefix(50))")
        } else {
          orphanedConversations += 1
          print("❌ [DiagnosticTool] Orphaned: \(conversationIssueId) -> \(title.prefix(50))")
          
          // Try to find matching issue by title with improved matching
          let matchingIssue = findBestMatchingIssue(
            conversationTitle: title,
            allIssues: issuesSnapshot.documents
          )
          
          if let matchingIssue = matchingIssue,
             let matchingIssueId = matchingIssue.data()["id"] as? String,
             let matchingTitle = matchingIssue.data()["title"] as? String {
            print("🔗 [DiagnosticTool] Found match: \(matchingIssueId) -> \(matchingTitle.prefix(50))")
            
            // Auto-fix the orphaned conversation
            do {
              try await db.collection("conversations").document(doc.documentID).updateData([
                "issueId": matchingIssueId
              ])
              fixedConversations += 1
              print("✅ [DiagnosticTool] Fixed conversation \(doc.documentID) -> \(matchingIssueId)")
            } catch {
              print("❌ [DiagnosticTool] Failed to fix conversation \(doc.documentID): \(error)")
            }
          } else {
            print("❌ [DiagnosticTool] No suitable match found for: \(title.prefix(50))")
          }
        }
      }
    }
    
    print("🔍 [DiagnosticTool] Summary:")
    print("🔍 [DiagnosticTool] - Valid conversations: \(validConversations)")
    print("🔍 [DiagnosticTool] - Orphaned conversations: \(orphanedConversations)")
    print("🔍 [DiagnosticTool] - Fixed conversations: \(fixedConversations)")
    print("🔍 [DiagnosticTool] ===== DIAGNOSIS COMPLETE =====")
  }
  
  private func findBestMatchingIssue(conversationTitle: String, allIssues: [QueryDocumentSnapshot]) -> QueryDocumentSnapshot? {
    let searchText = conversationTitle.lowercased()
    
    // Extract key words from conversation title (remove common words)
    let commonWords = Set(["the", "image", "shows", "depicts", "a", "an", "is", "are", "with", "of", "in", "on", "at", "to", "for", "and", "or", "but"])
    let titleWords = searchText.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
      .filter { !$0.isEmpty && !commonWords.contains($0) && $0.count > 2 }
    
    print("🔍 [DiagnosticTool] Key words from conversation: \(titleWords)")
    
    var bestMatch: QueryDocumentSnapshot?
    var bestScore = 0
    
    for issueDoc in allIssues {
      let issueData = issueDoc.data()
      let issueTitle = (issueData["title"] as? String ?? "").lowercased()
      let issueDesc = (issueData["description"] as? String ?? "").lowercased()
      let combinedText = "\(issueTitle) \(issueDesc)"
      
      var score = 0
      
      // Score based on word matches
      for word in titleWords {
        if combinedText.contains(word) {
          score += word.count // Longer words get higher scores
        }
      }
      
      // Bonus for exact phrase matches
      if titleWords.count >= 3 {
        let phrase = titleWords.prefix(3).joined(separator: " ")
        if combinedText.contains(phrase) {
          score += 20
        }
      }
      
      if score > bestScore && score >= 10 { // Minimum threshold
        bestScore = score
        bestMatch = issueDoc
        print("🔍 [DiagnosticTool] New best match (score: \(score)): \(issueTitle.prefix(50))")
      }
    }
    
    return bestMatch
  }
  
  // MARK: - Document Management
  
  /// Upload file data to Firebase Storage
  func uploadFile(data: Data, path: String) async throws -> String {
    let storageRef = Storage.storage().reference().child(path)
    
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    
    let _ = try await storageRef.putDataAsync(data, metadata: metadata)
    let downloadURL = try await storageRef.downloadURL()
    
    return downloadURL.absoluteString
  }
  
  /// Save document to Firestore
  func saveDocument(_ document: IssueDocument) async throws {
    let docRef = db.collection("documents").document(document.id)
    try await docRef.setData(document.toDictionary())
    
    print("✅ [FirebaseClient] Document saved: \(document.id)")
  }
  
  /// Fetch documents for an issue
  func fetchDocuments(for issueId: String) async throws -> [IssueDocument] {
    let snapshot = try await db.collection("documents")
      .whereField("issue_id", isEqualTo: issueId)
      .order(by: "uploaded_at", descending: true)
      .getDocuments()
    
    return snapshot.documents.compactMap { IssueDocument(dictionary: $0.data()) }
  }
  
  /// Delete a document
  func deleteDocument(_ documentId: String) async throws {
    try await db.collection("documents").document(documentId).delete()
    print("✅ [FirebaseClient] Document deleted: \(documentId)")
  }
  
  // MARK: - Waitlist Management
  
  /// Submit a waitlist entry for service expansion
  func submitWaitlistEntry(
    businessName: String,
    email: String,
    phoneNumber: String?,
    location: String
  ) async throws {
    print("📋 [FirebaseClient] Submitting waitlist entry for: \(businessName)")
    
    let waitlistId = UUID().uuidString
    let currentUserId = Auth.auth().currentUser?.uid
    
    let waitlistData: [String: Any] = [
      "id": waitlistId,
      "businessName": businessName,
      "email": email,
      "phoneNumber": phoneNumber ?? NSNull(),
      "location": location,
      "userId": currentUserId ?? NSNull(),
      "status": "pending",
      "createdAt": Timestamp(date: Date()),
      "notified": false
    ]
    
    try await db.collection("waitlist").document(waitlistId).setData(waitlistData)
    
    print("✅ [FirebaseClient] Waitlist entry created: \(waitlistId)")
  }
  
  // MARK: - Support Messages
  
  /// Create a new support message
  func createSupportMessage(_ message: SupportMessage) async throws {
    print("💬 [FirebaseClient] Creating support message: \(message.id)")
    
    let messageData: [String: Any] = [
      "id": message.id,
      "userId": message.userId,
      "userName": message.userName,
      "userEmail": message.userEmail ?? NSNull(),
      "category": message.category.rawValue,
      "subject": message.subject,
      "message": message.message,
      "status": message.status.rawValue,
      "adminNotes": message.adminNotes ?? NSNull(),
      "respondedBy": message.respondedBy ?? NSNull(),
      "respondedAt": message.respondedAt.map { Timestamp(date: $0) } ?? NSNull(),
      "createdAt": Timestamp(date: message.createdAt),
      "updatedAt": Timestamp(date: message.updatedAt)
    ]
    
    try await db.collection("supportMessages").document(message.id).setData(messageData)
    
    print("✅ [FirebaseClient] Support message created: \(message.id)")
  }
  
  /// Fetch all support messages (admin only)
  func fetchAllSupportMessages() async throws -> [SupportMessage] {
    print("📥 [FirebaseClient] Fetching all support messages")
    
    let snapshot = try await db.collection("supportMessages")
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    let messages = try snapshot.documents.compactMap { doc -> SupportMessage? in
      let data = doc.data()
      
      guard let id = data["id"] as? String,
            let userId = data["userId"] as? String,
            let userName = data["userName"] as? String,
            let categoryRaw = data["category"] as? String,
            let category = SupportCategory(rawValue: categoryRaw),
            let subject = data["subject"] as? String,
            let message = data["message"] as? String,
            let statusRaw = data["status"] as? String,
            let status = SupportMessageStatus(rawValue: statusRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
        print("⚠️ [FirebaseClient] Failed to parse support message: \(doc.documentID)")
        return nil
      }
      
      let userEmail = data["userEmail"] as? String
      let adminNotes = data["adminNotes"] as? String
      let respondedBy = data["respondedBy"] as? String
      let respondedAt = (data["respondedAt"] as? Timestamp)?.dateValue()
      
      return SupportMessage(
        id: id,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        category: category,
        subject: subject,
        message: message,
        status: status,
        adminNotes: adminNotes,
        respondedBy: respondedBy,
        respondedAt: respondedAt,
        createdAt: createdAtTimestamp.dateValue(),
        updatedAt: updatedAtTimestamp.dateValue()
      )
    }
    
    print("✅ [FirebaseClient] Fetched \(messages.count) support messages")
    return messages
  }
  
  /// Update support message status and admin notes
  func updateSupportMessage(
    messageId: String,
    status: SupportMessageStatus,
    adminNotes: String?,
    respondedBy: String?
  ) async throws {
    print("🔄 [FirebaseClient] Updating support message: \(messageId)")
    
    var updateData: [String: Any] = [
      "status": status.rawValue,
      "updatedAt": Timestamp(date: Date())
    ]
    
    if let adminNotes = adminNotes {
      updateData["adminNotes"] = adminNotes
    }
    
    if let respondedBy = respondedBy {
      updateData["respondedBy"] = respondedBy
      updateData["respondedAt"] = Timestamp(date: Date())
    }
    
    try await db.collection("supportMessages").document(messageId).updateData(updateData)
    
    print("✅ [FirebaseClient] Support message updated: \(messageId)")
  }
  
  /// Fetch support messages for a specific user
  func fetchUserSupportMessages(userId: String) async throws -> [SupportMessage] {
    print("📥 [FirebaseClient] Fetching support messages for user: \(userId)")
    
    let snapshot = try await db.collection("supportMessages")
      .whereField("userId", isEqualTo: userId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    let messages = try snapshot.documents.compactMap { doc -> SupportMessage? in
      let data = doc.data()
      
      guard let id = data["id"] as? String,
            let userId = data["userId"] as? String,
            let userName = data["userName"] as? String,
            let categoryRaw = data["category"] as? String,
            let category = SupportCategory(rawValue: categoryRaw),
            let subject = data["subject"] as? String,
            let message = data["message"] as? String,
            let statusRaw = data["status"] as? String,
            let status = SupportMessageStatus(rawValue: statusRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
        return nil
      }
      
      let userEmail = data["userEmail"] as? String
      let adminNotes = data["adminNotes"] as? String
      let respondedBy = data["respondedBy"] as? String
      let respondedAt = (data["respondedAt"] as? Timestamp)?.dateValue()
      
      return SupportMessage(
        id: id,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        category: category,
        subject: subject,
        message: message,
        status: status,
        adminNotes: adminNotes,
        respondedBy: respondedBy,
        respondedAt: respondedAt,
        createdAt: createdAtTimestamp.dateValue(),
        updatedAt: updatedAtTimestamp.dateValue()
      )
    }
    
    print("✅ [FirebaseClient] Fetched \(messages.count) support messages for user")
    return messages
  }
  
  // MARK: - Invoices
  
  /// Create a new invoice
  func createInvoice(_ invoice: Invoice) async throws {
    print("📝 [FirebaseClient] Creating invoice: \(invoice.invoiceNumber)")
    
    let encoder = Firestore.Encoder()
    let data = try encoder.encode(invoice)
    
    try await db.collection("invoices").document(invoice.id).setData(data)
    print("✅ [FirebaseClient] Invoice created successfully")
  }
  
  /// Update an existing invoice
  func updateInvoice(_ invoice: Invoice) async throws {
    print("📝 [FirebaseClient] Updating invoice: \(invoice.invoiceNumber)")
    
    let encoder = Firestore.Encoder()
    var data = try encoder.encode(invoice)
    data["updatedAt"] = Timestamp(date: Date())
    
    try await db.collection("invoices").document(invoice.id).updateData(data)
    print("✅ [FirebaseClient] Invoice updated successfully")
  }
  
  /// Fetch invoices for a specific issue
  func fetchInvoices(issueId: String) async throws -> [Invoice] {
    print("📥 [FirebaseClient] Fetching invoices for issue: \(issueId)")
    
    let snapshot = try await db.collection("invoices")
      .whereField("issueId", isEqualTo: issueId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    let decoder = Firestore.Decoder()
    let invoices = try snapshot.documents.compactMap { doc -> Invoice? in
      try? decoder.decode(Invoice.self, from: doc.data())
    }
    
    print("✅ [FirebaseClient] Fetched \(invoices.count) invoices")
    return invoices
  }
  
  /// Fetch all invoices for a business
  func fetchBusinessInvoices(businessId: String) async throws -> [Invoice] {
    print("📥 [FirebaseClient] Fetching invoices for business: \(businessId)")
    
    let snapshot = try await db.collection("invoices")
      .whereField("businessId", isEqualTo: businessId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    let decoder = Firestore.Decoder()
    let invoices = try snapshot.documents.compactMap { doc -> Invoice? in
      try? decoder.decode(Invoice.self, from: doc.data())
    }
    
    print("✅ [FirebaseClient] Fetched \(invoices.count) invoices for business")
    return invoices
  }
  
  /// Get a single invoice by ID
  func getInvoice(_ invoiceId: String) async throws -> Invoice {
    print("📥 [FirebaseClient] Fetching invoice: \(invoiceId)")
    
    let document = try await db.collection("invoices").document(invoiceId).getDocument()
    
    guard document.exists else {
      throw NSError(domain: "FirebaseClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invoice not found"])
    }
    
    let decoder = Firestore.Decoder()
    let invoice = try document.data(as: Invoice.self, decoder: decoder)
    
    print("✅ [FirebaseClient] Invoice fetched successfully: \(invoice.invoiceNumber)")
    return invoice
  }
  
  /// Upload invoice PDF to Firebase Storage
  func uploadInvoicePDF(_ pdfData: Data, invoiceId: String) async throws -> String {
    print("📤 [FirebaseClient] Uploading invoice PDF for: \(invoiceId)")
    
    let storageRef = storage.reference()
    let pdfRef = storageRef.child("invoices/\(invoiceId)/invoice.pdf")
    
    let metadata = StorageMetadata()
    metadata.contentType = "application/pdf"
    
    _ = try await pdfRef.putDataAsync(pdfData, metadata: metadata)
    let downloadURL = try await pdfRef.downloadURL()
    
    print("✅ [FirebaseClient] Invoice PDF uploaded successfully")
    return downloadURL.absoluteString
  }
  
  /// Fetch receipts for an issue (for invoice line items)
  func fetchReceipts(issueId: String) async throws -> [Receipt] {
    print("📥 [FirebaseClient] Fetching receipts for issue: \(issueId)")
    
    let snapshot = try await db.collection("receipts")
      .whereField("issueId", isEqualTo: issueId)
      .order(by: "createdAt", descending: true)
      .getDocuments()
    
    let decoder = Firestore.Decoder()
    let receipts = try snapshot.documents.compactMap { doc -> Receipt? in
      try? decoder.decode(Receipt.self, from: doc.data())
    }
    
    print("✅ [FirebaseClient] Fetched \(receipts.count) receipts")
    return receipts
  }
}
