import Foundation

/// Configuration manager for handling app secrets and configuration
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    // MARK: - Properties
    
    private var configurations: [String: String] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Load from environment or configuration file if available
        loadConfigurations()
    }
    
    // MARK: - Public Methods
    
    /// Get a configuration value for a key
    /// - Parameter key: The configuration key
    /// - Returns: The configuration value or nil if not found
    func value(forKey key: ConfigurationKey) -> String? {
        return configurations[key.rawValue]
    }
    
    /// Set a configuration value for a key
    /// - Parameters:
    ///   - value: The configuration value
    ///   - key: The configuration key
    func setValue(_ value: String, forKey key: ConfigurationKey) {
        configurations[key.rawValue] = value
    }
    
    // MARK: - Private Methods
    
    private func loadConfigurations() {
        // In a real app, this would load from a secure source
        // For now, we'll set default development values
        
        // OpenAI API Key - Replace with your actual key in production
        configurations[ConfigurationKey.openAIAPIKey.rawValue] = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        
        // Supabase URL and Key - Replace with your actual values in production
        configurations[ConfigurationKey.supabaseURL.rawValue] = "https://pcchrtwfjgfoequvbufq.supabase.co"
        configurations[ConfigurationKey.supabaseKey.rawValue] = ProcessInfo.processInfo.environment["SUPABASE_API_KEY"] ?? ""
    }
}

/// Configuration keys for the app
enum ConfigurationKey: String {
    case openAIAPIKey = "openai_api_key"
    case supabaseURL = "supabase_url"
    case supabaseKey = "supabase_key"
}
