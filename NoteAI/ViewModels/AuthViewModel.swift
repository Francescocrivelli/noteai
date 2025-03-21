import Foundation
import SwiftUI
import Supabase

class AuthViewModel: ObservableObject {
    private let authService: AuthService
    private let databaseService: DatabaseService
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(authService: AuthService, databaseService: DatabaseService) {
        self.authService = authService
        self.databaseService = databaseService
    }
    
    // MARK: - Authentication Methods
    
    func signInWithGoogle() async -> Bool {
        await signIn {
            try await authService.signInWithGoogle()
        }
    }
    
    func signInWithApple() async -> Bool {
        await signIn {
            try await authService.signInWithApple()
        }
    }
    
    private func signIn(using authMethod: () async throws -> User) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Perform sign in
            let user = try await authMethod()
            
            // Check if user preferences exist, create if not
            try await ensureUserPreferencesExist(for: user.id)
            
            await MainActor.run {
                isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            
            return false
        }
    }
    
    func signOut() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await authService.signOut()
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Sign out failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func ensureUserPreferencesExist(for userId: UUID) async throws {
        // Check if user preferences already exist
        let existingPreferences = try await databaseService.getUserPreferences(userId: userId)
        
        // If not, create them
        if existingPreferences == nil {
            _ = try await databaseService.createUserPreferences(userId: userId)
        }
    }
}
