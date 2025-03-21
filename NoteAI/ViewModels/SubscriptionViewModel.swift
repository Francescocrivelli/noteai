import Foundation
import StoreKit
import Supabase

class SubscriptionViewModel: ObservableObject {
    private let storeKitService: StoreKitService
    
    @Published var monthlyProduct: Product?
    @Published var yearlyProduct: Product?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var purchaseSuccessful = false
    
    init(storeKitService: StoreKitService) {
        self.storeKitService = storeKitService
        
        // Load products
        Task {
            await loadProducts()
        }
    }
    
    func loadProducts() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // First, make sure products are loaded in the service
        if storeKitService.products.isEmpty {
            await storeKitService.loadProducts()
        }
        
        // Find monthly and yearly subscription products
        for product in storeKitService.products {
            if product.id == "com.recursivestudio.ai.noteai.monthly" {
                await MainActor.run {
                    self.monthlyProduct = product
                }
            } else if product.id == "com.recursivestudio.ai.noteai.yearly" {
                await MainActor.run {
                    self.yearlyProduct = product
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func purchaseMonthlySubscription(userId: UUID) async {
        guard let product = monthlyProduct else {
            await MainActor.run {
                errorMessage = "Monthly subscription product not available"
            }
            return
        }
        
        await purchase(product: product, userId: userId)
    }
    
    func purchaseYearlySubscription(userId: UUID) async {
        guard let product = yearlyProduct else {
            await MainActor.run {
                errorMessage = "Yearly subscription product not available"
            }
            return
        }
        
        await purchase(product: product, userId: userId)
    }
    
    private func purchase(product: Product, userId: UUID) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            purchaseSuccessful = false
        }
        
        do {
            let transaction = try await storeKitService.purchase(product: product, userId: userId)
            
            await MainActor.run {
                isLoading = false
                purchaseSuccessful = transaction != nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
        }
    }
    
    func restorePurchases() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Request Apple to restore purchases
            try await AppStore.sync()
            
            // Update the purchased products list
            await storeKitService.updatePurchasedProducts()
            
            await MainActor.run {
                isLoading = false
                purchaseSuccessful = !storeKitService.purchasedProductIds.isEmpty
            }
            
            if !storeKitService.purchasedProductIds.isEmpty {
                // Purchase was restored, we don't need to check database as
                // StoreKitService's listener should update the database
            } else {
                await MainActor.run {
                    errorMessage = "No purchases to restore"
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
    }
    
    // Format the price of a product for display
    func formattedPrice(for product: Product?) -> String {
        guard let product = product else {
            return "N/A"
        }
        
        return product.displayPrice
    }
    
    // Check subscription status
    func checkSubscriptionStatus(userId: UUID) async -> Bool {
        return await storeKitService.hasActiveSubscription(userId: userId)
    }
}
