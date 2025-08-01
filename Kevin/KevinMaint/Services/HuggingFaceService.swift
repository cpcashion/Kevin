import Foundation
import UIKit

class HuggingFaceService {
    static let shared = HuggingFaceService()
    private init() {}
    
    // Your deployed Cloudflare Worker URL
    private let proxyURL = "https://kevin-ai-worker.kevin-app.workers.dev"
    
    func analyzeMaintenanceImage(_ image: UIImage, ocrText: String? = nil) async throws -> MaintenanceIssue {
        print("🔍 Starting FREE Hugging Face AI analysis...")
        
        // Try real API call with retry logic
        for attempt in 1...2 {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw AIError.imageProcessingFailed
                }
                
                print("🔄 Attempt \(attempt)/2 to reach worker...")
                let result = try await callProxyAPI(imageData: imageData, ocrText: ocrText)
                print("✅ Worker API success on attempt \(attempt)!")
                return result
            } catch {
                print("❌ Attempt \(attempt) failed: \(error)")
                if attempt == 2 {
                    print("🔄 All attempts failed. Using enhanced fallback analysis.")
                    break
                }
                // Wait 1 second before retry
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        // Use enhanced fallback
        return try await simulateHuggingFaceAnalysis(image: image, ocrText: ocrText)
    }
    
    private func simulateHuggingFaceAnalysis(image: UIImage, ocrText: String?) async throws -> MaintenanceIssue {
        // No mock data - force real implementation
        throw AIError.apiRequestFailed
    }
    
    // This will be used when you set up the Cloudflare Worker proxy
    private func callProxyAPI(imageData: Data, ocrText: String?) async throws -> MaintenanceIssue {
        guard let url = URL(string: "\(proxyURL)/analyze") else {
            throw AIError.apiRequestFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add OCR text if available
        if let ocrText = ocrText, !ocrText.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"ocrText\"\r\n\r\n".data(using: .utf8)!)
            body.append(ocrText.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        print("🌐 Calling worker at: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw AIError.apiRequestFailed
            }
            
            print("📡 Worker response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Worker response: \(responseString.prefix(200))...")
            }
            
            if httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(MaintenanceIssue.self, from: data)
            } else {
                // Worker returned error response, but it might still be valid JSON
                if let errorResponse = try? JSONDecoder().decode(MaintenanceIssue.self, from: data) {
                    print("⚠️ Worker returned error analysis, using it anyway")
                    return errorResponse
                }
                throw AIError.apiRequestFailed
            }
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }
}
