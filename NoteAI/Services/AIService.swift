import Foundation
import OpenAIKit

// Represents the extracted contact information
struct ContactInfo {
    var name: String?
    var phoneNumber: String?
    var email: String?
    var description: String
    var suggestedLabels: [String]
}

// Result from a search query
struct SearchResult {
    var matchedContactIds: [UUID]
    var explanation: String
}

class AIService {
    private let openAI: OpenAIKit.Client
    
    init(apiKey: String) {
        self.openAI = OpenAIKit.Client(apiToken: apiKey)
    }
    
    // Process natural language input to extract contact information
    func processContactInput(_ input: String, existingLabels: [String]) async throws -> ContactInfo {
        let systemPrompt = """
        You are an AI assistant that extracts structured contact information from natural language input.
        Extract the following fields if present:
        1. Name (full name of the person)
        2. Phone number (any phone number format)
        3. Email address
        4. Description (any details about the person, their role, where you met them, etc.)
        5. Suggested labels (based on the description, suggest 1-3 labels that would categorize this contact)
        
        Available labels: \(existingLabels.joined(separator: ", "))
        
        Suggest new labels if none of the existing ones fit well.
        Format your response as a JSON object with fields: name, phoneNumber, email, description, and suggestedLabels (array).
        If any field is missing, set it to null.
        """
        
        let chatParams = ChatParameters(
            model: Model.GPT4_o,
            messages: [
                Message(role: .system, content: systemPrompt),
                Message(role: .user, content: input)
            ],
            temperature: 0.2,
            responseFormat: .jsonObject
        )
        
        let response = try await openAI.chats.create(parameters: chatParams)
        
        guard let responseContent = response.choices.first?.message.content else {
            throw AIError.failedToProcessResponse
        }
        
        // Parse the JSON response
        guard let jsonData = responseContent.data(using: .utf8) else {
            throw AIError.invalidResponseFormat
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(AIContactResponse.self, from: jsonData)
            
            return ContactInfo(
                name: result.name,
                phoneNumber: result.phoneNumber,
                email: result.email,
                description: result.description ?? input, // Use input as fallback
                suggestedLabels: result.suggestedLabels ?? []
            )
        } catch {
            throw AIError.invalidResponseFormat
        }
    }
    
    // Search for contacts using natural language query
    func searchContacts(query: String, contacts: [Contact], labels: [Label]) async throws -> SearchResult {
        let contactsInfo = contacts.map { contact in
            let contactLabels = contact.labels?.map { $0.name } ?? []
            return """
            ID: \($0.id.uuidString)
            Name: \($0.name ?? "Unknown")
            Labels: \(contactLabels.joined(separator: ", "))
            Description: \($0.textDescription)
            """
        }.joined(separator: "\n\n")
        
        let systemPrompt = """
        You are an AI assistant that helps search through contacts based on natural language queries.
        Given a list of contacts and a search query, return the IDs of contacts that match the query.
        Consider names, descriptions, and labels when matching. 
        Provide semantic understanding rather than just exact keyword matching.
        
        Format your response as a JSON object with:
        1. matchedIds: An array of contact UUIDs that match the query
        2. explanation: A brief explanation of why these contacts were selected
        """
        
        let userPrompt = """
        Search query: \(query)
        
        Available contacts:
        \(contactsInfo)
        """
        
        let chatParams = ChatParameters(
            model: Model.GPT4_o,
            messages: [
                Message(role: .system, content: systemPrompt),
                Message(role: .user, content: userPrompt)
            ],
            temperature: 0.2,
            responseFormat: .jsonObject
        )
        
        let response = try await openAI.chats.create(parameters: chatParams)
        
        guard let responseContent = response.choices.first?.message.content else {
            throw AIError.failedToProcessResponse
        }
        
        // Parse the JSON response
        guard let jsonData = responseContent.data(using: .utf8) else {
            throw AIError.invalidResponseFormat
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(AISearchResponse.self, from: jsonData)
            
            let matchedIds = result.matchedIds.compactMap { UUID(uuidString: $0) }
            let explanation = result.explanation ?? "Matches based on your search criteria"
            
            return SearchResult(
                matchedContactIds: matchedIds,
                explanation: explanation
            )
        } catch {
            throw AIError.invalidResponseFormat
        }
    }
    
