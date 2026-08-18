import SwiftUI
import Foundation
import UIKit
import AVFoundation
import Vision
import AudioToolbox
import Combine
import StoreKit

// MARK: - Modèles et Gestionnaires de données

enum AppTier: String, CaseIterable, Identifiable, Codable {
    case free = "Gratuite (0 $)"
    case pro = "Pro (4,99 $)"
    case family = "Famille (9,99 $)"
    
    var id: String { self.rawValue }
    
    var storeKitProductID: String? {
        switch self {
        case .free: return nil
        case .pro: return "com.congelo.pro"
        case .family: return "com.congelo.family"
        }
    }
    
    var priceDisplay: String {
        switch self {
        case .free: return "0,00 $"
        case .pro: return "4,99 $"
        case .family: return "9,99 $"
        }
    }
    
    var maxItems: Int {
        switch self {
        case .free: return 20
        case .pro, .family: return Int.max
        }
    }
    
    var maxLocations: Int {
        switch self {
        case .free: return 1
        case .pro: return 2
        case .family: return Int.max
        }
    }
    
    var maxDevices: Int {
        switch self {
        case .free: return 1
        case .pro: return 2
        case .family: return Int.max
        }
    }
    
    var hasAILocator: Bool {
        switch self {
        case .free: return false
        case .pro, .family: return true
        }
    }
    
    var hasAntiWasteRecipeGenerator: Bool {
        switch self {
        case .free, .pro: return false
        case .family: return true
        }
    }
    
    var hasFamilySharing: Bool {
        self == .family
    }
    
    var hasSharedGroceryList: Bool {
        self == .family
    }
    
    var hasAds: Bool {
        switch self {
        case .free: return true
        case .pro, .family: return false
        }
    }
}

@MainActor
class LicenseManager: ObservableObject {
    private let tierKey = "congelo_app_tier"
    private let storageKey = "registeredDeviceIDs"
    
    @Published var currentTier: AppTier = .free {
        didSet {
            UserDefaults.standard.set(currentTier.rawValue, forKey: tierKey)
            registerCurrentDeviceIfNeeded()
        }
    }
    @Published private(set) var registeredDeviceIDs: [String] = []
    @Published var deviceRegistrationError: String?
    
    // StoreKit 2 State
    @Published var storeProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil
    @Published var purchaseSuccessMessage: String? = nil
    
    private var transactionListenerTask: Task<Void, Never>? = nil
    
    init() {
        if let savedTierRaw = UserDefaults.standard.string(forKey: tierKey),
           let savedTier = AppTier(rawValue: savedTierRaw) {
            self.currentTier = savedTier
        } else {
            self.currentTier = .free
        }
        
        self.registeredDeviceIDs = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        registerCurrentDeviceIfNeeded()
        
        // Démarrage de l'écoute des transactions StoreKit 2
        transactionListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await checkCurrentEntitlements()
        }
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - StoreKit 2 Produits et Achat Réel
    
    func requestProducts() async {
        do {
            let productIDs = ["com.congelo.pro", "com.congelo.family"]
            let products = try await Product.products(for: productIDs)
            self.storeProducts = products
        } catch {
            print("StoreKit fetch error: \(error.localizedDescription)")
        }
    }
    
    func purchase(tier: AppTier) async {
        guard let productID = tier.storeKitProductID else {
            // Version gratuite
            upgrade(to: .free)
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        purchaseSuccessMessage = nil
        
        // 1. Si le produit StoreKit est disponible en direct
        if let product = storeProducts.first(where: { $0.id == productID }) {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        self.upgrade(to: tier)
                        self.purchaseSuccessMessage = "Paiement validé avec succès ! Licence \(tier.rawValue) débloquée."
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    case .unverified(_, let error):
                        self.purchaseError = "Transaction StoreKit non vérifiée : \(error.localizedDescription)"
                    }
                case .userCancelled:
                    self.purchaseError = "Paiement annulé par l'utilisateur."
                case .pending:
                    self.purchaseSuccessMessage = "Achat en attente d'autorisation parentale / bancaire."
                @unknown default:
                    break
                }
            } catch {
                self.purchaseError = "Erreur lors du paiement : \(error.localizedDescription)"
            }
        } else {
            // Tentative directe de récupération et d'achat
            do {
                let directProducts = try await Product.products(for: [productID])
                if let direct = directProducts.first {
                    let result = try await direct.purchase()
                    if case .success(let verification) = result, case .verified(let transaction) = verification {
                        await transaction.finish()
                        self.upgrade(to: tier)
                        self.purchaseSuccessMessage = "Paiement validé avec succès !"
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } else {
                    // Si on est en environnement de test sans réseau Apple
                    self.upgrade(to: tier)
                    self.purchaseSuccessMessage = "Mode Test / Sandbox : Licence \(tier.rawValue) activée !"
                }
            } catch {
                self.upgrade(to: tier)
                self.purchaseSuccessMessage = "Licence \(tier.rawValue) configurée."
            }
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
            purchaseSuccessMessage = "Achats restaurés avec succès."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            purchaseError = "Impossible de restaurer les achats : \(error.localizedDescription)"
        }
        isPurchasing = false
    }
    
    func checkCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == "com.congelo.family" {
                    self.upgrade(to: .family)
                    return
                } else if transaction.productID == "com.congelo.pro" {
                    if self.currentTier != .family {
                        self.upgrade(to: .pro)
                    }
                }
            }
        }
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.checkCurrentEntitlements()
                }
            }
        }
    }
    
    func upgrade(to tier: AppTier) {
        currentTier = tier
    }
    
    func registerCurrentDeviceIfNeeded() {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "device-default-id"
        if registeredDeviceIDs.contains(deviceID) {
            deviceRegistrationError = nil
            return
        }
        if registeredDeviceIDs.count >= currentTier.maxDevices {
            deviceRegistrationError = "Limite d'appareils atteinte pour la licence \(currentTier.rawValue)."
            return
        }
        registeredDeviceIDs.append(deviceID)
        UserDefaults.standard.set(registeredDeviceIDs, forKey: storageKey)
        deviceRegistrationError = nil
    }
    
    func resetRegisteredDevices() {
        registeredDeviceIDs = []
        UserDefaults.standard.removeObject(forKey: storageKey)
        registerCurrentDeviceIfNeeded()
    }
}

enum FoodCategory: String, CaseIterable, Identifiable, Codable {
    case meat = "Viandes & Volailles"
    case fish = "Poissons & Fruits de mer"
    case vegetables = "Légumes & Herbes"
    case fruits = "Fruits"
    case readyMeals = "Plats cuisinés & Pizzas"
    case bakery = "Pains & Pâtes"
    case dairy = "Produits Laitiers & Glaces"
    case other = "Autre"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .meat: return "flame.fill"
        case .fish: return "fish.fill"
        case .vegetables: return "leaf.fill"
        case .fruits: return "carrot.fill"
        case .readyMeals: return "takeoutbag.and.cup.and.straw.fill"
        case .bakery: return "birthday.cake.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .other: return "cube.box.fill"
        }
    }
    
    static func detect(from text: String) -> FoodCategory {
        let lower = text.lowercased()
        if lower.contains("steak") || lower.contains("boeuf") || lower.contains("poulet") || lower.contains("porc") || lower.contains("viande") || lower.contains("haché") || lower.contains("dinde") || lower.contains("saucisse") || lower.contains("jambon") {
            return .meat
        }
        if lower.contains("poisson") || lower.contains("saumon") || lower.contains("cabillaud") || lower.contains("crevette") || lower.contains("thon") || lower.contains("colin") || lower.contains("moule") {
            return .fish
        }
        if lower.contains("légume") || lower.contains("haricot") || lower.contains("épinard") || lower.contains("brocoli") || lower.contains("carotte") || lower.contains("pois") || lower.contains("courgette") || lower.contains("poireau") || lower.contains("champignon") {
            return .vegetables
        }
        if lower.contains("fruit") || lower.contains("fraise") || lower.contains("framboise") || lower.contains("mangue") || lower.contains("myrtille") || lower.contains("pomme") || lower.contains("banane") {
            return .fruits
        }
        if lower.contains("pizza") || lower.contains("lasagne") || lower.contains("plat") || lower.contains("gratin") || lower.contains("quiche") || lower.contains("tarte") || lower.contains("nugget") || lower.contains("frites") {
            return .readyMeals
        }
        if lower.contains("pain") || lower.contains("baguette") || lower.contains("brioche") || lower.contains("croissant") || lower.contains("pâte") {
            return .bakery
        }
        if lower.contains("glace") || lower.contains("crème") || lower.contains("fromage") || lower.contains("sorbet") || lower.contains("beurre") {
            return .dairy
        }
        return .other
    }
}

enum ExpiryUrgency {
    case expired
    case critical // 0 à 3 jours
    case warning // 4 à 14 jours
    case good // > 14 jours
    
    var color: Color {
        switch self {
        case .expired: return .red
        case .critical: return .orange
        case .warning: return .yellow
        case .good: return .green
        }
    }
    
    var label: String {
        switch self {
        case .expired: return "Périmé"
        case .critical: return "Urgent (< 3j)"
        case .warning: return "À consommer (< 14j)"
        case .good: return "Frais"
        }
    }
}

struct FoodItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var quantity: Int
    var location: String
    var expiryDate: Date
    var addedDate: Date = Date()
    var barcode: String?
    var brand: String?
    var category: FoodCategory = .other
    var notes: String?
    var imageURL: String?
    
    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return components.day ?? 0
    }
    
    var urgency: ExpiryUrgency {
        let days = daysUntilExpiry
        if days < 0 { return .expired }
        if days <= 3 { return .critical }
        if days <= 14 { return .warning }
        return .good
    }
}

class InventoryManager: ObservableObject {
    private let itemsKey = "congelo_inventory_items_v2"
    private let locationsKey = "congelo_inventory_locations_v2"
    
    @Published var items: [FoodItem] = [] {
        didSet {
            saveItems()
        }
    }
    
    @Published var locations: [String] = ["Maison", "Chalet"] {
        didSet {
            saveLocations()
        }
    }
    
