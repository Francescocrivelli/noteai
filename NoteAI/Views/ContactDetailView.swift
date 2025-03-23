import SwiftUI
import Contacts

struct ContactDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var viewModel: ContactsViewModel
    
    let contact: Contact
    @State private var isEditing = false
    @State private var editedDescription = ""
    @State private var showingActionSheet = false
    @State private var showingLabelPicker = false
    @State private var selectedLabels: [Label] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Contact header
                HStack {
                    // Contact avatar
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Text(contactInitials)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.name ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let phoneNumber = contact.phoneNumber {
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.secondary)
                                Text(phoneNumber)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let email = contact.email {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.secondary)
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                
                // Contact actions
                HStack(spacing: 20) {
                    Button(action: callContact) {
                        VStack {
                            Image(systemName: "phone.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("Call")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: messageContact) {
                        VStack {
                            Image(systemName: "message.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Message")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: { showingActionSheet = true }) {
                        VStack {
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("More")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical)
                
                // Labels
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Labels")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingLabelPicker = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    if let labels = contact.labels, !labels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(labels) { label in
                                    Text(label.name)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.2))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(15)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                Task {
                                                    await viewModel.removeLabel(from: contact, labelId: label.id)
                                                }
                                            } label: {
                                                Label("Remove", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    } else {
                        Text("No labels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical)
                
                // Notes/Description
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Notes")
                            .font(.headline)
                        
                        Spacer()
                        
                        if isEditing {
                            Button("Save") {
                                saveDescription()
                            }
                            .foregroundColor(.accentColor)
                        } else {
                            Button("Edit") {
                                startEditing()
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    if isEditing {
                        TextEditor(text: $editedDescription)
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        Text(contact.textDescription)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical)
            }
            .padding()
        }
        .navigationTitle("Contact Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Contact Options"),
                buttons: [
                    .default(Text("Share Contact")) {
                        shareContact()
                    },
                    .destructive(Text("Delete Contact")) {
                        Task {
                            await deleteContact()
                        }
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingLabelPicker) {
            LabelPickerView(contact: contact, existingLabels: viewModel.labels) { selectedLabel in
                Task {
                    if let selectedLabel = selectedLabel {
                        await viewModel.assignLabel(to: contact, labelId: selectedLabel.id)
                    }
                }
                showingLabelPicker = false
            }
        }
    }
    
    // Contact initials for the avatar
    private var contactInitials: String {
        guard let name = contact.name, !name.isEmpty else {
            return "?"
        }
        
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        if components.count > 1 {
            let first = components.first?.prefix(1) ?? ""
            let last = components.last?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        } else if let first = components.first?.prefix(1) {
            return "\(first)".uppercased()
        }
        
        return "?"
    }
    
    // Edit description
    private func startEditing() {
        editedDescription = contact.textDescription
        isEditing = true
    }
    
    private func saveDescription() {
        Task {
            await viewModel.updateContactDescription(contact: contact, newDescription: editedDescription)
            isEditing = false
        }
    }
    
    // Actions
    private func callContact() {
        guard let phoneNumber = contact.phoneNumber else { return }
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard let url = URL(string: "tel://\(cleanedPhoneNumber)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func messageContact() {
        guard let phoneNumber = contact.phoneNumber else { return }
        let cleanedPhoneNumber = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard let url = URL(string: "sms://\(cleanedPhoneNumber)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func shareContact() {
        // Create a contact card to share
        let contact = CNMutableContact()
        if let name = self.contact.name {
            let nameComponents = name.components(separatedBy: " ")
            if nameComponents.count > 0 {
                contact.givenName = nameComponents[0]
                if nameComponents.count > 1 {
                    contact.familyName = nameComponents.dropFirst().joined(separator: " ")
                }
            }
        }
        
        if let phoneNumber = self.contact.phoneNumber {
            contact.phoneNumbers = [CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: phoneNumber)
            )]
        }
        
        if let email = self.contact.email {
            contact.emailAddresses = [CNLabeledValue(
                label: CNLabelWork,
                value: email as NSString
            )]
        }
        
        contact.note = self.contact.textDescription
        
        // Create a vCard
        let data = try? CNContactVCardSerialization.data(with: [contact])
        
        guard let contactData = data else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [contactData],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func deleteContact() async {
        await viewModel.deleteContact(contactId: contact.id)
        presentationMode.wrappedValue.dismiss()
    }
}

// Label Picker View for assigning labels
struct LabelPickerView: View {
    let contact: Contact
    let existingLabels: [Label]
    let onSelect: (Label?) -> Void
    
    @State private var newLabelName = ""
    @State private var selectedLabel: Label?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Create New Label")) {
                    TextField("New Label Name", text: $newLabelName)
                    
                    Button("Create Label") {
                        guard !newLabelName.isEmpty else { return }
                        onSelect(nil)
                        // The actual label creation happens in the ContactsViewModel
                    }
                    .disabled(newLabelName.isEmpty)
                }
                
                Section(header: Text("Existing Labels")) {
                    ForEach(existingLabels) { label in
                        HStack {
                            Text(label.name)
                            
                            Spacer()
                            
                            if contact.labels?.contains(where: { $0.id == label.id }) ?? false {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLabel = label
                            onSelect(label)
                        }
                    }
                }
            }
            .navigationTitle("Assign Label")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    onSelect(nil)
                }
            )
        }
    }
}

// MARK: - Preview
struct ContactDetailView_Previews: PreviewProvider {
    static let sampleContact = Contact(
        id: UUID(),
        userId: UUID(),
        name: "John Doe",
        phoneNumber: "555-123-4567",
        email: "john@example.com",
        textDescription: "Met at tech conference in March. Works at Apple as a developer. Interested in AI and machine learning.",
        createdAt: Date(),
        updatedAt: Date(),
        labels: [
            Label(id: UUID(), userId: UUID(), name: "Work", createdAt: Date()),
            Label(id: UUID(), userId: UUID(), name: "Tech", createdAt: Date())
        ]
    )
    
    static var previews: some View {
        NavigationView {
            ContactDetailView(contact: sampleContact)
                .environmentObject(PreviewContactsViewModel())
        }
    }
    
    // A minimal implementation for preview
    class PreviewContactsViewModel: ContactsViewModel {
        init() {
            super.init(
                databaseService: DatabaseService(supabase: SupabaseClient(supabaseURL: URL(string: "https://example.com")!, supabaseKey: "key")),
                contactsService: ContactsService(),
                aiService: AIService(apiKey: "key"),
                userId: UUID()
            )
            
            self.labels = [
                Label(id: UUID(), userId: UUID(), name: "Work", createdAt: Date()),
                Label(id: UUID(), userId: UUID(), name: "Tech", createdAt: Date()),
                Label(id: UUID(), userId: UUID(), name: "Friend", createdAt: Date())
            ]
        }
        
        override func removeLabel(from contact: Contact, labelId: UUID) async {}
        override func assignLabel(to contact: Contact, labelId: UUID) async {}
        override func updateContactDescription(contact: Contact, newDescription: String) async {}
    }
}
