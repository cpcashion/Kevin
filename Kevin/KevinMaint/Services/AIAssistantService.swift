import Foundation
import UIKit

/// Service for managing AI Assistant conversations using OpenAI Assistants API
class AIAssistantService: ObservableObject {
    static let shared = AIAssistantService()
    
    @Published var isProcessing = false
    @Published var error: Error?
    
    private let baseURL = "https://api.openai.com/v1"
    private let apiKey = APIKeys.openAIAPIKey
    
    // Assistant ID - created once and reused
    private var assistantId: String?
    
    // Thread ID cache - one thread per work order
    private var threadCache: [String: String] = [:] // workOrderId -> threadId
    
    private init() {}
    
    // MARK: - Assistant Management
    
    /// Get or create the Kevin AI assistant
    func getOrCreateAssistant() async throws -> String {
        if let existingId = assistantId {
            return existingId
        }
        
        // Check UserDefaults for cached assistant ID
        if let cachedId = UserDefaults.standard.string(forKey: "kevin_assistant_id") {
            print("✅ Using cached assistant ID: \(cachedId)")
            self.assistantId = cachedId
            return cachedId
        }
        
        // Create new assistant
        print("🤖 Creating new Kevin AI assistant...")
        
        let payload: [String: Any] = [
            "name": "Kevin AI",
            "instructions": assistantInstructions,
            "tools": functionTools,
            "model": "gpt-4o"
        ]
        
        let url = URL(string: "\(baseURL)/assistants")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Failed to create assistant: \(String(data: data, encoding: .utf8) ?? "unknown error")")
            throw AIError.apiRequestFailed
        }
        
        let result = try JSONDecoder().decode(AssistantResponse.self, from: data)
        print("✅ Created assistant: \(result.id)")
        
        // Cache the assistant ID
        UserDefaults.standard.set(result.id, forKey: "kevin_assistant_id")
        self.assistantId = result.id
        