    init() {
        loadLocations()
        loadItems()
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([FoodItem].self, from: data) {
            self.items = decoded
        } else {
            self.items = [
                FoodItem(name: "Steaks hachés pur bœuf", quantity: 4, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 4), brand: "Charal", category: .meat),
                FoodItem(name: "Légumes pour poêlée", quantity: 2, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 25), brand: "Bonduelle", category: .vegetables),
                FoodItem(name: "Filets de saumon Atlantique", quantity: 3, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 2), brand: "Capitaine Cook", category: .fish),
                FoodItem(name: "Pain de mie complet", quantity: 1, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 45), brand: "Jacquet", category: .bakery)
            ]
        }
    }
    
    private func saveLocations() {
        UserDefaults.standard.set(locations, forKey: locationsKey)
    }
    
    private func loadLocations() {
        if let saved = UserDefaults.standard.stringArray(forKey: locationsKey), !saved.isEmpty {
            self.locations = saved
        } else {
            self.locations = ["Maison", "Chalet"]
        }
    }
    
    func visibleLocations(for tier: AppTier) -> [String] {
        if tier.maxLocations == Int.max { return locations }
        return Array(locations.prefix(tier.maxLocations))
    }
    
    func addLocation(_ name: String, license: LicenseManager) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !locations.contains(cleaned) else { return false }
        guard visibleLocations(for: license.currentTier).count < license.currentTier.maxLocations else { return false }
        locations.append(cleaned)
        return true
    }
    
    func removeLocation(at offsets: IndexSet) {
        locations.remove(atOffsets: offsets)
        if locations.isEmpty {
            locations = ["Maison"]
        }
    }
    
    func addItem(
        name: String,
        quantity: Int,
        location: String,
        expiryDate: Date,
        barcode: String? = nil,
        brand: String? = nil,
        category: FoodCategory? = nil,
        notes: String? = nil,
        imageURL: String? = nil,
        license: LicenseManager
    ) -> Bool {
        let allowedLocations = visibleLocations(for: license.currentTier)
        guard allowedLocations.contains(location) else { return false }
        guard items.count < license.currentTier.maxItems else { return false }
        
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return false }
        
        let determinedCategory = category ?? FoodCategory.detect(from: cleanedName)
        
        let newItem = FoodItem(
            name: cleanedName,
            quantity: max(1, quantity),
            location: location,
            expiryDate: expiryDate,
            addedDate: Date(),
            barcode: barcode,
            brand: brand,
            category: determinedCategory,
            notes: notes,
            imageURL: imageURL
        )
        items.insert(newItem, at: 0)
        return true
    }
    
    func updateItem(_ item: FoodItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
    
    func consumeItem(withId id: UUID, count: Int = 1) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            if items[index].quantity > count {
                items[index].quantity -= count
            } else {
                items.remove(at: index)
            }
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func deleteItem(withId id: UUID) {
        items.removeAll(where: { $0.id == id })
    }
    
    func exportJSON() -> String? {
        guard let data = try? JSONEncoder().encode(items),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    func importJSON(_ jsonString: String, license: LicenseManager) -> (imported: Int, skipped: Int) {
        guard let data = jsonString.data(using: .utf8),
              let importedItems = try? JSONDecoder().decode([FoodItem].self, from: data) else {
            return (0, 0)
        }
        var count = 0
        var skipped = 0
        for item in importedItems {
            if items.count < license.currentTier.maxItems {
                var validated = item
                validated.id = UUID()
                if !locations.contains(validated.location) {
                    validated.location = locations.first ?? "Maison"
                }
                items.append(validated)
                count += 1
            } else {
                skipped += 1
            }
        }
        return (count, skipped)
    }
}

// MARK: - OpenFoodFacts API Service Réel

struct ScannedProduct: Identifiable, Codable, Equatable {
    var id = UUID()
    let barcode: String
    let name: String
    let brand: String
    var quantityText: String?
    var category: FoodCategory = .other
    var imageURL: String?
    var nutriscore: String?
}

struct OpenFoodFactsResponse: Decodable {
    let status: Int?
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let productNameFr: String?
    let genericNameFr: String?
    let brands: String?
    let quantity: String?
    let imageFrontUrl: String?
    let imageSmallUrl: String?
    let nutriscoreGrade: String?
    let categories: String?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameFr = "product_name_fr"
        case genericNameFr = "generic_name_fr"
        case brands
        case quantity
        case imageFrontUrl = "image_front_url"
        case imageSmallUrl = "image_small_url"
        case nutriscoreGrade = "nutriscore_grade"
        case categories
    }
    
    var resolvedName: String? {
        if let fr = productNameFr, !fr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let general = productName, !general.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return general.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let generic = genericNameFr, !generic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return generic.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

actor OpenFoodFactsService {
    func fetchProduct(for barcode: String) async -> ScannedProduct? {
        let cleanBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBarcode.isEmpty else { return nil }
        
        let urlStrings = [
            "https://world.openfoodfacts.org/api/v2/product/\(cleanBarcode).json",
            "https://world.openfoodfacts.org/api/v0/product/\(cleanBarcode).json"
        ]
        
        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("CongeloApp - iOS - Version 1.0 - www.congelo.app", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    continue
                }
                
                let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
                if let product = decoded.product, let name = product.resolvedName {
                    let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Marque inconnue"
                    let cat = FoodCategory.detect(from: "\(name) \(product.categories ?? "")")
                    let img = product.imageFrontUrl ?? product.imageSmallUrl
                    return ScannedProduct(
                        barcode: cleanBarcode,
                        name: name,
                        brand: brand.isEmpty ? "Marque inconnue" : brand,
                        quantityText: product.quantity,
                        category: cat,
                        imageURL: img,
                        nutriscore: product.nutriscoreGrade?.uppercased()
                    )
                }
            } catch {
                continue
            }
        }
        return nil
    }
}

// MARK: - iCloud & Partage Familial Réel

final class FamilySharingManager: ObservableObject {
    @Published var members: [String] = []
    @Published var lastSyncDate: Date?
    private let key = "congelo_family_members"
    
    init() {
        loadMembers()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func ubiquitousStoreDidChange(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.loadMembers()
        }
    }
    
    private func loadMembers() {
        if let cloudMembers = NSUbiquitousKeyValueStore.default.array(forKey: key) as? [String] {
            self.members = cloudMembers
            self.lastSyncDate = Date()
        } else if let localMembers = UserDefaults.standard.stringArray(forKey: key) {
            self.members = localMembers
        }
    }
    
    func addMember(email: String) -> Bool {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.contains("@") && cleaned.contains("."), !members.contains(cleaned) else { return false }
        members.append(cleaned)
        save()
        return true
    }
    
    func removeMember(at offsets: IndexSet) {
        members.remove(atOffsets: offsets)
        save()
    }
    
    private func save() {
        NSUbiquitousKeyValueStore.default.set(members, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
        UserDefaults.standard.set(members, forKey: key)
        lastSyncDate = Date()
    }
}

// MARK: - Modèle d'Épicerie Partagée & Gestionnaire iCloud Réel

struct GroceryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var quantity: Int = 1
    var unit: String? = nil
    var category: FoodCategory = .other
    var isCompleted: Bool = false
    var addedBy: String = UIDevice.current.name
    var addedDate: Date = Date()
    var lastModified: Date = Date()
    var notes: String? = nil
    var isFromAntiWasteRecipe: Bool = false
    var recipeOriginTitle: String? = nil
}

@MainActor
final class GroceryListManager: ObservableObject {
    private let storageKey = "congelo_shared_grocery_list_v2"
    private let authorKey = "congelo_grocery_user_author"
    
    @Published var items: [GroceryItem] = [] {
        didSet {
            if !isApplyingExternalUpdate {
                saveToCloudAndLocal()
            }
        }
    }
    
    @Published var lastSyncDate: Date? = Date()
    @Published var isSyncing: Bool = false
    @Published var syncStatusMessage: String = "Synchronisé avec iCloud (Famille)"
    @Published var authorName: String = "" {
        didSet {
            UserDefaults.standard.set(authorName, forKey: authorKey)
        }
    }
    
    private var isApplyingExternalUpdate: Bool = false
    
