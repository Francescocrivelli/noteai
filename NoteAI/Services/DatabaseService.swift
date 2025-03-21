import Foundation
import Supabase

class DatabaseService {
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // MARK: - User Preferences
    
    func getUserPreferences(userId: UUID) async throws -> UserPreferences? {
        return try await supabase.from("user_preferences")
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }
    
    func createUserPreferences(userId: UUID) async throws -> UserPreferences {
        let preferences = UserPreferences(
            id: UUID(),
            userId: userId,
            hasCompletedOnboarding: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        return try await supabase.from("user_preferences")
            .insert(preferences)
            .single()
            .execute()
            .value
    }
    
    func updateUserPreferences(preferences: UserPreferences) async throws -> UserPreferences {
        return try await supabase.from("user_preferences")
            .update(preferences)
            .eq("id", value: preferences.id.uuidString)
            .single()
            .execute()
            .value
    }
    
    // MARK: - Subscriptions
    
    func getSubscription(userId: UUID) async throws -> Subscription? {
        return try await supabase.from("subscriptions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .single()
            .execute()
            .value
    }
    
    func createSubscription(subscription: Subscription) async throws -> Subscription {
        return try await supabase.from("subscriptions")
            .insert(subscription)
            .single()
            .execute()
            .value
    }
    
    func updateSubscription(subscription: Subscription) async throws -> Subscription {
        return try await supabase.from("subscriptions")
            .update(subscription)
            .eq("id", value: subscription.id.uuidString)
            .single()
            .execute()
            .value
    }
    
    // MARK: - Contacts
    
    func getContacts(userId: UUID) async throws -> [Contact] {
        return try await supabase.from("contacts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }
    
    func createContact(contact: Contact) async throws -> Contact {
        return try await supabase.from("contacts")
            .insert(contact)
            .single()
            .execute()
            .value
    }
    
    func updateContact(contact: Contact) async throws -> Contact {
        return try await supabase.from("contacts")
            .update(contact)
            .eq("id", value: contact.id.uuidString)
            .single()
            .execute()
            .value
    }
    
    func deleteContact(contactId: UUID) async throws {
        _ = try await supabase.from("contacts")
            .delete()
            .eq("id", value: contactId.uuidString)
            .execute()
    }
    
    // MARK: - Labels
    
    func getLabels(userId: UUID) async throws -> [Label] {
        return try await supabase.from("labels")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("name", ascending: true)
            .execute()
            .value
    }
    
    func createLabel(label: Label) async throws -> Label {
        return try await supabase.from("labels")
            .insert(label)
            .single()
            .execute()
            .value
    }
    
    func updateLabel(label: Label) async throws -> Label {
        return try await supabase.from("labels")
            .update(label)
            .eq("id", value: label.id.uuidString)
            .single()
            .execute()
            .value
    }
    
    func deleteLabel(labelId: UUID) async throws {
        _ = try await supabase.from("labels")
            .delete()
            .eq("id", value: labelId.uuidString)
            .execute()
    }
    
    // MARK: - Contact-Label Relations
    
    func getContactLabels(contactId: UUID) async throws -> [ContactLabel] {
        return try await supabase.from("contact_labels")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .execute()
            .value
    }
    
    func getLabelsForContact(contactId: UUID) async throws -> [Label] {
        let query = """
        contact_labels!inner(contact_id, label_id),
        id, user_id, name, created_at
        """
        
        let labels: [Label] = try await supabase.from("labels")
            .select(query)
            .eq("contact_labels.contact_id", value: contactId.uuidString)
            .execute()
            .value
        
        return labels
    }
    
    func assignLabelToContact(contactId: UUID, labelId: UUID) async throws -> ContactLabel {
        let contactLabel = ContactLabel(
            id: UUID(),
            contactId: contactId,
            labelId: labelId,
            createdAt: Date()
        )
        
        return try await supabase.from("contact_labels")
            .insert(contactLabel)
            .single()
            .execute()
            .value
    }
    
    func removeLabelFromContact(contactId: UUID, labelId: UUID) async throws {
        _ = try await supabase.from("contact_labels")
            .delete()
            .eq("contact_id", value: contactId.uuidString)
            .eq("label_id", value: labelId.uuidString)
            .execute()
    }
}