        return result.id
    }
    
    // MARK: - Thread Management
    
    /// Get or create a conversation thread for a work order
    func getOrCreateThread(for workOrderId: String, context: WorkOrderContext) async throws -> String {
        // Check cache first
        if let existingThreadId = threadCache[workOrderId] {
            print("✅ Using cached thread: \(existingThreadId)")
            return existingThreadId
        }
        
        // Check Firestore for existing thread
        if let storedThreadId = try? await fetchThreadId(for: workOrderId) {
            print("✅ Using stored thread: \(storedThreadId)")
            threadCache[workOrderId] = storedThreadId
            return storedThreadId
        }
        
        // Create new thread
        print("🧵 Creating new thread for work order: \(workOrderId)")
        
        let payload: [String: Any] = [
            "metadata": [
                "workOrderId": workOrderId,
                "locationId": context.locationId,
                "locationName": context.locationName
            ]
        ]
        
        let url = URL(string: "\(baseURL)/threads")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Failed to create thread: \(String(data: data, encoding: .utf8) ?? "unknown error")")
            throw AIError.apiRequestFailed
        }
        
        let result = try JSONDecoder().decode(ThreadResponse.self, from: data)
        print("✅ Created thread: \(result.id)")
        
        // Cache and store the thread ID
        threadCache[workOrderId] = result.id
        try? await storeThreadId(result.id, for: workOrderId)
        
        return result.id
    }
    
    // MARK: - Message Management
    
    /// Add a message to the thread
    func addMessage(threadId: String, content: String, role: String = "user") async throws {
        print("💬 Adding message to thread: \(threadId)")
        
        let payload: [String: Any] = [
            "role": role,
            "content": content
        ]
        
        let url = URL(string: "\(baseURL)/threads/\(threadId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Failed to add message: \(String(data: data, encoding: .utf8) ?? "unknown error")")
            throw AIError.apiRequestFailed
        }
        
        print("✅ Message added successfully")
    }
    
    /// Run the assistant on a thread and get response
    func runAssistant(threadId: String, assistantId: String, context: WorkOrderContext) async throws -> String {
        print("🏃 Running assistant on thread: \(threadId)")
        
        await MainActor.run {
            self.isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        // Add context as a system message
        let contextSummary = context.generateContextSummary()
        
        let payload: [String: Any] = [
            "assistant_id": assistantId,
            "additional_instructions": """
            Current work order context:
            
            \(contextSummary)
            
            Based on this context, provide helpful assistance to the admin user.
            """
        ]
        
        let url = URL(string: "\(baseURL)/threads/\(threadId)/runs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Failed to run assistant: \(String(data: data, encoding: .utf8) ?? "unknown error")")
            throw AIError.apiRequestFailed
        }
        
        let runResponse = try JSONDecoder().decode(RunResponse.self, from: data)
        print("✅ Run started: \(runResponse.id)")
        
        // Poll for completion
        let finalRun = try await pollRunCompletion(threadId: threadId, runId: runResponse.id)
        
        // Handle function calls if needed
        if finalRun.status == "requires_action" {
            return try await handleFunctionCalls(threadId: threadId, run: finalRun)
        }
        
        // Get the assistant's response
        return try await getLatestMessage(threadId: threadId)
    }
    
    /// Poll for run completion
    private func pollRunCompletion(threadId: String, runId: String) async throws -> RunResponse {
        var attempts = 0
        let maxAttempts = 30 // 30 seconds max
        
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let url = URL(string: "\(baseURL)/threads/\(threadId)/runs/\(runId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let run = try JSONDecoder().decode(RunResponse.self, from: data)
            
            print("📊 Run status: \(run.status)")
            
            if run.status == "completed" || run.status == "requires_action" {
                return run
            }
            
            if run.status == "failed" || run.status == "cancelled" || run.status == "expired" {
                throw AIError.apiRequestFailed
            }
            
            attempts += 1
        }
        
        throw AIError.apiRequestFailed
    }
    
    /// Get the latest message from the thread
    private func getLatestMessage(threadId: String) async throws -> String {
        let url = URL(string: "\(baseURL)/threads/\(threadId)/messages?limit=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIError.apiRequestFailed
        }
        
        let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)
        
        guard let message = messagesResponse.data.first,
              let textContent = message.content.first(where: { $0.type == "text" }) else {
            throw AIError.invalidResponse
        }
        
        return textContent.text.value
    }
    
    /// Handle function calls from the assistant
    private func handleFunctionCalls(threadId: String, run: RunResponse) async throws -> String {
        guard let requiredAction = run.required_action,
              let toolCalls = requiredAction.submit_tool_outputs?.tool_calls else {
            throw AIError.invalidResponse
        }
        
        print("🔧 Handling \(toolCalls.count) function calls")
        
        var toolOutputs: [[String: Any]] = []
        
        for toolCall in toolCalls {
            let output = try await executeFunctionCall(toolCall)
            toolOutputs.append([
                "tool_call_id": toolCall.id,
                "output": output
            ])
        }
        
        // Submit tool outputs
        let payload: [String: Any] = [
            "tool_outputs": toolOutputs
        ]
        
        let url = URL(string: "\(baseURL)/threads/\(threadId)/runs/\(run.id)/submit_tool_outputs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let newRun = try JSONDecoder().decode(RunResponse.self, from: data)
        
        // Poll for completion again
        let finalRun = try await pollRunCompletion(threadId: threadId, runId: newRun.id)
        
        if finalRun.status == "completed" {
            return try await getLatestMessage(threadId: threadId)
        }
        
        throw AIError.apiRequestFailed
    }
    
    /// Execute a function call
    private func executeFunctionCall(_ toolCall: ToolCall) async throws -> String {
        print("🔧 Executing function: \(toolCall.function.name)")
        
        let arguments = try JSONDecoder().decode([String: String].self, from: toolCall.function.arguments.data(using: .utf8)!)
        
        switch toolCall.function.name {
        case "create_quote":
            return try await createQuote(arguments: arguments)
        case "send_quote":
            return try await sendQuote(arguments: arguments)
        case "schedule_work":
            return try await scheduleWork(arguments: arguments)
        case "send_message":
            return try await sendMessage(arguments: arguments)
        case "update_status":
            return try await updateStatus(arguments: arguments)
        case "estimate_cost":
            return try await estimateCost(arguments: arguments)
        default:
            return "{\"error\": \"Unknown function: \(toolCall.function.name)\"}"
        }
    }
    
    // MARK: - Function Implementations
    
    private func createQuote(arguments: [String: String]) async throws -> String {
        print("💰 Creating quote with arguments: \(arguments)")
        // This would integrate with your existing quote/invoice system
        return """
        {
            "success": true,
            "quote_id": "QUOTE-\(UUID().uuidString.prefix(8))",
            "amount": "\(arguments["amount"] ?? "0")",
            "message": "Quote created successfully"
        }
        """
    }
    
    private func sendQuote(arguments: [String: String]) async throws -> String {
        print("📧 Sending quote with arguments: \(arguments)")
        // This would integrate with your messaging system
        return """
        {
            "success": true,
            "message": "Quote sent to customer"
        }
        """
    }
    
    private func scheduleWork(arguments: [String: String]) async throws -> String {
        print("📅 Scheduling work with arguments: \(arguments)")
        // This would integrate with your scheduling system
        return """
        {
            "success": true,
            "scheduled_date": "\(arguments["date"] ?? "")",
            "message": "Work scheduled successfully"
        }
        """
    }
    
    private func sendMessage(arguments: [String: String]) async throws -> String {
        print("💬 Sending message with arguments: \(arguments)")
        // This would integrate with your messaging system
        return """
        {
            "success": true,
            "message": "Message sent to customer"
        }
        """
    }
    
    private func updateStatus(arguments: [String: String]) async throws -> String {
        print("🔄 Updating status with arguments: \(arguments)")
        // This would integrate with your work order system
        return """
        {
            "success": true,
            "new_status": "\(arguments["status"] ?? "")",
            "message": "Status updated successfully"
        }
        """
    }
    
    private func estimateCost(arguments: [String: String]) async throws -> String {
        print("💵 Estimating cost with arguments: \(arguments)")
        // This would use your cost estimation logic
        return """
        {
            "success": true,
            "estimated_cost": "250-350",
            "breakdown": {
                "labor": "180",
                "materials": "120"
            },
            "message": "Cost estimated successfully"
        }
        """
    }
    
    // MARK: - Firebase Integration
    
    private func fetchThreadId(for workOrderId: String) async throws -> String? {
        // This would fetch from Firestore
        // For now, return nil to always create new threads
        return nil
    }
    
    private func storeThreadId(_ threadId: String, for workOrderId: String) async throws {
        // This would store in Firestore under workOrders/{workOrderId}/aiThread
        print("💾 Storing thread ID: \(threadId) for work order: \(workOrderId)")
    }
    
    // MARK: - Assistant Instructions
    
    private var assistantInstructions: String {
        """
        You are Kevin AI, an intelligent assistant helping manage restaurant maintenance work orders.
        
        YOUR ROLE:
        - Help admins respond quickly to maintenance requests
        - Analyze work order context and provide actionable suggestions
        - Generate quotes, schedule work, and send messages on behalf of the admin
        - Be proactive but always confirm before taking actions
        
        PERSONALITY:
        - Professional but friendly
        - Concise and action-oriented
        - Helpful and proactive
        - Clear about what you can and cannot do
        
        CAPABILITIES:
        - Create and send quotes based on work order details
        - Schedule work appointments
        - Send messages to customers
        - Update work order status
        - Estimate costs based on materials and labor
        
        GUIDELINES:
        - Always review the work order context before responding
        - Suggest specific actions with clear parameters
        - Ask clarifying questions when needed
        - Confirm before executing actions that affect the customer
        - Be transparent about your confidence level
        
        EXAMPLE INTERACTIONS:
        
        User: "New issue at Summit Coffee"
        You: "Summit Coffee has bathroom trim damage. The photo shows water-damaged baseboard, approximately 6 feet. Based on similar jobs, I estimate $250-350 for repair. Would you like me to create a quote?"
        
        User: "quote $300"
        You: "I'll create a quote for $300. Breakdown: Labor $180, Materials $120. Should I send it to the customer now or would you like to review it first?"
        
        User: "send it"
        You: "Quote sent to Summit Coffee. I'll notify you when they respond. Would you like me to schedule this for next Tuesday when you're in that area?"
        """
    }
    
    private var functionTools: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "create_quote",
                    "description": "Create a quote/estimate for repair work",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "amount": [
                                "type": "string",
                                "description": "Total quote amount (e.g., '300')"
                            ],
                            "labor": [
                                "type": "string",
                                "description": "Labor cost portion"
                            ],
                            "materials": [
                                "type": "string",
                                "description": "Materials cost portion"
                            ],
                            "description": [
                                "type": "string",
                                "description": "Description of work to be done"
                            ]
                        ],
                        "required": ["amount"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "send_quote",
                    "description": "Send a quote to the customer",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "quote_id": [
                                "type": "string",
                                "description": "ID of the quote to send"
                            ],
                            "message": [
                                "type": "string",
                                "description": "Optional message to include with the quote"
                            ]
                        ],
                        "required": ["quote_id"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "schedule_work",
                    "description": "Schedule work for a specific date and time",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "date": [
                                "type": "string",
                                "description": "Date in YYYY-MM-DD format"
                            ],
                            "time": [
                                "type": "string",
                                "description": "Time in HH:MM format"
                            ],
                            "duration": [
                                "type": "string",
                                "description": "Expected duration (e.g., '2 hours')"
                            ]
                        ],
                        "required": ["date"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "send_message",
                    "description": "Send a message to the customer",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "message": [
                                "type": "string",
                                "description": "Message content to send"
                            ]
                        ],
                        "required": ["message"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "update_status",
                    "description": "Update the work order status",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "status": [
                                "type": "string",
                                "description": "New status (reported, in_progress, completed)"
                            ]
                        ],
                        "required": ["status"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "estimate_cost",
                    "description": "Estimate the cost of repair work based on materials and labor",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "materials": [
                                "type": "array",
                                "description": "List of materials needed",
                                "items": ["type": "string"]
                            ],
                            "labor_hours": [
                                "type": "string",
                                "description": "Estimated labor hours"
                            ]
                        ],
                        "required": []
                    ]
                ]
            ]
        ]
    }
}

// MARK: - API Response Models

struct AssistantResponse: Codable {
    let id: String
    let object: String
    let created_at: Int
    let name: String?
    let description: String?
    let model: String
    let instructions: String?
}

struct ThreadResponse: Codable {
    let id: String
    let object: String
    let created_at: Int
    let metadata: [String: String]?
}

struct RunResponse: Codable {
    let id: String
    let object: String
    let created_at: Int
    let thread_id: String
    let assistant_id: String
    let status: String
    let required_action: RequiredAction?
}

struct RequiredAction: Codable {
    let type: String
    let submit_tool_outputs: SubmitToolOutputs?
}

struct SubmitToolOutputs: Codable {
    let tool_calls: [ToolCall]
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable {
    let name: String
    let arguments: String
}

struct MessagesResponse: Codable {
    let object: String
    let data: [MessageData]
}

struct MessageData: Codable {
    let id: String
    let object: String
    let created_at: Int
    let thread_id: String
    let role: String
    let content: [MessageContent]
}

struct MessageContent: Codable {
    let type: String
    let text: TextContent
}

struct TextContent: Codable {
    let value: String
    let annotations: [String]?
}
