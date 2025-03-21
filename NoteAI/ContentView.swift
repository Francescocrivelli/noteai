import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                if !appState.hasActiveSubscription {
                    SubscriptionView()
                } else {
                    MainView()
                }
            } else {
                AuthView()
            }
        }
    }
}

// Authentication View
struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("NoteAI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your AI-powered contact management app")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 15) {
                Button(action: {
                    // TODO: Implement Google Sign-in
                    isLoading = true
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
                    // TODO: Implement Apple Sign-in
                    isLoading = true
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
            
            if isLoading {
                ProgressView()
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
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Upgrade to NoteAI Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Unlock the full power of AI contact management")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "person.text.rectangle.fill", text: "Unlimited AI-enhanced contacts")
                FeatureRow(icon: "tag.fill", text: "Smart labeling and organization")
                FeatureRow(icon: "magnifyingglass", text: "Natural language search")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Continuous sync with iPhone contacts")
            }
            .padding()
            
            Spacer()
            
            Button(action: {
                // TODO: Implement in-app purchase
            }) {
                Text("Subscribe Now")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 40)
            
            Button(action: {
                // For demo purposes, let's just set hasActiveSubscription to true
                appState.hasActiveSubscription = true
            }) {
                Text("Skip for Demo")
                    .foregroundColor(.blue)
            }
            .padding()
            
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

// Main app interface
struct MainView: View {
    @State private var inputText = ""
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Input field for search and contact creation
            HStack {
                TextField(isSearching ? "Search contacts..." : "Add a new contact...", text: $inputText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button(action: {
                    isSearching.toggle()
                }) {
                    Image(systemName: isSearching ? "plus" : "magnifyingglass")
                        .foregroundColor(.blue)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Results list
            // This is a placeholder. Will be replaced with actual contacts list.
            List {
                Text("Sample Contact")
                Text("Sample Contact 2")
                Text("Sample Contact 3")
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle(isSearching ? "Search Contacts" : "Add Contact")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
