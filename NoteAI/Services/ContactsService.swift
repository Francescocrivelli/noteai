import Foundation
import Contacts

class ContactsService {
    private let contactStore = CNContactStore()
    
    // Request access to the user's contacts
    func requestAccess() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    // Fetch all contacts from the device
    func fetchAllContacts() async throws -> [CNContact] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts = [CNContact]()
        
        try contactStore.enumerateContacts(with: request) { contact, stop in
            contacts.append(contact)
        }
        
        return contacts
    }
    
    // Create a new contact on the device
    func createContact(name: String, phoneNumber: String?, email: String?, note: String) async throws -> String {
        let newContact = CNMutableContact()
        
        // Process the name (simple splitting logic)
        let nameParts = name.split(separator: " ", maxSplits: 1)
        if nameParts.count > 0 {
            newContact.givenName = String(nameParts[0])
            if nameParts.count > 1 {
                newContact.familyName = String(nameParts[1])
            }
        } else {
            newContact.givenName = name
        }
        
        // Add phone number if available
        if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
            let phoneValue = CNPhoneNumber(stringValue: phoneNumber)
            let phoneNumberValue = CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneValue)
            newContact.phoneNumbers = [phoneNumberValue]
        }
        
        // Add email if available
        if let email = email, !email.isEmpty {
            let emailValue = CNLabeledValue(label: CNLabelWork, value: email as NSString)
            newContact.emailAddresses = [emailValue]
        }
        
        // Add note with the description
        newContact.note = note
        
        // Save the contact
        let saveRequest = CNSaveRequest()
        saveRequest.add(newContact, toContainerWithIdentifier: nil)
        
        try contactStore.execute(saveRequest)
        
        return "\(newContact.givenName) \(newContact.familyName)"
    }
    
    // Search for contacts matching a query
    func searchContacts(query: String) async throws -> [CNContact] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor
        ]
        
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        
        return contacts
    }
    
    // Convert CNContacts to our Contact model
    func convertToAppContacts(cnContacts: [CNContact], userId: UUID) -> [Contact] {
        return cnContacts.map { cnContact in
            let fullName = [cnContact.givenName, cnContact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            
            let phoneNumber = cnContact.phoneNumbers.first?.value.stringValue
            let email = cnContact.emailAddresses.first?.value as String?
            
            return Contact(
                id: UUID(),
                userId: userId,
                name: fullName.isEmpty ? nil : fullName,
                phoneNumber: phoneNumber,
                email: email,
                textDescription: cnContact.note,
                createdAt: Date(),
                updatedAt: Date(),
                labels: []
            )
        }
    }
}
