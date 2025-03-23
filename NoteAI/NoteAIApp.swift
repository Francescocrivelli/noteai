import SwiftUI
import Supabase

@main
struct NoteAIApp: App {
    // Initialize app-wide state
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
    
    // Services
    private(set) lazy var authService = AuthService(supabase: supabase)
    private(set) lazy var databaseService = DatabaseService(supabase: supabase)
    private(set) lazy var contactsService = ContactsService()
    private(set) lazy var aiService = AIService(apiKey: openAIKey)
    private(set) lazy var storeKitService = StoreKitService(databaseService: databaseService)
    
    // View Models (created when needed)
    private var _authViewModel: AuthViewModel?
    private var _subscriptionViewModel: SubscriptionViewModel?
    private var _contactsViewModel: ContactsViewModel?
    private var _onboardingViewModel: OnboardingViewModel?
    
    // Subscription state
    @Published var hasActiveSubscription = false
    @Published var hasCompletedOnboarding = false
    
    // API keys from ConfigurationManager
    private let openAIKey: String
    private let supabaseURL: URL
    private let supabaseKey: String
    
    init() {
        // Get configuration values
        let configManager = ConfigurationManager.shared
        openAIKey = configManager.value(forKey: .openAIAPIKey) ?? ""
        supabaseKey = configManager.value(forKey: .supabaseKey) ?? ""
        let supabaseURLString = configManager.value(forKey: .supabaseURL) ?? ""
        supabaseURL = URL(string: supabaseURLString)!
        
        // Initialize Supabase client
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
        
        // For development, enable these to bypass authentication and subscription
        #if DEBUG
        // isAuthenticated = true
        // hasCompletedOnboarding = true
        // hasActiveSubscription = true
        #endif
    }
    
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            self.currentUser = session?.user
            self.isAuthenticated = session != nil
            
            if isAuthenticated {
                await checkSubscription()
                await checkOnboardingStatus()
            }
        } catch {
            print("No active session: \(error)")
        }
    }
    
    func checkSubscription() async {
        if let userId = currentUser?.id {
            let hasSubscription = await storeKitService.hasActiveSubscription(userId: UUID(uuidString: userId)!)
            
            DispatchQueue.main.async {
                self.hasActiveSubscription = hasSubscription
            }
        }
    }
    
    func checkOnboardingStatus() async {
        if let userId = currentUser?.id {
            do {
                let preferences = try await databaseService.getUserPreferences(userId: UUID(uuidString: userId)!)
                
                DispatchQueue.main.async {
                    self.hasCompletedOnboarding = preferences?.hasCompletedOnboarding ?? false
                }
            } catch {
                print("Failed to get user preferences: \(error)")
                DispatchQueue.main.async {
                    self.hasCompletedOnboarding = false
                }
            }
        }
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasActiveSubscription = false
                self.hasCompletedOnboarding = false
                
                // Clear view models
                self._authViewModel = nil
                self._subscriptionViewModel = nil
                self._contactsViewModel = nil
                self._onboardingViewModel = nil
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    // MARK: - View Model Providers
    
    func authViewModel() -> AuthViewModel {
        if _authViewModel == nil {
            _authViewModel = AuthViewModel(authService: authService, databaseService: databaseService)
        }
        return _authViewModel!
    }
    
    func subscriptionViewModel() -> SubscriptionViewModel {
        if _subscriptionViewModel == nil {
            _subscriptionViewModel = SubscriptionViewModel(storeKitService: storeKitService)
        }
        return _subscriptionViewModel!
    }
    
    func contactsViewModel() -> ContactsViewModel {
        if _contactsViewModel == nil, let userId = currentUser?.id {
            _contactsViewModel = ContactsViewModel(
                databaseService: databaseService,
                contactsService: contactsService,
                aiService: aiService,
                userId: UUID(uuidString: userId)!
            )
        }
        return _contactsViewModel!
    }
    
    func onboardingViewModel() -> OnboardingViewModel {
        if _onboardingViewModel == nil, let userId = currentUser?.id {
            _onboardingViewModel = OnboardingViewModel(
                contactsService: contactsService,
                databaseService: databaseService,
                aiService: aiService,
                userId: UUID(uuidString: userId)!
            )
        }
        return _onboardingViewModel!
    }
    
    // Method to mark onboarding as completed
    func setOnboardingCompleted() {
        DispatchQueue.main.async {
            self.hasCompletedOnboarding = true
        }
    }
    
    // Method to mark subscription as active
    func setSubscriptionActive() {
        DispatchQueue.main.async {
            self.hasActiveSubscription = true
        }
    }
}
