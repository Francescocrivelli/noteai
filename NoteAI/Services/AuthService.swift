import Foundation
import Supabase
import AuthenticationServices
import SwiftUI
import UIKit

class AuthService: NSObject, ObservableObject {
    private let supabase: SupabaseClient
    private var continueBlock: ((URL) -> Void)?
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // Sign in with Apple
    func signInWithApple() async throws -> User {
        // Get Apple's OAuth URL and initiate sign-in
        let signInRequest = try await supabase.auth.signInWithOAuth(
            provider: .apple,
            redirectTo: URL(string: "noteai://auth-callback")
        )
        
        // Present ASWebAuthenticationSession for Sign In with Apple
        let (url, urlPromise) = createURLHandlerPromise()
        
        // Open the URL in ASWebAuthenticationSession
        await openURL(signInRequest.url, url)
        
        // Create session from the callback URL
        let session = try await supabase.auth.session(from: try await urlPromise.value)
        guard let user = session?.user else {
            throw AuthError.noUserFound
        }
        
        return user
    }
    
    // Sign in with Google
    func signInWithGoogle() async throws -> User {
        // Get Google's OAuth URL and initiate sign-in
        let signInRequest = try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "noteai://auth-callback")
        )
        
        // Create a promise to handle the URL callback
        let (url, urlPromise) = createURLHandlerPromise()
        
        // Open the URL in ASWebAuthenticationSession
        await openURL(signInRequest.url, url)
        
        // Create session from the callback URL
        let session = try await supabase.auth.session(from: try await urlPromise.value)
        guard let user = session?.user else {
            throw AuthError.noUserFound
        }
        
        return user
    }
    
    // Sign out the current user
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    // MARK: - Helper Methods
    
    // Create a promise to handle the URL callback
    private func createURLHandlerPromise() -> ((URL) -> Void, Task<URL, Error>) {
        var urlBlock: ((URL) -> Void)?
        
        let task = Task<URL, Error> {
            try await withCheckedThrowingContinuation { continuation in
                urlBlock = { url in
                    continuation.resume(returning: url)
                }
            }
        }
        
        return (urlBlock!, task)
    }
    
    // Open the URL in ASWebAuthenticationSession
    @MainActor
    private func openURL(_ url: URL, _ completion: @escaping (URL) -> Void) {
        continueBlock = completion
        
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "noteai"
        ) { [weak self] callbackURL, error in
            guard error == nil, let callbackURL = callbackURL else {
                return
            }
            
            self?.continueBlock?(callbackURL)
        }
        
        session.presentationContextProvider = ASWebAuthenticationPresentationContextProviding()
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }
}

// Error type for auth operations
enum AuthError: Error {
    case noUserFound
}

// Helper for ASWebAuthenticationSession
class ASWebAuthenticationPresentationContextProviding: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the key window from the current app
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        return window
    }
}
