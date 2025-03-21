import SwiftUI
import Supabase

@main
struct NoteAIApp: App {
    // Initialize app-wide dependencies and state
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// Central app state manager
class AppState: ObservableObject {
    // Supabase client
    let supabase: SupabaseClient
    
    // Authentication state
    @Published var isAuthenticated = false
    @Published var currentUser: User? = nil
    
    // Subscription state
    @Published var hasActiveSubscription = false
    
    init() {
        // Initialize Supabase client
        // Note: In a production app, these would be stored securely
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://pcchrtwfjgfoequvbufq.supabase.co")!,
            supabaseKey: "SUPABASE_API_KEY" // Replace with actual key when running
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            self.currentUser = session?.user
            self.isAuthenticated = session != nil
            
            if isAuthenticated {
                await checkSubscription()
            }
        } catch {
            print("No active session: \(error)")
        }
    }
    
    func checkSubscription() async {
        // In a real app, you'd check the user's subscription status here
        // For now, we'll just set it to false
        DispatchQueue.main.async {
            self.hasActiveSubscription = false
        }
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasActiveSubscription = false
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
