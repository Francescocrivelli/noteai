import Foundation

struct Contact: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID
    var name: String?
    var phoneNumber: String?
    var email: String?
    var textDescription: String
    var createdAt: Date
    var updatedAt: Date
    
    // Used to store associated labels (not directly part of the DB model)
    var labels: [Label]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case phoneNumber = "phone_number"
        case email
        case textDescription = "text_description"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // labels is not included as it's populated separately
    }
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Label: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID
    var name: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }
    
    static func == (lhs: Label, rhs: Label) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ContactLabel: Identifiable, Codable {
    var id: UUID
    var contactId: UUID
    var labelId: UUID
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case labelId = "label_id"
        case createdAt = "created_at"
    }
}

struct Subscription: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var productId: String
    var originalTransactionId: String?
    var latestTransactionId: String?
    var status: String
    var expirationDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case originalTransactionId = "original_transaction_id"
        case latestTransactionId = "latest_transaction_id"
        case status
        case expirationDate = "expiration_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isActive: Bool {
        guard let expiration = expirationDate else {
            return false
        }
        
        return status == "active" && expiration > Date()
    }
}

struct UserPreferences: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