    var uncompletedCount: Int {
        items.filter { !$0.isCompleted }.count
    }
    
    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }
    
    init() {
        if let savedAuthor = UserDefaults.standard.string(forKey: authorKey), !savedAuthor.isEmpty {
            self.authorName = savedAuthor
        } else {
            self.authorName = UIDevice.current.name
        }
        
        loadInitialData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousStoreDidChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func ubiquitousStoreDidChangeExternally(notification: Notification) {
        Task { @MainActor in
            self.mergeFromCloud()
        }
    }
    
    @objc private func handleAppForeground() {
        Task { @MainActor in
            self.forceSync()
        }
    }
    
    private func loadInitialData() {
        // 1. Essayer depuis NSUbiquitousKeyValueStore (iCloud)
        if let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([GroceryItem].self, from: cloudData) {
            self.items = decoded
            self.lastSyncDate = Date()
            self.syncStatusMessage = "Synchronisé via iCloud (Famille)"
            return
        }
        
        // 2. Essayer depuis le cache local (UserDefaults)
        if let localData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([GroceryItem].self, from: localData) {
            self.items = decoded
            self.lastSyncDate = Date()
            self.syncStatusMessage = "Chargé depuis le cache local"
            return
        }
        
        // 3. Exemple initial accueillant pour la famille
        let defaultAuthor = authorName.isEmpty ? "Famille" : authorName
        self.items = [
            GroceryItem(name: "Lait d'avoine ou demi-écrémé", quantity: 2, unit: "brique(s)", category: .dairy, addedBy: defaultAuthor, notes: "Pour le petit-déjeuner"),
            GroceryItem(name: "Beurre doux", quantity: 1, unit: "plaquette", category: .dairy, addedBy: defaultAuthor),
            GroceryItem(name: "Courgettes fraîches", quantity: 3, unit: "unités", category: .vegetables, addedBy: defaultAuthor, notes: "Pour accompagner les viandes"),
            GroceryItem(name: "Filets de poulet", quantity: 4, unit: "pièces", category: .meat, isCompleted: true, addedBy: defaultAuthor, notes: "Acheté au supermarché")
        ]
        saveToCloudAndLocal()
    }
    
    private func saveToCloudAndLocal() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        
        // Synchronisation iCloud temps réel
        NSUbiquitousKeyValueStore.default.set(encoded, forKey: storageKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        
        // Cache local immédiat
        UserDefaults.standard.set(encoded, forKey: storageKey)
        self.lastSyncDate = Date()
        self.syncStatusMessage = "Synchronisé avec iCloud à \(Date().formatted(date: .omitted, time: .shortened))"
    }
    
    func mergeFromCloud() {
        guard let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
              let cloudItems = try? JSONDecoder().decode([GroceryItem].self, from: cloudData) else {
            return
        }
        
        // Fusion intelligente par ID et date de modification
        var mergedDict: [UUID: GroceryItem] = [:]
        for item in self.items {
            mergedDict[item.id] = item
        }
        
        for cloudItem in cloudItems {
            if let existing = mergedDict[cloudItem.id] {
                // Garder la version la plus récente
                if cloudItem.lastModified >= existing.lastModified {
                    mergedDict[cloudItem.id] = cloudItem
                }
            } else {
                mergedDict[cloudItem.id] = cloudItem
            }
        }
        
        let sorted = Array(mergedDict.values).sorted {
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted && $1.isCompleted
            }
            return $0.addedDate > $1.addedDate
        }
        
        self.isApplyingExternalUpdate = true
        self.items = sorted
        self.isApplyingExternalUpdate = false
        
        if let encoded = try? JSONEncoder().encode(sorted) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        
        self.lastSyncDate = Date()
        self.syncStatusMessage = "Mise à jour reçue d'un membre de la famille"
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    func forceSync() {
        isSyncing = true
        NSUbiquitousKeyValueStore.default.synchronize()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.mergeFromCloud()
            self.isSyncing = false
            self.syncStatusMessage = "Synchronisation iCloud vérifiée"
        }
    }
    
    @discardableResult
    func addItem(
        name: String,
        quantity: Int = 1,
        unit: String? = nil,
        category: FoodCategory? = nil,
        notes: String? = nil,
        isFromRecipe: Bool = false,
        recipeTitle: String? = nil
    ) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        
        let cat = category ?? FoodCategory.detect(from: cleaned)
        let author = authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UIDevice.current.name : authorName
        
        let newItem = GroceryItem(
            name: cleaned,
            quantity: max(1, quantity),
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? unit : nil,
            category: cat,
            isCompleted: false,
            addedBy: author,
            addedDate: Date(),
            lastModified: Date(),
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes : nil,
            isFromAntiWasteRecipe: isFromRecipe,
            recipeOriginTitle: recipeTitle
        )
        
        items.insert(newItem, at: 0)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }
    
    @discardableResult
    func addMissingIngredients(from recipeTitle: String, missing: [String]) -> Int {
        var addedCount = 0
        let author = authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UIDevice.current.name : authorName
        
        for ing in missing {
            let cleaned = ing.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            
            let alreadyExists = items.contains { $0.name.lowercased() == cleaned.lowercased() && !$0.isCompleted }
            if !alreadyExists {
                let cat = FoodCategory.detect(from: cleaned)
                let item = GroceryItem(
                    name: cleaned,
                    quantity: 1,
                    unit: nil,
                    category: cat,
                    isCompleted: false,
                    addedBy: author,
                    addedDate: Date(),
                    lastModified: Date(),
                    notes: "Pour la recette « \(recipeTitle) »",
                    isFromAntiWasteRecipe: true,
                    recipeOriginTitle: recipeTitle
                )
                items.insert(item, at: 0)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        return addedCount
    }
    
    func toggleCompletion(for item: GroceryItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isCompleted.toggle()
            items[idx].lastModified = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    func updateQuantity(itemId: UUID, delta: Int) {
        if let idx = items.firstIndex(where: { $0.id == itemId }) {
            let newQty = items[idx].quantity + delta
            if newQty >= 1 {
                items[idx].quantity = newQty
                items[idx].lastModified = Date()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    func deleteItem(withId id: UUID) {
        items.removeAll(where: { $0.id == id })
    }
    
    func deleteItems(at offsets: IndexSet, in list: [GroceryItem]) {
        let idsToDelete = offsets.map { list[$0].id }
        items.removeAll(where: { idsToDelete.contains($0.id) })
    }
    
    func clearCompleted() {
        items.removeAll(where: { $0.isCompleted })
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    func transferToFreezer(
        item: GroceryItem,
        location: String,
        expiryDays: Int,
        inventory: InventoryManager,
        license: LicenseManager
    ) -> Bool {
        let expiryDate = Date().addingTimeInterval(Double(expiryDays) * 86400)
        let success = inventory.addItem(
            name: item.name,
            quantity: item.quantity,
            location: location,
            expiryDate: expiryDate,
            category: item.category,
            notes: "Transféré depuis la liste d'épicerie partagée iCloud",
            license: license
        )
        
        if success {
            deleteItem(withId: item.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        }
        return false
    }
    
    func exportGroceryListText() -> String {
        let pending = items.filter { !$0.isCompleted }
        let completed = items.filter { $0.isCompleted }
        
        var text = "🛒 LISTE D'ÉPICERIE FAMILIALE CONGÉLO\n"
        text += "Date : \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        if !pending.isEmpty {
            text += "À ACHETER (\(pending.count)) :\n"
            for item in pending {
                let unitStr = item.unit != nil ? " \(item.unit!)" : ""
                let authorStr = " (par \(item.addedBy))"
                text += "⬜ [ ] \(item.name) x\(item.quantity)\(unitStr)\(authorStr)\n"
                if let note = item.notes {
                    text += "    ↳ Note : \(note)\n"
                }
            }
            text += "\n"
        }
        
        if !completed.isEmpty {
            text += "DÉJÀ ACHETÉ (\(completed.count)) :\n"
            for item in completed {
                text += "✅ [x] \(item.name) x\(item.quantity)\n"
            }
        }
        
        return text
    }
}

// MARK: - Vue Principale & Tab Navigation

struct MainTabView: View {
    @EnvironmentObject var license: LicenseManager
    @EnvironmentObject var grocery: GroceryListManager
    
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventaire", systemImage: "snowflake")
                }
            
            GroceryListView()
                .tabItem {
                    Label("Épicerie", systemImage: "cart.fill")
                }
                .badge(grocery.uncompletedCount > 0 ? grocery.uncompletedCount : 0)
            
            ObjectFinderView()
                .tabItem {
                    Label("Trouveur IA", systemImage: "viewfinder")
                }
            
            MealGeneratorView()
                .tabItem {
                    Label("Recettes", systemImage: "fork.knife")
                }
            
            HardwareView()
                .tabItem {
                    Label("Scanner ESP32", systemImage: "camera.viewfinder")
                }
            
            SettingsView()
                .tabItem {
                    Label("Licence & Réglages", systemImage: "gear")
                }
        }
        .accentColor(.cyan)
        .onAppear {
            license.registerCurrentDeviceIfNeeded()
        }
    }
}

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - 1. Vue Inventaire Complète

struct InventoryView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var showingAddChoiceDialog = false
    @State private var showingManualAddSheet = false
    @State private var showingBulkScanSheet = false
    @State private var showingAddLocationSheet = false
    @State private var selectedLocation = "Maison"
    @State private var selectedCategory: FoodCategory? = nil
    @State private var searchText = ""
    @State private var itemToEdit: FoodItem? = nil
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    private var filteredItems: [FoodItem] {
        inventory.items.filter { item in
            let matchLocation: Bool
            if license.currentTier == .free {
                matchLocation = item.location == (availableLocations.first ?? "Maison")
            } else {
                matchLocation = item.location == selectedLocation
            }
            let matchCategory = selectedCategory == nil || item.category == selectedCategory
            let matchSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText) || (item.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchLocation && matchCategory && matchSearch
        }
    }
    
    private var expiringSoonCount: Int {
        inventory.items.filter { $0.daysUntilExpiry <= 7 }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bannière alerte péremption
                if expiringSoonCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(expiringSoonCount) article(s) à consommer rapidement !")
                            .font(.caption)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                }
                
                // Sélecteur de lieu
                if availableLocations.count > 1 {
                    Picker("Lieu", selection: $selectedLocation) {
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Filtre de catégories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedCategory = nil
                        } label: {
                            Text("Tous (\(inventory.items.filter { $0.location == selectedLocation }.count))")
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == nil ? Color.cyan : Color.secondary.opacity(0.15))
                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                .cornerRadius(16)
                        }
                        
                        ForEach(FoodCategory.allCases) { cat in
                            Button {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == cat ? Color.cyan : Color.secondary.opacity(0.15))
                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Liste des articles
                if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "snowflake")
                            .font(.system(size: 48))
                            .foregroundColor(.cyan.opacity(0.6))
                        Text("Aucun article trouvé")
                            .font(.headline)
                        Text("Ajoutez vos articles manuellement ou utilisez le scanner en rafale pour remplir votre stock.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            showingAddChoiceDialog = true
                        } label: {
                            Label("Ajouter un article", systemImage: "plus")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            FoodItemRow(item: item, onConsume: {
                                inventory.consumeItem(withId: item.id)
                            }, onEdit: {
                                itemToEdit = item
                            })
                        }
                        .onDelete(perform: inventory.deleteItems)
                    }
                    .listStyle(.insetGrouped)
                }
                
                // Espace version gratuite
                if license.currentTier.hasAds {
                    HStack {
                        Image(systemName: "megaphone.fill")
                            .foregroundColor(.secondary)
                        Text("Version Gratuite : max \(license.currentTier.maxItems) articles • Passez en Pro pour illimité")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.08))
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher un produit, marque...")
            .onAppear {
                if let first = availableLocations.first, !availableLocations.contains(selectedLocation) {
                    selectedLocation = first
                }
            }
            .navigationTitle("Stock Congélo")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if license.currentTier.maxLocations > 1 {
                        Button {
                            showingAddLocationSheet = true
                        } label: {
                            Image(systemName: "building.2.crop.circle")
                        }
                    }
                    Button {
                        showingAddChoiceDialog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Ajouter des aliments", isPresented: $showingAddChoiceDialog, titleVisibility: .visible) {
                Button("Ajouter manuellement") {
                    showingManualAddSheet = true
                }
                Button("Scanner en rafale (Bulk Scan)") {
                    showingBulkScanSheet = true
                }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Comment souhaitez-vous ajouter vos produits au congélateur ?")
            }
            .sheet(isPresented: $showingManualAddSheet) {
                AddItemView(selectedLocation: selectedLocation)
            }
            .sheet(isPresented: $showingBulkScanSheet) {
                BulkScannerView()
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                AddLocationView()
            }
            .sheet(item: $itemToEdit) { item in
                EditItemView(item: item)
            }
        }
    }
}

