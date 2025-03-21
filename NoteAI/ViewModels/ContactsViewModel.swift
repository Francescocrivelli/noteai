import Foundation
import Supabase
import Contacts

class ContactsViewModel: ObservableObject {
    private let databaseService: DatabaseService
    private let contactsService: ContactsService
    private let aiService: AIService
    private let userId: UUID
    
    @Published var contacts: [Contact] = []
    @Published var labels: [Label] = []
    @Published var filteredContacts: [Contact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var isSearching = false
    
    // Mode state
    @Published var inputMode: InputMode = .add
    
    init(databaseService: DatabaseService, contactsService: ContactsService, aiService: AIService, userId: UUID) {
        self.databaseService = databaseService
        self.contactsService = contactsService
        self.aiService = aiService
        self.userId = userId
        
        // Load data
        Task {
            await loadContacts()
            await loadLabels()
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    func loadContacts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            contacts = try await databaseService.getContacts(userId: userId)
            
            // Load labels for each contact
            for i in 0..<contacts.count {
                if contacts[i].labels == nil {
                    contacts[i].labels = try await databaseService.getLabelsForContact(contactId: contacts[i].id)
                }
            }
            
            filteredContacts = contacts
            isLoading = false
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    @MainActor
    func loadLabels() async {
        do {
            labels = try await databaseService.getLabels(userId: userId)
        } catch {
            errorMessage = "Failed to load labels: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Contact Creation
    
    func processInput(_ input: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            if inputMode == .add {
                // Process as a contact creation
                await createContactFromInput(input)
            } else if inputMode == .search {
                // Process as a search query
                await searchContacts(query: input)
            } else if inputMode == .command {
                // Process as a command
                await processCommand(input)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to process input: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func createContactFromInput(_ input: String) async {
        do {
            // Get existing label names for AI to use
            let labelNames = labels.map { $0.name }
            
            // Use AI to extract contact information
            let contactInfo = try await aiService.processContactInput(input, existingLabels: labelNames)
            
            // Create contact in database
            let newContact = Contact(
                id: UUID(),
                userId: userId,
                name: contactInfo.name,
                phoneNumber: contactInfo.phoneNumber,
                email: contactInfo.email,
                textDescription: contactInfo.description,
                createdAt: Date(),
                updatedAt: Date(),
                labels: []
            )
            
            let createdContact = try await databaseService.createContact(contact: newContact)
            
            // Create in device contacts if we have name or phone
            if let name = contactInfo.name, !name.isEmpty || 
               let phone = contactInfo.phoneNumber, !phone.isEmpty {
                try await contactsService.createContact(
                    name: contactInfo.name ?? "Unknown",
                    phoneNumber: contactInfo.phoneNumber,
                    email: contactInfo.email,
                    note: contactInfo.description
                )
            }
            
            // Process labels
            var contactLabels: [Label] = []
            for labelName in contactInfo.suggestedLabels {
                if let existingLabel = labels.first(where: { $0.name.lowercased() == labelName.lowercased() }) {
                    // Use existing label
                    try await databaseService.assignLabelToContact(contactId: createdContact.id, labelId: existingLabel.id)
                    contactLabels.append(existingLabel)
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
                    
                    contactLabels.append(createdLabel)
                    
                    // Add to local labels array
                    await MainActor.run {
                        self.labels.append(createdLabel)
                    }
                }
            }
            
            // Add the contact to our local array
            var updatedContact = createdContact
            updatedContact.labels = contactLabels
            
            await MainActor.run {
                self.contacts.insert(updatedContact, at: 0)
                self.filteredContacts = self.contacts
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create contact: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Search
    
    private func searchContacts(query: String) async {
        do {
            if query.isEmpty {
                await MainActor.run {
                    self.filteredContacts = self.contacts
                    self.isLoading = false
                }
                return
            }
            
            // Use AI to search
            let searchResult = try await aiService.searchContacts(query: query, contacts: contacts, labels: labels)
            
            // Filter contacts based on the matched IDs
            let matchedContacts = contacts.filter { contact in
                searchResult.matchedContactIds.contains(contact.id)
            }
            
            await MainActor.run {
                self.filteredContacts = matchedContacts
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                // Fallback to simple string matching
                self.filteredContacts = self.contacts.filter { contact in
                    let name = contact.name?.lowercased() ?? ""
                    let description = contact.textDescription.lowercased()
                    let labelNames = contact.labels?.map { $0.name.lowercased() } ?? []
                    
                    let searchLower = query.lowercased()
                    
                    return name.contains(searchLower) || 
                           description.contains(searchLower) || 
                           labelNames.contains { $0.contains(searchLower) }
                }
                
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Commands
    
    private func processCommand(_ input: String) async {
        do {
            // Get existing label names
            let labelNames = labels.map { $0.name }
            
            // Process the command using AI
            let commandResponse = try await aiService.processCommand(input, existingLabels: labelNames)
            
            switch commandResponse.commandType {
            case .createLabel:
                if let labelName = commandResponse.labelName, !labelName.isEmpty {
                    // Check if label already exists
                    if labels.contains(where: { $0.name.lowercased() == labelName.lowercased() }) {
                        await MainActor.run {
                            errorMessage = "Label '\(labelName)' already exists"
                            isLoading = false
                        }
                    } else {
                        // Create new label
                        let newLabel = Label(
                            id: UUID(),
                            userId: userId,
                            name: labelName,
                            createdAt: Date()
                        )
                        
                        let createdLabel = try await databaseService.createLabel(label: newLabel)
                        
                        await MainActor.run {
                            self.labels.append(createdLabel)
                            self.isLoading = false
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Could not determine label name from your input"
                        isLoading = false
                    }
                }
                
            case .deleteLabel:
                if let labelName = commandResponse.labelName, !labelName.isEmpty {
                    // Find the label to delete
                    if let labelToDelete = labels.first(where: { $0.name.lowercased() == labelName.lowercased() }) {
                        // Delete the label
                        try await databaseService.deleteLabel(labelId: labelToDelete.id)
                        
                        await MainActor.run {
                            self.labels.removeAll { $0.id == labelToDelete.id }
                            
                            // Also update any contacts that had this label
                            for i in 0..<self.contacts.count {
                                self.contacts[i].labels?.removeAll { $0.id == labelToDelete.id }
                            }
                            
                            self.filteredContacts = self.contacts
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = "Label '\(labelName)' not found"
                            isLoading = false
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Could not determine label name from your input"
                        isLoading = false
                    }
                }
                
            case .other:
                await MainActor.run {
                    errorMessage = "Unknown command. Try 'create label [name]' or 'delete label [name]'"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to process command: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Contact Management
    
    func deleteContact(contactId: UUID) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await databaseService.deleteContact(contactId: contactId)
            
            await MainActor.run {
                contacts.removeAll { $0.id == contactId }
                filteredContacts = contacts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete contact: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Mode Management
    
    func setMode(_ mode: InputMode) {
        inputMode = mode
        
        // Reset filtered contacts when switching to search mode
        if mode == .search {
            searchQuery = ""
            filteredContacts = contacts
        }
    }
}

// Input mode for the text field
enum InputMode {
    case add      // Adding a new contact
    case search   // Searching contacts
    case command  // Executing a command
}