    // Suggest labels for a contact based on its description
    func suggestLabelsForContact(description: String, existingLabels: [String]) async throws -> [String] {
        let systemPrompt = """
        You are an AI assistant that suggests appropriate labels for contacts based on their description.
        Suggest 1-3 relevant labels that would help categorize this contact.
        
        Available labels: \(existingLabels.joined(separator: ", "))
        
        Suggest new labels if none of the existing ones fit well.
        Format your response as a JSON array of strings.
        """
        
        let chatParams = ChatParameters(
            model: Model.GPT4_o,
            messages: [
                Message(role: .system, content: systemPrompt),
                Message(role: .user, content: description)
            ],
            temperature: 0.3,
            responseFormat: .jsonObject
        )
        
        let response = try await openAI.chats.create(parameters: chatParams)
        
        guard let responseContent = response.choices.first?.message.content else {
            throw AIError.failedToProcessResponse
        }
        
        // Parse the JSON response
        guard let jsonData = responseContent.data(using: .utf8) else {
            throw AIError.invalidResponseFormat
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode([String].self, from: jsonData)
            return result
        } catch {
            throw AIError.invalidResponseFormat
        }
    }
    
    // Process a command in natural language (like "create a label called Investors")
    func processCommand(_ command: String, existingLabels: [String]) async throws -> CommandResponse {
        let systemPrompt = """
        You are an AI assistant that processes natural language commands for a contact management app.
        Identify the type of command and extract relevant parameters.
        
        Supported commands:
        1. Create a label: "create a label called X", "add label X", etc.
        2. Delete a label: "delete label X", "remove label X", etc.
        3. Other commands: Identify any other type of command and explain what it does
        
        Existing labels: \(existingLabels.joined(separator: ", "))
        
        Format your response as a JSON object with fields:
        - commandType: "create_label", "delete_label", or "other"
        - labelName: (for create/delete commands) the name of the label
        - explanation: Description of what the command does
        """
        
        let chatParams = ChatParameters(
            model: Model.GPT4_o,
            messages: [
                Message(role: .system, content: systemPrompt),
                Message(role: .user, content: command)
            ],
            temperature: 0.2,
            responseFormat: .jsonObject
        )
        
        let response = try await openAI.chats.create(parameters: chatParams)
        
        guard let responseContent = response.choices.first?.message.content else {
            throw AIError.failedToProcessResponse
        }
        
        // Parse the JSON response
        guard let jsonData = responseContent.data(using: .utf8) else {
            throw AIError.invalidResponseFormat
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(AICommandResponse.self, from: jsonData)
            
            return CommandResponse(
                commandType: CommandType(rawValue: result.commandType) ?? .other,
                labelName: result.labelName,
                explanation: result.explanation ?? "Command processed"
            )
        } catch {
            throw AIError.invalidResponseFormat
        }
    }
}

// Response models for AI processing
private struct AIContactResponse: Codable {
    let name: String?
    let phoneNumber: String?
    let email: String?
    let description: String?
    let suggestedLabels: [String]?
}

private struct AISearchResponse: Codable {
    let matchedIds: [String]
    let explanation: String?
}

private struct AICommandResponse: Codable {
    let commandType: String
    let labelName: String?
    let explanation: String?
}

// Public response model for commands
enum CommandType: String, Codable {
    case createLabel = "create_label"
    case deleteLabel = "delete_label"
    case other = "other"
}

struct CommandResponse {
    let commandType: CommandType
    let labelName: String?
    let explanation: String
}

// Error types for AI operations
enum AIError: Error {
    case failedToProcessResponse
    case invalidResponseFormat
}
