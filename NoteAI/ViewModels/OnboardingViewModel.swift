import Foundation
import Contacts
import Supabase

class OnboardingViewModel: ObservableObject {
    private let contactsService: ContactsService
    private let databaseService: DatabaseService
    private let aiService: AIService
    private let userId: UUID
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var progress: Float = 0.0
    @Published var contactsImported = 0
    @Published var totalContacts = 0
    @Published var hasCompletedOnboarding = false
    
    init(contactsService: ContactsService, databaseService: DatabaseService, aiService: AIService, userId: UUID) {
        self.contactsService = contactsService
        self.databaseService = databaseService
        self.aiService = aiService
        self.userId = userId
        
        // Check if onboarding has been completed
        Task {
            await checkOnboardingStatus()
        }
    }
    
    @MainActor
    func checkOnboardingStatus() async {
        isLoading = true
        
        do {
            let preferences = try await databaseService.getUserPreferences(userId: userId)
            hasCompletedOnboarding = preferences?.hasCompletedOnboarding ?? false
            isLoading = false
        } catch {
            errorMessage = "Failed to check onboarding status: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func requestContactsAccess() async -> Bool {
        do {
            return try await contactsService.requestAccess()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to request contacts access: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func importContacts() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            progress = 0.0
            contactsImported = 0
        }
        
        do {
            // Request contacts access if needed
            let hasAccess = await requestContactsAccess()
            guard hasAccess else {
                await MainActor.run {
                    errorMessage = "Contacts access denied"
                    isLoading = false
                }
                return
            }
            
            // Fetch all contacts from the device
            let deviceContacts = try await contactsService.fetchAllContacts()
            
            await MainActor.run {
                totalContacts = deviceContacts.count
            }
            
            // Get existing labels
            let labels = try await databaseService.getLabels(userId: userId)
            let labelNames = labels.map { $0.name }
            
            // Process each contact
            var importedLabels = [String: Label]()
            for labelName in labelNames {
                if let label = labels.first(where: { $0.name == labelName }) {
                    importedLabels[labelName] = label
                }
            }
            
            // Process in batches to avoid overloading
            let batchSize = 5
            for i in stride(from: 0, to: deviceContacts.count, by: batchSize) {
                let end = min(i + batchSize, deviceContacts.count)
                let batch = deviceContacts[i..<end]
                
                try await processContactBatch(batch: Array(batch), importedLabels: &importedLabels, labelNames: labelNames)
                
                await MainActor.run {
                    contactsImported += batch.count
                    progress = Float(contactsImported) / Float(totalContacts)
                }
            }
            
            // Mark onboarding as completed
            try await markOnboardingCompleted()
            
            await MainActor.run {
                hasCompletedOnboarding = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to import contacts: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func processContactBatch(batch: [CNContact], importedLabels: inout [String: Label], labelNames: [String]) async throws {
        for cnContact in batch {
            // Skip contacts without names or phone numbers
            let fullName = [cnContact.givenName, cnContact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let hasPhoneNumber = !cnContact.phoneNumbers.isEmpty
            
            if !fullName.isEmpty || hasPhoneNumber {
                let phoneNumber = cnContact.phoneNumbers.first?.value.stringValue
                let email = cnContact.emailAddresses.first?.value as String?
                
                // Create description from available information
                var description = cnContact.note
                
                if description.isEmpty {
                    var parts = [String]()
                    
                    if !cnContact.organizationName.isEmpty {
                        parts.append("Works at \(cnContact.organizationName)")
                    }
                    
                    if !parts.isEmpty {
                        description = parts.joined(separator: ". ")
                    } else {
                        description = "Imported from contacts"
                    }
                }
                
                // Create contact in the database
                let contact = Contact(
                    id: UUID(),
                    userId: userId,
                    name: fullName.isEmpty ? nil : fullName,
                    phoneNumber: phoneNumber,
                    email: email,
                    textDescription: description,
                    createdAt: Date(),
                    updatedAt: Date(),
                    labels: []
                )
                
                let createdContact = try await databaseService.createContact(contact: contact)
                
                // Suggest labels for the contact
                if !description.isEmpty {
                    let suggestedLabels = try await aiService.suggestLabelsForContact(
                        description: description,
                        existingLabels: labelNames
                    )
                    
                    // Process labels
                    for labelName in suggestedLabels {
                        if let existingLabel = importedLabels[labelName] {
                            // Use existing label
                            try await databaseService.assignLabelToContact(contactId: createdContact.id, labelId: existingLabel.id)
                        } else {
                            // Create new label
                            let newLabel = Label(
                                id: UUID(),
                                userId: userId,
                                name: labelName,
                                createdAt: Date()
                            )
                            
                            let createdLabel = try await databaseService.createLabel(label: newLabel)
                            try await databaseService.assignLabelToContact(contactId: createdContact.id, labelId: createdLabel.id)
                            
                            // Add to imported labels
                            importedLabels[labelName] = createdLabel
                        }
                    }
                }
            }
        }
    }
    
    private func markOnboardingCompleted() async throws {
        // Get user preferences
        if let preferences = try await databaseService.getUserPreferences(userId: userId) {
            // Update preferences
            var updatedPreferences = preferences
            updatedPreferences.hasCompletedOnboarding = true
            updatedPreferences.updatedAt = Date()
            
            _ = try await databaseService.updateUserPreferences(preferences: updatedPreferences)
        } else {
            // Create preferences if they don't exist
            let newPreferences = UserPreferences(
                id: UUID(),
                userId: userId,
                hasCompletedOnboarding: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            _ = try await databaseService.createUserPreferences(userId: userId)
        }
    }
    
    func skipOnboarding() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await markOnboardingCompleted()
            
            await MainActor.run {
                hasCompletedOnboarding = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to skip onboarding: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