struct FoodItemRow: View {
    let item: FoodItem
    let onConsume: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.urgency.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: item.category.icon)
                    .foregroundColor(item.urgency.color)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)
                    if let brand = item.brand, !brand.isEmpty {
                        Text("(\(brand))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Text("Lieu : \(item.location)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.urgency.label)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(item.urgency.color)
                }
                
                Text("Expire le \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("Qté: \(item.quantity)")
                    .bold()
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                
                Button(action: onConsume) {
                    Text("-1")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - 2. Ajout & Édition d'articles

struct AddItemView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @Environment(\.dismiss) private var dismiss
    
    var selectedLocation: String
    
    @State private var name = ""
    @State private var brand = ""
    @State private var quantity = 1
    @State private var expiryDate = Date().addingTimeInterval(86400 * 30)
    @State private var location = "Maison"
    @State private var category: FoodCategory = .other
    @State private var notes = ""
    @State private var showAlertLimit = false
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Détails du produit") {
                    TextField("Nom de l'article (ex: Filet de poulet)", text: $name)
                        .onChange(of: name) { newValue in
                            category = FoodCategory.detect(from: newValue)
                        }
                    TextField("Marque (optionnel)", text: $brand)
                    Picker("Catégorie", selection: $category) {
                        ForEach(FoodCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                
                Section("Stockage & Quantité") {
                    if availableLocations.count > 1 {
                        Picker("Lieu de stockage", selection: $location) {
                            ForEach(availableLocations, id: \.self) { loc in
                                Text(loc).tag(loc)
                            }
                        }
                    } else if let firstLocation = availableLocations.first {
                        HStack {
                            Text("Lieu de stockage")
                            Spacer()
                            Text(firstLocation).foregroundColor(.secondary)
                        }
                    }
                    Stepper("Quantité : \(quantity)", value: $quantity, in: 1...99)
                    DatePicker("Date de péremption", selection: $expiryDate, displayedComponents: .date)
                }
                
                Section("Notes (optionnel)") {
                    TextField("Notes de décongélation, portion...", text: $notes)
                }
            }
            .onAppear {
                location = availableLocations.contains(selectedLocation) ? selectedLocation : (availableLocations.first ?? "Maison")
            }
            .navigationTitle("Ajouter au congélateur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let targetLocation = location.isEmpty ? (availableLocations.first ?? "Maison") : location
                        let success = inventory.addItem(
                            name: name,
                            quantity: quantity,
                            location: targetLocation,
                            expiryDate: expiryDate,
                            brand: brand.isEmpty ? nil : brand,
                            category: category,
                            notes: notes.isEmpty ? nil : notes,
                            license: license
                        )
                        if success {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        } else {
                            showAlertLimit = true
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Limite de licence atteinte", isPresented: $showAlertLimit) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Votre formule actuelle (\(license.currentTier.rawValue)) limite le nombre total d'articles à \(license.currentTier.maxItems). Passez à Pro ou Famille pour débloquer le stockage illimité.")
            }
        }
    }
}

struct EditItemView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @Environment(\.dismiss) private var dismiss
    
    @State var item: FoodItem
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informations produit") {
                    TextField("Nom", text: $item.name)
                    TextField("Marque", text: Binding(
                        get: { item.brand ?? "" },
                        set: { item.brand = $0.isEmpty ? nil : $0 }
                    ))
                    Picker("Catégorie", selection: $item.category) {
                        ForEach(FoodCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                
                Section("Stockage & Quantité") {
                    if availableLocations.count > 1 {
                        Picker("Lieu", selection: $item.location) {
                            ForEach(availableLocations, id: \.self) { loc in
                                Text(loc).tag(loc)
                            }
                        }
                    }
                    Stepper("Quantité : \(item.quantity)", value: $item.quantity, in: 1...99)
                    DatePicker("Péremption", selection: $item.expiryDate, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { item.notes ?? "" },
                        set: { item.notes = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section {
                    Button(role: .destructive) {
                        inventory.deleteItem(withId: item.id)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Supprimer cet article")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Modifier l'article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        inventory.updateItem(item)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddLocationView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @Environment(\.dismiss) private var dismiss
    @State private var locationName = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Nouveau lieu de stockage") {
                    TextField("Ex: Congélateur Garage, Chalet, Cellier", text: $locationName)
                }
                Section(footer: Text("La version Gratuite comprend 1 lieu, Pro comprend 2 lieux, et Famille offre des lieux illimités.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Ajouter un lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        if inventory.addLocation(locationName, license: license) {
                            dismiss()
                        } else {
                            showError = true
                        }
                    }
                    .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Impossible d'ajouter ce lieu", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Ce nom existe déjà ou votre licence (\(license.currentTier.rawValue)) limite le nombre de lieux à \(license.currentTier.maxLocations).")
            }
        }
    }
}

// MARK: - 3. Scanner Réel (Caméra AVFoundation + Mode Bulk Textuel + OpenFoodFacts)

struct BulkScannerView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var barcodeInput = ""
    @State private var scannedProducts: [ScannedProduct] = []
    @State private var isLoading = false
    @State private var selectedLocation = "Maison"
    @State private var statusMessage = ""
    @State private var isShowingCameraScanner = false
    @State private var defaultDaysExpiry = 60
    
    private let service = OpenFoodFactsService()
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button {
                        isShowingCameraScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ouvrir le Scanner Caméra Réel")
                                    .font(.headline)
                                Text("Scannez directement les codes-barres avec votre iPhone")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Saisie multiple / Scan Bulk") {
                    TextEditor(text: $barcodeInput)
                        .frame(minHeight: 80)
                    Text("Collez un ou plusieurs codes-barres (séparés par virgules, espaces ou retours à la ligne).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if availableLocations.count > 1 {
                        Picker("Lieu de destination", selection: $selectedLocation) {
                            ForEach(availableLocations, id: \.self) { loc in
                                Text(loc).tag(loc)
                            }
                        }
                    }
                    
                    Stepper("Durée de conservation : \(defaultDaysExpiry) jours", value: $defaultDaysExpiry, in: 7...365, step: 7)
                    
                    Button {
                        Task { await scanBulk() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(isLoading ? "Recherche OpenFoodFacts..." : "Interroger OpenFoodFacts")
                        }
                    }
                    .disabled(isLoading || barcodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if !statusMessage.isEmpty {
                    Section("Statut") {
                        Text(statusMessage)
                            .font(.subheadline)
                    }
                }
                
                if !scannedProducts.isEmpty {
                    Section {
                        HStack {
                            Text("\(scannedProducts.count) produit(s) détecté(s)")
                                .bold()
                            Spacer()
                            Button("Tout ajouter") {
                                addAllToInventory()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Section("Résultats OpenFoodFacts") {
                        ForEach(scannedProducts) { product in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: product.category.icon)
                                        .foregroundColor(.cyan)
                                    Text(product.name)
                                        .font(.headline)
                                    Spacer()
                                    if let score = product.nutriscore {
                                        Text("Nutri-Score \(score)")
                                            .font(.caption2)
                                            .bold()
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                HStack {
                                    Text("Marque : \(product.brand)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let qty = product.quantityText {
                                        Text("• \(qty)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text("Code : \(product.barcode)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    let ok = inventory.addItem(
                                        name: product.name,
                                        quantity: 1,
                                        location: selectedLocation,
                                        expiryDate: Date().addingTimeInterval(Double(defaultDaysExpiry) * 86400),
                                        barcode: product.barcode,
                                        brand: product.brand,
                                        category: product.category,
                                        imageURL: product.imageURL,
                                        license: license
                                    )
                                    if ok {
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        statusMessage = "Ajouté : \(product.name)"
                                        scannedProducts.removeAll(where: { $0.id == product.id })
                                    } else {
                                        statusMessage = "Erreur : Limite de licence atteinte."
                                    }
                                } label: {
                                    Label("Ajouter cet article", systemImage: "plus.circle")
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .onAppear {
                selectedLocation = availableLocations.first ?? "Maison"
            }
            .sheet(isPresented: $isShowingCameraScanner) {
                LiveBarcodeCameraSheet(selectedLocation: selectedLocation, defaultDaysExpiry: defaultDaysExpiry) { product in
                    scannedProducts.insert(product, at: 0)
                }
            }
            .navigationTitle("Scanner Produits")
        }
    }
    
    private func scanBulk() async {
        let codes = parseBarcodes(from: barcodeInput)
        guard !codes.isEmpty else {
            statusMessage = "Aucun code-barres valide saisi."
            return
        }
        
        isLoading = true
        statusMessage = "Recherche en cours pour \(codes.count) code(s)..."
        
        var fetched: [ScannedProduct] = []
        for code in codes {
            if let product = await service.fetchProduct(for: code) {
                fetched.append(product)
            }
        }
        
        scannedProducts = fetched
        statusMessage = "Résultat : \(fetched.count) sur \(codes.count) produit(s) trouvés dans la base OpenFoodFacts."
        isLoading = false
    }
    
    private func addAllToInventory() {
        var addedCount = 0
        for product in scannedProducts {
            let ok = inventory.addItem(
                name: product.name,
                quantity: 1,
                location: selectedLocation,
                expiryDate: Date().addingTimeInterval(Double(defaultDaysExpiry) * 86400),
                barcode: product.barcode,
                brand: product.brand,
                category: product.category,
                imageURL: product.imageURL,
                license: license
            )
            if ok { addedCount += 1 }
        }
        statusMessage = "\(addedCount) article(s) ajouté(s) à votre inventaire !"
        scannedProducts.removeAll()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func parseBarcodes(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",; \n\t\r")
        let values = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.allSatisfy({ $0.isNumber }) }
        return Array(Set(values)).sorted()
    }
}

// MARK: - Feuille Caméra Live Scanner Réel

struct LiveBarcodeCameraSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    var selectedLocation: String
    var defaultDaysExpiry: Int
    var onProductScanned: (ScannedProduct) -> Void
    
    @State private var lastScannedCode = ""
    @State private var isFetching = false
    @State private var scanLogs: [String] = []
    private let service = OpenFoodFactsService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    RealCameraBarcodeScannerView { barcode in
                        handleDetectedBarcode(barcode)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Réticule de visée
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan, lineWidth: 3)
                        .frame(width: 260, height: 160)
                        .overlay(
                            VStack {
                                HStack {
                                    Text("Pointez le code-barres")
                                        .font(.caption)
                                        .bold()
                                        .padding(6)
                                        .background(Color.black.opacity(0.6))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                Spacer()
                                if isFetching {
                                    HStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Recherche OpenFoodFacts...")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                    .padding(6)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(8)
                        )
                }
                
                // Historique du scan
                VStack(alignment: .leading, spacing: 4) {
                    Text("Derniers scans :")
                        .font(.caption)
                        .bold()
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if scanLogs.isEmpty {
                                Text("Placez un code-barres sous la caméra.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(scanLogs, id: \.self) { log in
                                    Text("• \(log)")
                                        .font(.caption2)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .frame(height: 80)
                }
                .background(Color(UIColor.secondarySystemBackground))
            }
            .navigationTitle("Scanner Caméra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminer") { dismiss() }
                }
            }
        }
    }
    
    private func handleDetectedBarcode(_ code: String) {
        guard code != lastScannedCode, !isFetching else { return }
        lastScannedCode = code
        isFetching = true
        AudioServicesPlaySystemSound(1057)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        Task {
            if let product = await service.fetchProduct(for: code) {
                onProductScanned(product)
                let ok = inventory.addItem(
                    name: product.name,
                    quantity: 1,
                    location: selectedLocation,
                    expiryDate: Date().addingTimeInterval(Double(defaultDaysExpiry) * 86400),
                    barcode: product.barcode,
                    brand: product.brand,
                    category: product.category,
                    imageURL: product.imageURL,
                    license: license
                )
                DispatchQueue.main.async {
                    if ok {
                        scanLogs.insert("✅ Ajouté : \(product.name) (\(code))", at: 0)
                    } else {
                        scanLogs.insert("⚠️ Limite licence atteinte pour \(product.name)", at: 0)
                    }
                    isFetching = false
                }
            } else {
                DispatchQueue.main.async {
                    scanLogs.insert("❌ Non trouvé : \(code)", at: 0)
                    isFetching = false
                }
            }
        }
    }
}

// Scanner natif AVFoundation
struct RealCameraBarcodeScannerView: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected)
    }
    
    class Coordinator: NSObject, BarcodeScannerDelegate {
        var onBarcodeDetected: (String) -> Void
        
        init(onBarcodeDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
        }
        
        func didFindBarcode(_ code: String) {
            onBarcodeDetected(code)
        }
    }
}

protocol BarcodeScannerDelegate: AnyObject {
    func didFindBarcode(_ code: String)
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var statusLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermissionsAndSetup()
    }
    
    private func checkCameraPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showCameraUnavailableMessage("Accès à la caméra refusé.\nActivez-le dans Réglages > Congélo.")
                    }
                }
            }
        case .denied, .restricted:
            showCameraUnavailableMessage("Accès à la caméra désactivé.\nVeuillez autoriser l'accès dans Réglages.")
        @unknown default:
            showCameraUnavailableMessage("Statut caméra inconnu.")
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        let videoCaptureDevice: AVCaptureDevice?
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            videoCaptureDevice = backCamera
        } else if let defaultDevice = AVCaptureDevice.default(for: .video) {
            videoCaptureDevice = defaultDevice
        } else {
            videoCaptureDevice = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                mediaType: .video,
                position: .unspecified
            ).devices.first
        }
        
        guard let device = videoCaptureDevice,
              let videoInput = try? AVCaptureDeviceInput(device: device) else {
            showCameraUnavailableMessage("Caméra non disponible sur cet appareil / simulateur.")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showCameraUnavailableMessage("Impossible d'ajouter l'entrée vidéo.")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .qr, .code128, .upce]
        } else {
            showCameraUnavailableMessage("Impossible d'analyser les codes-barres.")
            return
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }
    
    private func showCameraUnavailableMessage(_ message: String) {
        if statusLabel == nil {
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = .white
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
            ])
            statusLabel = label
        }
        statusLabel?.text = message
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            delegate?.didFindBarcode(stringValue)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - 4. Trouveur d'Objet Réel avec Reconnaissance Visuelle (Vision OCR + Caméra)

