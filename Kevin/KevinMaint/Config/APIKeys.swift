import Foundation

struct APIKeys {
    // MARK: - OpenAI Configuration
    // TODO: Move to environment variables or secure storage for production
    static let openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "YOUR_OPENAI_API_KEY_HERE"
    
    // MARK: - Google Places API
    static let googlePlacesAPIKey = ProcessInfo.processInfo.environment["GOOGLE_PLACES_API_KEY"] ?? "YOUR_GOOGLE_PLACES_API_KEY_HERE"
    
    // MARK: - Alternative AI Services (if needed)
    static let anthropicAPIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "YOUR_ANTHROPIC_API_KEY_HERE"
    static let googleAIAPIKey = ProcessInfo.processInfo.environment["GOOGLE_AI_API_KEY"] ?? "YOUR_GOOGLE_AI_API_KEY_HERE"
    
    // MARK: - Configuration
    static var isOpenAIConfigured: Bool {
        return !openAIAPIKey.isEmpty && openAIAPIKey != "YOUR_OPENAI_API_KEY_HERE"
    }
    
    static var isGooglePlacesConfigured: Bool {
        return !googlePlacesAPIKey.isEmpty && googlePlacesAPIKey != "YOUR_GOOGLE_PLACES_API_KEY_HERE"
    }
}

// MARK: - Security Note
/*
 IMPORTANT: For production apps, store API keys securely:
 
 1. Use Xcode's Build Settings to inject keys as environment variables
 2. Store in iOS Keychain for runtime access
 3. Use a secure backend service to proxy API calls
 4. Never commit real API keys to version control
 
 For development/testing, replace "YOUR_OPENAI_API_KEY_HERE" with your actual key.
 */
