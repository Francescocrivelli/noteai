import Foundation
import StoreKit
import Supabase

class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIds = Set<String>()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let databaseService: DatabaseService
    private let productIdentifiers = ["com.recursivestudio.ai.noteai.monthly", "com.recursivestudio.ai.noteai.yearly"]
    private var updateListenerTask: Task<Void, Error>?
    
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
        
        // Start listening for transactions
        updateListenerTask = listenForTransactions()
        
        // Load products
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Load products from App Store Connect
    @MainActor
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: Set(productIdentifiers))
            products = storeProducts
            await updatePurchasedProducts()
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // Purchase a product
    @MainActor
    func purchase(product: Product, userId: UUID) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)
                
                // Record purchase in the database
                try await recordPurchase(productId: product.id, transaction: transaction, userId: userId)
                
                // Update purchased products
                await updatePurchasedProducts()
                
                isLoading = false
                return transaction
                
            case .userCancelled:
                isLoading = false
                return nil
                
            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval."
                return nil
                
            default:
                isLoading = false
                errorMessage = "Purchase failed for an unknown reason."
                return nil
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to purchase product: \(error.localizedDescription)"
            throw error
        }
    }
    
    // Update the purchased products list
    @MainActor
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.revocationDate == nil {
                    // If the transaction hasn't been revoked, add it to the list
                    purchasedProductIds.insert(transaction.productID)
                } else {
                    // If the transaction has been revoked, remove it from the list
                    purchasedProductIds.remove(transaction.productID)
                }
                
                // Finish the transaction so it's not processed again
                await transaction.finish()
            } catch {
                // Transaction not verified, ignore it
                continue
            }
        }
    }
    
    // Listen for transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver the purchased content
                    await self.updatePurchasedProducts()
                    
                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    // Transaction not verified, ignore it
                }
            }
        }
    }
    
    // Verify the transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Record the purchase in the database
    private func recordPurchase(productId: String, transaction: Transaction, userId: UUID) async throws {
        let subscription = Subscription(
            id: UUID(),
            userId: userId,
            productId: productId,
            originalTransactionId: transaction.originalID,
            latestTransactionId: transaction.id,
            status: "active",
            expirationDate: transaction.expirationDate,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        _ = try await databaseService.createSubscription(subscription: subscription)
    }
    
    // Check if the user has an active subscription
    func hasActiveSubscription(userId: UUID) async -> Bool {
        do {
            if let subscription = try await databaseService.getSubscription(userId: userId) {
                if let expirationDate = subscription.expirationDate, expirationDate > Date() {
                    return true
                }
            }
            
            return await checkStorePurchases()
        } catch {
            return await checkStorePurchases()
        }
    }
    
    // Check if there are any current purchases in the App Store
    private func checkStorePurchases() async -> Bool {
        await updatePurchasedProducts()
        return !purchasedProductIds.isEmpty
    }
}

// Errors for StoreKit operations
enum StoreError: Error {
    case failedVerification
    case unknown
}
