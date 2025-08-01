import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class MaintenanceServiceV2: ObservableObject {
  static let shared = MaintenanceServiceV2()
  
  private let db = Firestore.firestore()
  private let storage = Storage.storage()
  
  // MARK: - Collection/Path Names
  private let requestsCol = "maintenance_requests"
  private func requestDoc(_ id: String) -> DocumentReference { db.collection(requestsCol).document(id) }
  private func photosCol(_ requestId: String) -> CollectionReference { requestDoc(requestId).collection("photos") }
  private func updatesCol(_ requestId: String) -> CollectionReference { requestDoc(requestId).collection("updates") }
  
  // MARK: - Create Request
  func createRequest(_ request: MaintenanceRequest, images: [UIImage]) async throws {
    print("🔥 [MaintenanceServiceV2] ===== CREATE REQUEST STARTED =====")
    print("🔥 [MaintenanceServiceV2] Request ID: \(request.id)")
    print("🔥 [MaintenanceServiceV2] Business ID: \(request.businessId)")
    print("🔥 [MaintenanceServiceV2] Reporter ID: \(request.reporterId)")
    print("🔥 [MaintenanceServiceV2] Title: \(request.title)")
    print("🔥 [MaintenanceServiceV2] Images count: \(images.count)")
    
    guard let currentUser = Auth.auth().currentUser else {
      print("❌ [MaintenanceServiceV2] No authenticated user")
      throw NSError(domain: "MaintenanceServiceV2", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }
    print("✅ [MaintenanceServiceV2] Authenticated user: \(currentUser.uid)")
    print("✅ [MaintenanceServiceV2] User email: \(currentUser.email ?? "NO EMAIL")")
    
    guard !images.isEmpty else {
      print("❌ [MaintenanceServiceV2] No images provided")
      throw NSError(domain: "MaintenanceServiceV2", code: 1001, userInfo: [NSLocalizedDescriptionKey: "At least one photo is required"])
    }
    
    // 1) Upload photos to Storage
    print("📸 [MaintenanceServiceV2] Starting photo uploads...")
    var photoUrls: [String] = []
    var photoDocIds: [String] = []
    for (idx, img) in images.enumerated() {
      print("📸 [MaintenanceServiceV2] Processing photo \(idx + 1)/\(images.count)...")
      guard let data = img.jpegData(compressionQuality: 0.85) else { 
        print("❌ [MaintenanceServiceV2] Failed to convert image \(idx) to JPEG")
        continue 
      }
      let path = "maintenance-photos/\(request.id)/photo_\(idx).jpg"
      let ref = storage.reference().child(path)
      print("📤 [MaintenanceServiceV2] Uploading to: \(path)")
      _ = try await ref.putDataAsync(data, metadata: nil)
      let url = try await ref.downloadURL().absoluteString
      photoUrls.append(url)
      print("✅ [MaintenanceServiceV2] Photo \(idx) uploaded: \(url)")
      
      // Create photo doc in subcollection
      let photoDoc = photosCol(request.id).document()
      print("📝 [MaintenanceServiceV2] Creating photo document: \(photoDoc.documentID)")
      try await photoDoc.setData([
        "id": photoDoc.documentID,
        "requestId": request.id,
        "url": url,
        "thumbUrl": url,
        "uploaderId": currentUser.uid,
        "takenAt": Timestamp(date: Date())
      ])
      photoDocIds.append(photoDoc.documentID)
      print("✅ [MaintenanceServiceV2] Photo document created")
    }
    print("✅ [MaintenanceServiceV2] All \(photoUrls.count) photos uploaded successfully")
    
    // 2) Create request document
    var data: [String: Any] = [
      "id": request.id,
      "businessId": request.businessId,
      "locationId": request.locationId ?? NSNull(),
      "reporterId": request.reporterId,
      "assigneeId": request.assigneeId ?? NSNull(),
      "title": request.title,
      "description": request.description,
      "category": request.category.rawValue,
      "priority": request.priority.rawValue,
      "status": request.status.rawValue,
      "photoUrls": photoUrls,
      "createdAt": Timestamp(date: request.createdAt),
      "updatedAt": Timestamp(date: request.updatedAt)
    ]
    
    if let ai = request.aiAnalysis {
      let enc = try JSONEncoder().encode(ai)
      data["aiAnalysis"] = String(data: enc, encoding: .utf8)
    }
    if let estCost = request.estimatedCost { data["estimatedCost"] = estCost }
    if let estTime = request.estimatedTime { data["estimatedTime"] = estTime }
    if let scheduled = request.scheduledAt { data["scheduledAt"] = Timestamp(date: scheduled) }
    if let started = request.startedAt { data["startedAt"] = Timestamp(date: started) }
    if let completed = request.completedAt { data["completedAt"] = Timestamp(date: completed) }
    if let q = request.quotedCost { data["quotedCost"] = q }
    if let a = request.actualCost { data["actualCost"] = a }
    
    print("📝 [MaintenanceServiceV2] Creating request document in Firestore...")
    print("📝 [MaintenanceServiceV2] Collection: \(requestsCol)")
    print("📝 [MaintenanceServiceV2] Document ID: \(request.id)")
    try await requestDoc(request.id).setData(data)
    print("✅ [MaintenanceServiceV2] Request document created successfully")
    do {
      let adminIds = try await FirebaseClient.shared.getAdminUserIds(adminEmails: AdminConfig.adminEmails)
      if !adminIds.isEmpty {
        try? await FirebaseClient.shared.sendNotificationTrigger(
          userIds: adminIds,
          title: "New Issue",
          body: request.title,
          data: [
            "type": "issue_created",
            "issueId": request.id,
            "businessId": request.businessId
          ]
        )
      }
    } catch {
    }
    print("✅ [MaintenanceServiceV2] ===== CREATE REQUEST COMPLETE =====")
  }
  
  // MARK: - Listing
  func listRequests(businessId: String? = nil, reporterId: String? = nil, status: RequestStatus? = nil, createdAfter: Date? = nil) async throws -> [MaintenanceRequest] {
    var query: Query = db.collection(requestsCol).order(by: "createdAt", descending: true)
    if let businessId { query = query.whereField("businessId", isEqualTo: businessId) }
    if let reporterId { query = query.whereField("reporterId", isEqualTo: reporterId) }
    if let status { query = query.whereField("status", isEqualTo: status.rawValue) }
    if let createdAfter { query = query.whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: createdAfter)) }
    
    let snap = try await query.getDocuments()
    return snap.documents.compactMap { parseRequest(doc: $0) }
  }
  
  // MARK: - Status Updates
  func updateStatus(requestId: String, to newStatus: RequestStatus) async throws {
    // Get old status first
    let snap = try await requestDoc(requestId).getDocument()
    guard let data = snap.data(),
          let oldStatusRaw = data["status"] as? String,
          let oldStatus = RequestStatus(rawValue: oldStatusRaw) else {
      throw NSError(domain: "MaintenanceServiceV2", code: 404, userInfo: nil)
    }
    
    // Update status
    try await requestDoc(requestId).updateData([
      "status": newStatus.rawValue,
      "updatedAt": Timestamp(date: Date())
    ])
    
    // Send notification if status actually changed
    if oldStatus != newStatus {
      await sendStatusChangeNotification(
        requestId: requestId,
        oldStatus: oldStatus,
        newStatus: newStatus
      )
    }
  }
  
  private func sendStatusChangeNotification(
    requestId: String,
    oldStatus: RequestStatus,
    newStatus: RequestStatus
  ) async {
    // Fetch the request document
    guard let snap = try? await requestDoc(requestId).getDocument(),
          let request = parseRequest(doc: snap) else { return }
    
    // Get all participants
    var recipients: Set<String> = [request.reporterId]
    
    // Add admin users
    if let adminIds = try? await FirebaseClient.shared.getAdminUserIds(adminEmails: AdminConfig.adminEmails) {
      recipients.formUnion(adminIds)
    }
    
    // Remove current user
    if let currentUserId = Auth.auth().currentUser?.uid {
      recipients.remove(currentUserId)
    }
    
    // Get restaurant name (resolve from businessId if needed)
    let restaurantName = request.businessId
    
    await NotificationService.shared.sendIssueStatusChangeNotification(
      to: Array(recipients),
      issueTitle: request.title,
      restaurantName: restaurantName,
      oldStatus: oldStatus.rawValue,
      newStatus: newStatus.rawValue,
      issueId: requestId,
      updatedBy: Auth.auth().currentUser?.displayName ?? "Someone"
    )
  }
  
  // MARK: - Updates (Work Logs)
  func addUpdate(_ update: RequestUpdate) async throws {
    try await updatesCol(update.requestId).document(update.id).setData([
      "id": update.id,
      "requestId": update.requestId,
      "authorId": update.authorId,
      "message": update.message,
      "createdAt": Timestamp(date: update.createdAt)
    ])
  }
  
  func fetchUpdates(requestId: String) async throws -> [RequestUpdate] {
    let snap = try await updatesCol(requestId).order(by: "createdAt", descending: false).getDocuments()
    return snap.documents.compactMap { doc in
      let data = doc.data()
      guard let id = data["id"] as? String,
            let requestId = data["requestId"] as? String,
            let authorId = data["authorId"] as? String,
            let message = data["message"] as? String,
            let createdAtTs = data["createdAt"] as? Timestamp else { return nil }
      return RequestUpdate(id: id, requestId: requestId, authorId: authorId, message: message, createdAt: createdAtTs.dateValue())
    }
  }
  
  // MARK: - Photos
  func uploadPhoto(requestId: String, image: UIImage) async throws -> MaintenancePhoto {
    guard let data = image.jpegData(compressionQuality: 0.85) else {
      throw NSError(domain: "MaintenanceServiceV2", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
    }
    let photoId = UUID().uuidString
    let path = "maintenance-photos/\(requestId)/\(photoId).jpg"
    let ref = storage.reference().child(path)
    _ = try await ref.putDataAsync(data, metadata: nil)
    let url = try await ref.downloadURL().absoluteString
    
    let doc = photosCol(requestId).document(photoId)
    try await doc.setData([
      "id": photoId,
      "requestId": requestId,
      "url": url,
      "takenAt": Timestamp(date: Date())
    ])
    
    return MaintenancePhoto(id: photoId, requestId: requestId, url: url, thumbUrl: url, takenAt: Date())
  }
  
  func fetchPhotos(requestId: String) async throws -> [MaintenancePhoto] {
    let snap = try await photosCol(requestId).order(by: "takenAt", descending: false).getDocuments()
    return snap.documents.compactMap { doc in
      let data = doc.data()
      guard let id = data["id"] as? String,
            let url = data["url"] as? String,
            let takenAtTs = data["takenAt"] as? Timestamp else { return nil }
      return MaintenancePhoto(id: id, requestId: requestId, url: url, thumbUrl: data["thumbUrl"] as? String, takenAt: takenAtTs.dateValue())
    }
  }
  
  // MARK: - Helpers
  private func parseRequest(doc: DocumentSnapshot) -> MaintenanceRequest? {
    let d = doc.data() ?? [:]
    guard let id = d["id"] as? String,
          let businessId = d["businessId"] as? String,
          let reporterId = d["reporterId"] as? String,
          let title = d["title"] as? String,
          let description = d["description"] as? String,
          let categoryRaw = d["category"] as? String,
          let category = MaintenanceCategory(rawValue: categoryRaw),
          let priorityRaw = d["priority"] as? String,
          let priority = MaintenancePriority(rawValue: priorityRaw),
          let statusRaw = d["status"] as? String,
          let status = RequestStatus(rawValue: statusRaw),
          let createdAtTs = d["createdAt"] as? Timestamp,
          let updatedAtTs = d["updatedAt"] as? Timestamp else { return nil }
    
    var ai: AIAnalysis? = nil
    if let aiStr = d["aiAnalysis"] as? String, let data = aiStr.data(using: .utf8) {
      ai = try? JSONDecoder().decode(AIAnalysis.self, from: data)
    }
    
    return MaintenanceRequest(
      id: id,
      businessId: businessId,
      locationId: d["locationId"] as? String,
      reporterId: reporterId,
      assigneeId: d["assigneeId"] as? String,
      title: title,
      description: description,
      category: category,
      priority: priority,
      status: status,
      aiAnalysis: ai,
      estimatedCost: d["estimatedCost"] as? Double,
      estimatedTime: d["estimatedTime"] as? String,
      photoUrls: d["photoUrls"] as? [String],
      scheduledAt: (d["scheduledAt"] as? Timestamp)?.dateValue(),
      startedAt: (d["startedAt"] as? Timestamp)?.dateValue(),
      completedAt: (d["completedAt"] as? Timestamp)?.dateValue(),
      quotedCost: d["quotedCost"] as? Double,
      actualCost: d["actualCost"] as? Double,
      createdAt: createdAtTs.dateValue(),
      updatedAt: updatedAtTs.dateValue()
    )
  }
}
