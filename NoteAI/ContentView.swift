import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                if !appState.hasCompletedOnboarding {
                    OnboardingView()
                        .environmentObject(appState.onboardingViewModel())
                } else if !appState.hasActiveSubscription {
                    SubscriptionView()
                        .environmentObject(appState.subscriptionViewModel())
                } else {
                    MainView()
                        .environmentObject(appState.contactsViewModel())
                }
            } else {
                AuthView()
                    .environmentObject(appState.authViewModel())
            }
        }
    }
}

// Authentication View
struct AuthView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App logo and title
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("NoteAI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your AI-powered contact management")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Sign-in buttons
            VStack(spacing: 15) {
                Button(action: {
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                }
                
                Button(action: {
                    Task {
                        await viewModel.signInWithApple()
                    }
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)
            
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

// Subscription View
struct SubscriptionView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: SubscriptionViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Title
            Text("Upgrade to NoteAI Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Unlock the full power of AI contact management")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "person.text.rectangle.fill", text: "Unlimited AI-enhanced contacts")
                FeatureRow(icon: "tag.fill", text: "Smart labeling and organization")
                FeatureRow(icon: "magnifyingglass", text: "Natural language search")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Continuous sync with iPhone contacts")
            }
            .padding()
            
            Spacer()
            
            // Subscription options
            VStack(spacing: 15) {
                // Monthly option
                Button(action: {
                    Task {
                        if let userId = appState.currentUser?.id {
                            await viewModel.purchaseMonthlySubscription(userId: UUID(uuidString: userId)!)
                            if viewModel.purchaseSuccessful {
                                appState.setSubscriptionActive()
                            }
                        }
                    }
                }) {
                    HStack {
                        Text("Monthly")
                            .fontWeight(.bold)
                        Spacer()
                        Text(viewModel.monthlyProduct != nil ? viewModel.formattedPrice(for: viewModel.monthlyProduct) : "$3.99/month")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Yearly option
                Button(action: {
                    Task {
                        if let userId = appState.currentUser?.id {
                            await viewModel.purchaseYearlySubscription(userId: UUID(uuidString: userId)!)
                            if viewModel.purchaseSuccessful {
                                appState.setSubscriptionActive()
                            }
                        }
                    }
                }) {
                    HStack {
                        Text("Yearly (Save 25%)")
                            .fontWeight(.bold)
                        Spacer()
                        Text(viewModel.yearlyProduct != nil ? viewModel.formattedPrice(for: viewModel.yearlyProduct) : "$29.99/year")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)
            
            // Restore purchases
            Button(action: {
                Task {
                    await viewModel.restorePurchases()
                    if viewModel.purchaseSuccessful {
                        appState.setSubscriptionActive()
                    }
                }
            }) {
                Text("Restore Purchases")
                    .foregroundColor(.blue)
            }
            .padding()
            
            // DEMO MODE ONLY - Remove in production
            Button(action: {
                appState.setSubscriptionActive()
            }) {
                Text("Skip for Demo")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.bottom)
            
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

// Feature row for subscription view
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
            
            Text(text)
                .font(.body)
        }
    }
}

// Onboarding View
struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Welcome to NoteAI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Let's set up your contacts")
                .font(.headline)
            
            Spacer()
            
            // Import progress
            if viewModel.isLoading {
                VStack(spacing: 15) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                    
                    Text("Importing \(viewModel.contactsImported) of \(viewModel.totalContacts) contacts...")
                        .font(.caption)
                }
                .padding()
            } else {
                // Import options
                VStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await viewModel.importContacts()
                            if viewModel.hasCompletedOnboarding {
                                appState.setOnboardingCompleted()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Import Contacts")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.skipOnboarding()
                            if viewModel.hasCompletedOnboarding {
                                appState.setOnboardingCompleted()
                            }
                        }
                    }) {
                        Text("Start Fresh")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 40)
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

// Main app interface
struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ContactsViewModel
    @State private var inputText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Input field for search/add/command
                VStack(spacing: 10) {
                    HStack {
                        TextField(placeholderText, text: $inputText)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .submitLabel(.done)
                            .onSubmit {
                                submitInput()
                            }
                        
                        Button(action: {
                            toggleMode()
                        }) {
                            Image(systemName: modeIcon)
                                .foregroundColor(.accentColor)
                                .padding(8)
                        }
                    }
                    
                    // Mode indicator
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            viewModel.setMode(.add)
                        }) {
                            Text("Add")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.inputMode == .add ? Color.accentColor : Color.clear)
                                .foregroundColor(viewModel.inputMode == .add ? .white : .primary)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            viewModel.setMode(.search)
                        }) {
                            Text("Search")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.inputMode == .search ? Color.accentColor : Color.clear)
                                .foregroundColor(viewModel.inputMode == .search ? .white : .primary)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            viewModel.setMode(.command)
                        }) {
                            Text("Command")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.inputMode == .command ? Color.accentColor : Color.clear)
                                .foregroundColor(viewModel.inputMode == .command ? .white : .primary)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Loading indicator or error message
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                // Results list
                List {
                    ForEach(viewModel.filteredContacts) { contact in
                        ContactRow(contact: contact)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteContact(contactId: contact.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("NoteAI")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await appState.signOut()
                        }
                    }) {
                        Text("Sign Out")
                    }
                }
            }
        }
        .onAppear {
            // Load data when view appears
            Task {
                await viewModel.loadContacts()
                await viewModel.loadLabels()
            }
        }
    }
    
    // Dynamic placeholder text based on mode
    private var placeholderText: String {
        switch viewModel.inputMode {
        case .add:
            return "Add a new contact..."
        case .search:
            return "Search contacts..."
        case .command:
            return "Enter a command (e.g., 'create label Investors')..."
        }
    }
    
    // Icon for the mode toggle button
    private var modeIcon: String {
        switch viewModel.inputMode {
        case .add:
            return "magnifyingglass"
        case .search:
            return "plus"
        case .command:
            return "person.fill"
        }
    }
    
    // Toggle between input modes
    private func toggleMode() {
        switch viewModel.inputMode {
        case .add:
            viewModel.setMode(.search)
        case .search:
            viewModel.setMode(.command)
        case .command:
            viewModel.setMode(.add)
        }
    }
    
    // Process the input text
    private func submitInput() {
        guard !inputText.isEmpty else { return }
        
        Task {
            await viewModel.processInput(inputText)
            inputText = ""
        }
    }
}

// Contact row in the list
struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name ?? "Unknown")
                .font(.headline)
            
            if let phone = contact.phoneNumber {
                Text(phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(contact.textDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let labels = contact.labels, !labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(labels) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