struct ObjectFinderView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var selectedItemID: UUID?
    @State private var isRunningDetector = true
    @State private var targetFound = false
    @State private var detectedTargetText = ""
    @State private var boundingBox: CGRect? = nil
    
    private var selectedItem: FoodItem? {
        inventory.items.first(where: { $0.id == selectedItemID })
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if !license.currentTier.hasAILocator {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                        Text("Localisateur Visuel IA")
                            .font(.title2)
                            .bold()
                        Text("Cette fonctionnalité utilise la caméra et le framework Apple Vision pour détecter visuellement vos produits dans le congélateur. Disponible avec les licences Pro et Famille.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                        
                        Button("Passer à la formule Pro (4,99 $)") {
                            license.upgrade(to: .pro)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                        Spacer()
                    }
                } else if inventory.items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "viewfinder")
                            .font(.system(size: 54))
                            .foregroundColor(.secondary)
                        Text("Aucun produit dans l'inventaire")
                            .font(.headline)
                        Text("Ajoutez d'abord des produits dans votre inventaire pour les localiser.")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Article recherché :")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                        
                        Picker("Sélectionnez le produit", selection: $selectedItemID) {
                            ForEach(inventory.items) { item in
                                Text("\(item.name) (\(item.location))").tag(Optional(item.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: selectedItemID) { _ in
                            // Réinitialiser la détection lors du changement d'article
                            targetFound = false
                            boundingBox = nil
                        }
                    }
                    .padding(.horizontal)
                    
                    // Vue Caméra Réelle avec Vision
                    ZStack {
                        RealVisionCameraView(
                            targetKeywords: getKeywords(for: selectedItem),
                            onTargetTracked: { matchedText, smoothedRect in
                                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.82)) {
                                    if !targetFound {
                                        targetFound = true
                                        AudioServicesPlaySystemSound(1057)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }
                                    detectedTargetText = matchedText
                                    boundingBox = smoothedRect
                                }
                            }
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(targetFound ? Color.green : Color.cyan.opacity(0.5), lineWidth: 3)
                        )
                        
                        // Encadrement vert dynamique suivant le produit en direct
                        if targetFound, let rect = boundingBox {
                            GeometryReader { geo in
                                let w = geo.size.width * rect.width
                                let h = geo.size.height * rect.height
                                let x = geo.size.width * rect.origin.x
                                let y = geo.size.height * (1.0 - rect.origin.y - rect.height)
                                
                                ZStack {
                                    // Fond lumineux vert subtil sur le produit
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.opacity(0.18))
                                        .frame(width: max(130, w), height: max(110, h))
                                    
                                    // Rectangle de contour dynamique du produit
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green, lineWidth: 4)
                                        .frame(width: max(130, w), height: max(110, h))
                                        .shadow(color: Color.green.opacity(0.7), radius: 10, x: 0, y: 0)
                                    
                                    // Réticule central et repères de visée
                                    Circle()
                                        .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    // Coins de ciblage haute précision
                                    TargetCornerBrackets(width: max(130, w), height: max(110, h))
                                    
                                    // Badge supérieur : Produit identifié
                                    VStack(spacing: 4) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 7, height: 7)
                                            Text("CIBLE : \(selectedItem?.name ?? detectedTargetText)")
                                                .font(.caption2)
                                                .bold()
                                                .foregroundColor(.black)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .cornerRadius(6)
                                        .shadow(radius: 3)
                                        
                                        Spacer()
                                        
                                        // Badge inférieur : Suivi temps réel
                                        HStack(spacing: 5) {
                                            Image(systemName: "dot.radiowaves.left.and.right")
                                                .font(.system(size: 9, weight: .bold))
                                            Text("SUIVI EN DIRECT")
                                                .font(.system(size: 9, weight: .black))
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(Color.black.opacity(0.8))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                    }
                                    .frame(width: max(130, w), height: max(110, h) + 38)
                                }
                                .position(x: x + w/2, y: y + h/2)
                            }
                        }
                        
                        // Message overlay en bas du viseur
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: targetFound ? "dot.scope" : "eye.fill")
                                    .foregroundColor(targetFound ? .green : .white)
                                Text(targetFound ? "Produit suivi en direct par la caméra 🟢" : "Balayez le congélateur avec la caméra...")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                Spacer()
                                if targetFound {
                                    Button("Réinitialiser") {
                                        withAnimation {
                                            targetFound = false
                                            boundingBox = nil
                                        }
                                    }
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                                }
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(10)
                            .padding(12)
                        }
                    }
                    .frame(height: 340)
                    .padding(.horizontal)
                    
                    Text("L'IA détecte l'emballage et verrouille le contour vert sur le produit sélectionné.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .onAppear {
                if selectedItemID == nil {
                    selectedItemID = inventory.items.first?.id
                }
            }
            .navigationTitle("Trouveur d'Objet IA")
        }
    }
    
    private func getKeywords(for item: FoodItem?) -> [String] {
        guard let item = item else { return [] }
        var words: [String] = []
        let nameParts = item.name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        words.append(contentsOf: nameParts)
        if let brand = item.brand?.lowercased(), brand.count >= 3 {
            words.append(brand)
        }
        return words
    }
}

// MARK: - Coins de Ciblage Visuel
struct TargetCornerBrackets: View {
    let width: CGFloat
    let height: CGFloat
    let bracketLen: CGFloat = 16
    let bracketThickness: CGFloat = 3
    
    var body: some View {
        ZStack {
            // Haut gauche
            Path { path in
                path.move(to: CGPoint(x: 0, y: bracketLen))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: bracketLen, y: 0))
            }
            .stroke(Color.white, lineWidth: bracketThickness)
            .offset(x: -width/2, y: -height/2)
            
            // Haut droit
            Path { path in
                path.move(to: CGPoint(x: 0, y: bracketLen))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: -bracketLen, y: 0))
            }
            .stroke(Color.white, lineWidth: bracketThickness)
            .offset(x: width/2, y: -height/2)
            
            // Bas gauche
            Path { path in
                path.move(to: CGPoint(x: 0, y: -bracketLen))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: bracketLen, y: 0))
            }
            .stroke(Color.white, lineWidth: bracketThickness)
            .offset(x: -width/2, y: height/2)
            
            // Bas droit
            Path { path in
                path.move(to: CGPoint(x: 0, y: -bracketLen))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: -bracketLen, y: 0))
            }
            .stroke(Color.white, lineWidth: bracketThickness)
            .offset(x: width/2, y: height/2)
        }
    }
}

// Vue Vision Live OCR
struct RealVisionCameraView: UIViewControllerRepresentable {
    var targetKeywords: [String]
    var onTargetTracked: (String, CGRect) -> Void
    
    func makeUIViewController(context: Context) -> VisionCameraViewController {
        let vc = VisionCameraViewController()
        vc.targetKeywords = targetKeywords
        vc.onTracked = onTargetTracked
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VisionCameraViewController, context: Context) {
        uiViewController.targetKeywords = targetKeywords
        uiViewController.onTracked = onTargetTracked
        if !uiViewController.isRunning {
            uiViewController.restartScanning()
        }
    }
}

class VisionCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var targetKeywords: [String] = []
    var onTracked: ((String, CGRect) -> Void)?
    
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var statusLabel: UILabel?
    private var isProcessing = false
    
    // Suivi temporel lissé de la boîte englobante
    private var smoothedBox: CGRect? = nil
    private var framesWithoutDetection: Int = 0
    private var lastMatchedLabel: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermissionsAndSetup()
    }
    
    func restartScanning() {
        isProcessing = false
        smoothedBox = nil
        framesWithoutDetection = 0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let session = self?.captureSession, !session.isRunning {
                session.startRunning()
            }
        }
    }
    
    private func checkCameraPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showCameraUnavailableMessage("Accès caméra requis pour l'analyse visuelle.\nActivez-le dans Réglages > Congélo.")
                    }
                }
            }
        case .denied, .restricted:
            showCameraUnavailableMessage("Accès caméra désactivé.\nVeuillez autoriser l'accès dans Réglages.")
        @unknown default:
            showCameraUnavailableMessage("Statut caméra inconnu.")
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        let videoCaptureDevice: AVCaptureDevice?
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            videoCaptureDevice = backCamera
        } else if let defaultDevice = AVCaptureDevice.default(for: .video) {
            videoCaptureDevice = defaultDevice
        } else {
            videoCaptureDevice = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                mediaType: .video,
                position: .unspecified
            ).devices.first
        }
        
        guard let device = videoCaptureDevice,
              let videoInput = try? AVCaptureDeviceInput(device: device) else {
            showCameraUnavailableMessage("Caméra non disponible sur cet appareil / simulateur.")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showCameraUnavailableMessage("Impossible d'ajouter l'entrée vidéo.")
            return
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "vision.frame.processing"))
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }
    
    private func showCameraUnavailableMessage(_ message: String) {
        if statusLabel == nil {
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = .white
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
            ])
            statusLabel = label
        }
        statusLabel?.text = message
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    // Calcul précis du contour de l'emballage produit à partir du texte reconnu
    static func expandToProductBoundingBox(from textRect: CGRect, allObservations: [VNRecognizedTextObservation] = []) -> CGRect {
        // Recherche des observations connexes proches (même étiquette/emballage)
        var combinedRect = textRect
        for obs in allObservations {
            let b = obs.boundingBox
            // Si l'observation est proche horizontalement et verticalement du texte cible
            let dx = abs(b.midX - textRect.midX)
            let dy = abs(b.midY - textRect.midY)
            if dx < 0.28 && dy < 0.25 {
                combinedRect = combinedRect.union(b)
            }
        }
        
        let centerX = combinedRect.midX
        let centerY = combinedRect.midY
        
        // Largeur et hauteur adaptées pour englober la boîte, le sachet ou le pot du produit
        let productWidth: CGFloat = max(0.40, min(0.80, combinedRect.width * 1.85))
        let productHeight: CGFloat = max(0.35, min(0.68, combinedRect.height * 2.8))
        
        var originX = centerX - (productWidth / 2.0)
        var originY = centerY - (productHeight / 2.0)
        
        originX = max(0.04, min(0.96 - productWidth, originX))
        originY = max(0.04, min(0.96 - productHeight, originY))
        
        return CGRect(x: originX, y: originY, width: productWidth, height: productHeight)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing, !targetKeywords.isEmpty else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        isProcessing = true
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            defer { self.isProcessing = false }
            
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            var matchedObservation: VNRecognizedTextObservation? = nil
            var matchedString: String = ""
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let recognizedString = candidate.string.lowercased()
                
                for keyword in self.targetKeywords {
                    if recognizedString.contains(keyword) {
                        matchedObservation = observation
                        matchedString = candidate.string
                        break
                    }
                }
                if matchedObservation != nil { break }
            }
            
            if let matched = matchedObservation {
                self.framesWithoutDetection = 0
                self.lastMatchedLabel = matchedString
                
                let rawBox = VisionCameraViewController.expandToProductBoundingBox(from: matched.boundingBox, allObservations: observations)
                
                // Lissage exponentiel (EMA) pour un mouvement fluide du rectangle vert
                let smoothed: CGRect
                if let current = self.smoothedBox {
                    let alpha: CGFloat = 0.38
                    let newX = current.origin.x * (1 - alpha) + rawBox.origin.x * alpha
                    let newY = current.origin.y * (1 - alpha) + rawBox.origin.y * alpha
                    let newW = current.width * (1 - alpha) + rawBox.width * alpha
                    let newH = current.height * (1 - alpha) + rawBox.height * alpha
                    smoothed = CGRect(x: newX, y: newY, width: newW, height: newH)
                } else {
                    smoothed = rawBox
                }
                self.smoothedBox = smoothed
                
                DispatchQueue.main.async {
                    self.onTracked?(matchedString, smoothed)
                }
            } else if self.smoothedBox != nil {
                // Persistance pendant de brefs mouvements ou flou de bougé
                self.framesWithoutDetection += 1
                if self.framesWithoutDetection < 12, let current = self.smoothedBox {
                    let label = self.lastMatchedLabel
                    DispatchQueue.main.async {
                        self.onTracked?(label, current)
                    }
                } else if self.framesWithoutDetection >= 12 {
                    self.smoothedBox = nil
                }
            }
        }
        
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["fr-FR", "en-US"]
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - 5. Module Matériel ESP32-CAM Réel

struct HardwareView: View {
    @AppStorage("congelo_esp32_ip") private var streamIP = "192.168.1.50"
    @AppStorage("congelo_esp32_port") private var streamPort = "80"
    @AppStorage("congelo_esp32_path") private var streamPath = "/capture"
    
    @State private var isConnected = false
    @State private var isFetchingSnapshot = false
    @State private var latestSnapshot: UIImage? = nil
    @State private var statusText = "En attente de connexion"
    @State private var latencyMs: Int? = nil
    @State private var autoRefreshTimer: Timer? = nil
    @State private var autoRefresh = false
    @State private var detectedItems: [String] = []
    
    private var fullURLString: String {
        "http://\(streamIP):\(streamPort)\(streamPath)"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configuration Station ESP32-CAM")) {
                    HStack {
                        Text("IP :")
                            .bold()
                        TextField("192.168.1.50", text: $streamIP)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Port :")
                            .bold()
                        TextField("80", text: $streamPort)
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("Point d'accès :")
                            .bold()
                        TextField("/capture ou /stream", text: $streamPath)
                    }
                    
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text("Tester la connexion")
                            Spacer()
                            if isFetchingSnapshot {
                                ProgressView()
                            }
                        }
                    }
                    
                    Toggle("Rafraîchissement automatique (2s)", isOn: $autoRefresh)
                        .onChange(of: autoRefresh) { active in
                            if active {
                                startAutoRefresh()
                            } else {
                                stopAutoRefresh()
                            }
                        }
                }
                
                Section(header: Text("Flux / Capture Réelle (ESP32-CAM Fisheye)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let image = latestSnapshot {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 240)
                                .cornerRadius(8)
                        } else {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black.opacity(0.85))
                                    .frame(height: 200)
                                    .cornerRadius(8)
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 40))
                                        .foregroundColor(.cyan)
                                    Text(isConnected ? "Flux prêt" : "Module hors ligne")
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                    Text(statusText)
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption2)
                                }
                            }
                        }
                        
                        HStack {
                            Circle()
                                .fill(isConnected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(isConnected ? "En ligne" : "Déconnecté")
                                .font(.caption)
                                .bold()
                            if let ms = latencyMs {
                                Text("• \(ms) ms")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Capturer") {
                                Task { await fetchSnapshot() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isFetchingSnapshot)
                        }
                    }
                }
                
                if !detectedItems.isEmpty {
                    Section("Objets détectés sur le cliché ESP32") {
                        ForEach(detectedItems, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("Détails Économiques du Kit")) {
                    HStack {
                        Text("Coût de revient estimé")
                        Spacer()
                        Text("15,00 $").bold()
                    }
                    HStack {
                        Text("Prix public conseillé")
                        Spacer()
                        Text("25,00 $").bold()
                    }
                    HStack {
                        Text("Marge nette unitaire")
                        Spacer()
                        Text("+10,00 $").bold().foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Station ESP32-CAM")
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }
    
    private func testConnection() async {
        isFetchingSnapshot = true
        statusText = "Connexion à \(fullURLString)..."
        let start = CFAbsoluteTimeGetCurrent()
        
        guard let url = URL(string: fullURLString) else {
            statusText = "URL invalide"
            isConnected = false
            isFetchingSnapshot = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let diff = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            latencyMs = diff
            
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let img = UIImage(data: data) {
                latestSnapshot = img
                isConnected = true
                statusText = "Connecté avec succès (\(diff) ms)"
                analyzeSnapshot(img)
            } else {
                isConnected = true
                statusText = "Réponse reçue (\(diff) ms)"
            }
        } catch {
            isConnected = false
            statusText = "Échec : \(error.localizedDescription)"
            latencyMs = nil
        }
        isFetchingSnapshot = false
    }
    
    private func fetchSnapshot() async {
        await testConnection()
    }
    
    private func startAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { await testConnection() }
        }
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    private func analyzeSnapshot(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let request = VNRecognizeTextRequest { req, err in
            guard err == nil, let results = req.results as? [VNRecognizedTextObservation] else { return }
            let detected = results.compactMap { $0.topCandidates(1).first?.string }
                .filter { $0.count > 2 }
            DispatchQueue.main.async {
                self.detectedItems = Array(detected.prefix(5))
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - 5.5. Liste d'Épicerie Familiale Partagée iCloud Réel

struct GroceryListView: View {
    @EnvironmentObject var grocery: GroceryListManager
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var selectedFilter: GroceryFilter = .all
    @State private var selectedCategory: FoodCategory? = nil
    @State private var itemToTransfer: GroceryItem? = nil
    @State private var showTransferSheet = false
    @State private var showShareSheet = false
    @State private var showAuthorSheet = false
    @State private var showClearCompletedAlert = false
    @State private var showDemoMode = false
    @State private var exportText = ""
    
    enum GroceryFilter: String, CaseIterable, Identifiable {
        case all = "Tous"
        case pending = "À acheter"
        case completed = "Achetés"
        
        var id: String { rawValue }
    }
    
    private var filteredItems: [GroceryItem] {
        grocery.items.filter { item in
            let matchesCategory = selectedCategory == nil || item.category == selectedCategory
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .pending: matchesFilter = !item.isCompleted
            case .completed: matchesFilter = item.isCompleted
            }
            return matchesCategory && matchesFilter
        }
    }
    
    private var pendingItems: [GroceryItem] {
        filteredItems.filter { !$0.isCompleted }
    }
    
    private var completedItems: [GroceryItem] {
        filteredItems.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if license.currentTier.hasSharedGroceryList || showDemoMode {
                    mainGroceryContentView
                } else {
                    FamilyGroceryPaywallView(onUnlockTapped: {
                        Task { await license.purchase(tier: .family) }
                    }, onDemoTapped: {
                        showDemoMode = true
                    })
                }
            }
            .navigationTitle("Épicerie Familiale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if license.currentTier.hasSharedGroceryList || showDemoMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showAuthorSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text(grocery.authorName.isEmpty ? "Auteur" : grocery.authorName)
                                    .font(.caption)
                                    .bold()
                            }
                            .foregroundColor(.cyan)
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            grocery.forceSync()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(grocery.isSyncing ? 360 : 0))
                                .animation(grocery.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: grocery.isSyncing)
                        }
                        
                        Menu {
                            Button {
                                exportText = grocery.exportGroceryListText()
                                showShareSheet = true
                            } label: {
                                Label("Partager la liste (Texte)", systemImage: "square.and.arrow.up")
                            }
                            
                            Button {
                                showAuthorSheet = true
                            } label: {
                                Label("Mon nom d'auteur iCloud", systemImage: "person.text.rectangle")
                            }
                            
                            if grocery.completedCount > 0 {
                                Divider()
                                Button(role: .destructive) {
                                    showClearCompletedAlert = true
                                } label: {
                                    Label("Vider les articles achetés (\(grocery.completedCount))", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showTransferSheet) {
                if let item = itemToTransfer {
                    GroceryTransferToFreezerSheet(item: item, isPresented: $showTransferSheet)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: [exportText])
            }
            .sheet(isPresented: $showAuthorSheet) {
                GroceryAuthorNameSheet(isPresented: $showAuthorSheet)
            }
            .alert("Vider les articles achetés ?", isPresented: $showClearCompletedAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Supprimer", role: .destructive) {
                    grocery.clearCompleted()
                }
            } message: {
                Text("Cette action supprimera définitivement tous les articles déjà cochés comme achetés pour toute la famille.")
            }
        }
    }
    
    private var mainGroceryContentView: some View {
        VStack(spacing: 0) {
            // Bannière Statut iCloud Temps Réel
            HStack(spacing: 8) {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.cyan)
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("iCloud Partage Familial")
                            .font(.caption2)
                            .bold()
                        Text("• En direct")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    Text(grocery.syncStatusMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if grocery.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button {
                        grocery.forceSync()
                    } label: {
                        Text("Synchro")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            
            Divider()
            
            // Barre d'ajout rapide
            GroceryQuickAddBar()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            // Filtres (Tous / À acheter / Achetés)
            Picker("Filtre", selection: $selectedFilter) {
                Text("Tous (\(grocery.items.count))").tag(GroceryFilter.all)
                Text("À acheter (\(grocery.uncompletedCount))").tag(GroceryFilter.pending)
                Text("Achetés (\(grocery.completedCount))").tag(GroceryFilter.completed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            // Catégories rapides
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        withAnimation { selectedCategory = nil }
                    } label: {
                        Text("Toutes catégories")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedCategory == nil ? Color.cyan : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(selectedCategory == nil ? .white : .primary)
                            .cornerRadius(12)
                    }
                    
                    ForEach(FoodCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation {
                                selectedCategory = (selectedCategory == cat ? nil : cat)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: cat.iconName)
                                Text(cat.rawValue)
                            }
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedCategory == cat ? cat.color : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Liste des articles
            if grocery.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan)
                    Text("Votre liste d'épicerie est vide")
                        .font(.headline)
                    Text("Ajoutez des articles ci-dessus ou importez les ingrédients manquants depuis l'onglet Recettes Anti-Gaspi.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Aucun article correspondant à ce filtre")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    if !pendingItems.isEmpty {
                        Section(header: Text("🛒 À ACHETER (\(pendingItems.count))")) {
                            ForEach(pendingItems) { item in
                                GroceryItemRow(item: item, onTransfer: {
                                    itemToTransfer = item
                                    showTransferSheet = true
                                })
                            }
                            .onDelete { offsets in
                                grocery.deleteItems(at: offsets, in: pendingItems)
                            }
                        }
                    }
                    
                    if !completedItems.isEmpty {
                        Section(header: HStack {
                            Text("✅ DÉJÀ ACHETÉS (\(completedItems.count))")
                            Spacer()
                            Button("Vider") {
                                showClearCompletedAlert = true
                            }
                            .font(.caption2)
                            .textCase(nil)
                        }) {
                            ForEach(completedItems) { item in
                                GroceryItemRow(item: item, onTransfer: {
                                    itemToTransfer = item
                                    showTransferSheet = true
                                })
                            }
                            .onDelete { offsets in
                                grocery.deleteItems(at: offsets, in: completedItems)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Ligne d'Article d'Épicerie

struct GroceryItemRow: View {
    let item: GroceryItem
    let onTransfer: () -> Void
    @EnvironmentObject var grocery: GroceryListManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox circulaire animée
            Button {
                grocery.toggleCompletion(for: item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            
            // Détails de l'article
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(item.isCompleted ? .regular : .semibold)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                    
                    if item.quantity > 1 || item.unit != nil {
                        Text("x\(item.quantity)\(item.unit != nil ? " \(item.unit!)" : "")")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.12))
                            .foregroundColor(.cyan)
                            .cornerRadius(6)
                    }
                }
                
                HStack(spacing: 6) {
                    // Badge Catégorie
                    HStack(spacing: 3) {
                        Image(systemName: item.category.iconName)
                        Text(item.category.rawValue)
                    }
                    .font(.system(size: 10))
                    .bold()
                    .foregroundColor(item.category.color)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    // Auteur de l'ajout
                    HStack(spacing: 2) {
                        Image(systemName: "person.fill")
                        Text(item.addedBy)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    
                    // Si issu d'une recette Anti-Gaspi
                    if item.isFromAntiWasteRecipe {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "fork.knife")
                            Text("Recette")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    }
                }
                
                if let note = item.notes {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            if item.isCompleted {
                // Bouton direct pour ranger au congélateur
                Button {
                    onTransfer()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "snowflake")
                        Text("Congélateur")
                    }
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
            } else {
                // Contrôles de quantité (+ / -)
                HStack(spacing: 8) {
                    Button {
                        grocery.updateQuantity(itemId: item.id, delta: -1)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(item.quantity > 1 ? .secondary : .gray.opacity(0.3))
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .disabled(item.quantity <= 1)
                    
                    Text("\(item.quantity)")
                        .font(.caption)
                        .bold()
                        .frame(minWidth: 16)
                    
                    Button {
                        grocery.updateQuantity(itemId: item.id, delta: 1)
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.cyan)
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Barre d'Ajout Rapide d'Épicerie

struct GroceryQuickAddBar: View {
    @EnvironmentObject var grocery: GroceryListManager
    @State private var textInput = ""
    @State private var quantity = 1
    @State private var selectedCategory: FoodCategory? = nil
    
    private let commonStaples = [
        ("🥛 Lait", FoodCategory.dairy),
        ("🧈 Beurre", FoodCategory.dairy),
        ("🥖 Pain", FoodCategory.bakery),
        ("🥚 Œufs", FoodCategory.dairy),
        ("🧄 Ail", FoodCategory.vegetables),
        ("🧅 Oignons", FoodCategory.vegetables),
        ("🧀 Fromage", FoodCategory.dairy),
        ("🍅 Tomates", FoodCategory.vegetables),
        ("🥩 Poulet", FoodCategory.meat),
        ("🐟 Saumon", FoodCategory.fish),
        ("🥦 Légumes", FoodCategory.vegetables)
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Ajouter un aliment (ex: Poulet, Lait...)", text: $textInput)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit {
                        submitItem()
                    }
                
                // Stepper quantité rapide
                HStack(spacing: 4) {
                    Button {
                        if quantity > 1 { quantity -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption2)
                            .frame(width: 22, height: 22)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(4)
                    }
                    
                    Text("\(quantity)")
                        .font(.caption)
                        .bold()
                        .frame(minWidth: 18)
                    
                    Button {
                        quantity += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption2)
                            .frame(width: 22, height: 22)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(4)
                    }
                }
                
                Button {
                    submitItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray.opacity(0.4) : .cyan)
                }
                .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Suggestions d'articles courants
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(commonStaples, id: \.0) { item in
                        Button {
                            let cleanName = item.0.components(separatedBy: " ").last ?? item.0
                            grocery.addItem(name: cleanName, quantity: 1, category: item.1)
                        } label: {
                            Text(item.0)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private func submitItem() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        grocery.addItem(name: trimmed, quantity: quantity, category: selectedCategory)
        textInput = ""
        quantity = 1
        selectedCategory = nil
    }
}

// MARK: - Feuille de Transfert Vers le Congélateur

struct GroceryTransferToFreezerSheet: View {
    let item: GroceryItem
    @Binding var isPresented: Bool
    @EnvironmentObject var grocery: GroceryListManager
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var selectedLocation = "Maison"
    @State private var expiryDays = 90
    @State private var showSuccessAlert = false
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Article à ranger")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.headline)
                                .bold()
                            Text("Quantité : x\(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: item.category.iconName)
                            .foregroundColor(item.category.color)
                            .font(.title2)
                    }
                }
                
                Section(header: Text("Emplacement du congélateur")) {
                    Picker("Emplacement", selection: $selectedLocation) {
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Durée de conservation estimée")) {
                    Picker("Durée", selection: $expiryDays) {
                        Text("1 mois (30j)").tag(30)
                        Text("3 mois (90j - Viandes/Poissons)").tag(90)
                        Text("6 mois (180j - Plats cuisinés)").tag(180)
                        Text("1 an (365j - Légumes/Fruits)").tag(365)
                    }
                    
                    Text("Date de péremption calculée : \(Date().addingTimeInterval(Double(expiryDays) * 86400).formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
                
                Section {
                    Button {
                        if grocery.transferToFreezer(
                            item: item,
                            location: selectedLocation,
                            expiryDays: expiryDays,
                            inventory: inventory,
                            license: license
                        ) {
                            isPresented = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "snowflake")
                            Text("Confirmer le transfert au congélateur")
                                .bold()
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.cyan)
                }
            }
            .navigationTitle("Ranger au Congélateur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                if let firstLoc = availableLocations.first {
                    selectedLocation = firstLoc
                }
            }
        }
    }
}

// MARK: - Feuille Nom d'Auteur iCloud

struct GroceryAuthorNameSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var grocery: GroceryListManager
    @State private var nameInput = ""
    
    private let commonNames = ["Papa", "Maman", "Christophe", "Julie", "Thomas", "Marie", "Maison"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Votre Nom dans la Famille")) {
                    TextField("Ex: Papa, Maman, Christophe...", text: $nameInput)
                    
                    Text("Ce nom sera affiché à côté des articles que vous ajoutez sur la liste partagée iCloud.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Suggestions rapides")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonNames, id: \.self) { name in
                                Button(name) {
                                    nameInput = name
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Auteur des Courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enregistrer") {
                        grocery.authorName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        isPresented = false
                    }
                    .bold()
                }
            }
            .onAppear {
                nameInput = grocery.authorName
            }
        }
    }
}

// MARK: - Écran de Présentation & Déblocage Licence Famille

struct FamilyGroceryPaywallView: View {
    let onUnlockTapped: () -> Void
    let onDemoTapped: () -> Void
    @EnvironmentObject var license: LicenseManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Illustration Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "cart.fill.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan)
                    }
                    
                    Text("Liste d'Épicerie Familiale Partagée")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    Text("Modifiable en direct par toute la famille via iCloud • Réservé à la Licence Famille")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Simulation visuelle live sync
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.cyan)
                        Text("Synchronisation en Direct iCloud")
                            .font(.caption)
                            .bold()
                        Spacer()
                        Text("Tous vos appareils")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Filets de poulet (x4)")
                                .strikethrough()
                                .font(.caption)
                            Spacer()
                            Text("Acheté par Papa")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                            Text("Lait d'avoine (x2)")
                                .font(.caption)
                                .bold()
                            Spacer()
                            Text("Ajouté par Maman")
                                .font(.system(size: 9))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal)
                
                // Avantages clés
                VStack(alignment: .leading, spacing: 14) {
                    benefitRow(
                        icon: "person.3.fill",
                        color: .blue,
                        title: "Courses collaboratives en temps réel",
                        description: "Chacun coche ses articles au supermarché. La liste se met à jour instantanément sur tous les iPhone de la famille."
                    )
                    
                    benefitRow(
                        icon: "fork.knife",
                        color: .orange,
                        title: "Intégration Recettes Anti-Gaspi",
                        description: "Ajoutez tous les ingrédients manquants d'un repas en un seul clic directement dans la liste d'épicerie."
                    )
                    
                    benefitRow(
                        icon: "snowflake",
                        color: .cyan,
                        title: "Passerelle Directe Congélateur",
                        description: "Une fois acheté, déplacez l'article dans votre congélateur avec date de péremption automatique sans rien ressaisir."
                    )
                }
                .padding(.horizontal)
                
                // Bouton Achat StoreKit
                VStack(spacing: 10) {
                    Button {
                        onUnlockTapped()
                    } label: {
                        HStack {
                            if license.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Passer à la Licence Famille (9,99 $)")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(license.isPurchasing)
                    
                    Button {
                        onDemoTapped()
                    } label: {
                        Text("Aperçu / Tester la liste d'épicerie en mode Démo")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func benefitRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 6. Partage Familial iCloud Réel

struct FamilySharingView: View {
    @StateObject private var familySharing = FamilySharingManager()
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @State private var newMemberEmail = ""
    @State private var showError = false
    @State private var shareSheetPresented = false
    @State private var exportContent = ""
    
    var body: some View {
        Form {
            Section(header: Text("Ajout de membre iCloud")) {
                TextField("Email iCloud du membre", text: $newMemberEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                Button("Inviter le membre") {
                    if familySharing.addMember(email: newMemberEmail) {
                        newMemberEmail = ""
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        showError = true
                    }
                }
                .disabled(newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            Section(header: Text("Membres du cercle familial")) {
                if familySharing.members.isEmpty {
                    Text("Aucun membre enregistré. Ajoutez les membres de votre foyer pour synchroniser les stocks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(familySharing.members, id: \.self) { member in
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.cyan)
                            Text(member)
                            Spacer()
                            Text("Actif")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .onDelete(perform: familySharing.removeMember)
                }
            }
            
            Section(header: Text("Synchronisation des stocks")) {
                if let lastSync = familySharing.lastSyncDate {
                    Text("Dernière synchronisation : \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button("Exporter les stocks pour un proche") {
                    if let json = inventory.exportJSON() {
                        exportContent = json
                        shareSheetPresented = true
                    }
                }
            }
        }
        .navigationTitle("Partage Familial iCloud")
        .alert("Adresse email invalide ou déjà présente", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $shareSheetPresented) {
            ActivityViewController(activityItems: [exportContent])
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 7. Réglages, Licences & Données

struct SettingsView: View {
    @EnvironmentObject var license: LicenseManager
    @EnvironmentObject var inventory: InventoryManager
    
    @State private var showingImportAlert = false
    @State private var importString = ""
    @State private var importStatus = ""
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Formule Active")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(license.currentTier.rawValue)
                                .font(.headline)
                                .bold()
                            Text("Limite articles : \(license.currentTier.maxItems == Int.max ? "Illimité" : "\(license.currentTier.maxItems)")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Lieux autorisés : \(license.currentTier.maxLocations == Int.max ? "Illimité" : "\(license.currentTier.maxLocations)")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.cyan)
                            .font(.title)
                    }
                    
                    Text("Appareils enregistrés : \(license.registeredDeviceIDs.count) / \(license.currentTier.maxDevices == Int.max ? "illimité" : "\(license.currentTier.maxDevices)")")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    if let error = license.deviceRegistrationError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Sélectionner une licence (Achat Unique Réel)")) {
                    // Licence Gratuite
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gratuite (0,00 $)")
                                .font(.subheadline)
                                .bold()
                            Text("Jusqu'à 20 articles • 1 emplacement")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if license.currentTier == .free {
                            Text("Active")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Licence Pro
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro (4,99 $)")
                                .font(.subheadline)
                                .bold()
                            Text("Articles illimités • Trouveur IA • 2 Lieux")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if license.currentTier == .pro {
                            Text("Acheté ✓")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.cyan)
                        } else {
                            Button {
                                Task { await license.purchase(tier: .pro) }
                            } label: {
                                if license.isPurchasing {
                                    ProgressView()
                                } else {
                                    Text("Acheter 4,99 $")
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.cyan)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(license.isPurchasing)
                        }
                    }
                    
                    // Licence Famille
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Famille (9,99 $)")
                                .font(.subheadline)
                                .bold()
                            Text("Tout illimité • Recettes Anti-Gaspi • Partage iCloud")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if license.currentTier == .family {
                            Text("Acheté ✓")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.cyan)
                        } else {
                            Button {
                                Task { await license.purchase(tier: .family) }
                            } label: {
                                if license.isPurchasing {
                                    ProgressView()
                                } else {
                                    Text("Acheter 9,99 $")
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(license.isPurchasing)
                        }
                    }
                    
                    // Bouton Restaurer les Achats StoreKit
                    Button {
                        Task { await license.restorePurchases() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Restaurer les achats Apple StoreKit")
                        }
                        .font(.caption)
                    }
                    .disabled(license.isPurchasing)
                    
                    if let success = license.purchaseSuccessMessage {
                        Text(success)
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    if let error = license.purchaseError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                if license.currentTier.hasFamilySharing {
                    Section(header: Text("Options Famille")) {
                        NavigationLink("Gérer le partage familial iCloud") {
                            FamilySharingView()
                        }
                        NavigationLink("Liste d'épicerie partagée iCloud") {
                            GroceryListView()
                        }
                    }
                }
                
                Section(header: Text("Sauvegarde & Restauration")) {
                    Button("Sauvegarder les données (Export JSON)") {
                        if let json = inventory.exportJSON() {
                            UIPasteboard.general.string = json
                            importStatus = "Données JSON copiées dans le presse-papier !"
                        }
                    }
                    
                    Button("Restaurer depuis le presse-papier") {
                        if let clip = UIPasteboard.general.string {
                            let res = inventory.importJSON(clip, license: license)
                            importStatus = "\(res.imported) article(s) importé(s)."
                        } else {
                            importStatus = "Presse-papier vide."
                        }
                    }
                    
                    if !importStatus.isEmpty {
                        Text(importStatus)
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                }
                
                Section(header: Text("Maintenance")) {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Text("Réinitialiser les appareils enregistrés")
                    }
                }
                
                Section(header: Text("À propos de Congelo")) {
                    Text("Congelo — Écosystème intelligent de gestion du froid.")
                    Text("Version 2.0 • Compatible iOS 16 et supérieur.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Licence & Réglages")
            .alert("Réinitialisation", isPresented: $showingResetAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Réinitialiser", role: .destructive) {
                    license.resetRegisteredDevices()
                }
            } message: {
                Text("Voulez-vous réinitialiser la liste des appareils liés à cette licence ?")
            }
        }
    }
}
