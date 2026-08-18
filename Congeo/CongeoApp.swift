import SwiftUI
import Foundation
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        return true
    }
}

@main
struct CongeoApp: App {
    // Enregistrement de l'AppDelegate pour la configuration Firebase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var groceryManager = GroceryListManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(licenseManager)
                .environmentObject(inventoryManager)
                .environmentObject(groceryManager)
        }
    }
}

// MARK: - Configuration Firebase Congélo

enum FirebaseConfig {
    static let projectID = "congelapp-70613"
    static let apiKey = "AIzaSyC2zMPmeAP4W2reM6sGrNRVgdtUgmSLZiM"
    static let storageBucket = "congelapp-70613.firebasestorage.app"
    static let bundleID = "com.christophewhite.congelo"
    static let firestoreBaseURL = "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"
}

// MARK: - Service Firestore Hybride (SDK Natif & REST Asynchrone)

@MainActor
final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var isConnectedToFirebase: Bool = true
    @Published var lastSyncTimestamp: Date? = nil
    @Published var syncErrorMessage: String? = nil
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Épicerie Familiale (Grocery List)
    
    func fetchGroceryItems() async throws -> [GroceryItem] {
        #if canImport(FirebaseFirestore)
        #if canImport(FirebaseCore)
        if FirebaseApp.app() != nil {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("grocery_items").getDocuments()
            var results: [GroceryItem] = []
            for doc in snapshot.documents {
                if let item = try? doc.data(as: GroceryItem.self) {
                    results.append(item)
                }
            }
            if !results.isEmpty {
                self.lastSyncTimestamp = Date()
                return results
            }
        }
        #endif
        #endif
        
        // Fallback REST Firestore direct
        let documentURL = URL(string: "\(FirebaseConfig.firestoreBaseURL)/family_data/grocery_list?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: documentURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if http.statusCode == 404 {
                // Le document n'existe pas encore sur Firebase
                return []
            }
            
            guard (200...299).contains(http.statusCode) else {
                throw NSError(domain: "FirebaseService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur HTTP \(http.statusCode)"])
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any],
               let rawJsonField = fields["rawJSON"] as? [String: Any],
               let rawJsonString = rawJsonField["stringValue"] as? String,
               let rawData = rawJsonString.data(using: .utf8),
               let items = try? JSONDecoder().decode([GroceryItem].self, from: rawData) {
                self.lastSyncTimestamp = Date()
                self.isConnectedToFirebase = true
                return items
            }
            return []
        } catch {
            self.syncErrorMessage = error.localizedDescription
            throw error
        }
    }
    
    func saveGroceryItems(_ items: [GroceryItem]) async throws {
        #if canImport(FirebaseFirestore)
        #if canImport(FirebaseCore)
        if FirebaseApp.app() != nil {
            let db = Firestore.firestore()
            let batch = db.batch()
            let collectionRef = db.collection("grocery_items")
            for item in items {
                let docRef = collectionRef.document(item.id.uuidString)
                if let encoded = try? Firestore.Encoder().encode(item) {
                    batch.setData(encoded, forDocument: docRef)
                }
            }
            try await batch.commit()
            self.lastSyncTimestamp = Date()
            self.isConnectedToFirebase = true
            return
        }
        #endif
        #endif
        
        // Fallback REST Firestore direct
        guard let jsonData = try? JSONEncoder().encode(items),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let documentURL = URL(string: "\(FirebaseConfig.firestoreBaseURL)/family_data/grocery_list?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: documentURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "fields": [
                "rawJSON": [
                    "stringValue": jsonString
                ],
                "itemCount": [
                    "integerValue": "\(items.count)"
                ],
                "updatedAt": [
                    "timestampValue": ISO8601DateFormatter().string(from: Date())
                ],
                "source": [
                    "stringValue": "iOS App"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            self.lastSyncTimestamp = Date()
            self.isConnectedToFirebase = true
        }
    }
    
    // MARK: - Membres du Cercle Familial (Family Members)
    
    func fetchFamilyMembers() async throws -> [String] {
        let documentURL = URL(string: "\(FirebaseConfig.firestoreBaseURL)/family_data/members?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: documentURL)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any],
               let rawJsonField = fields["membersJSON"] as? [String: Any],
               let rawJsonString = rawJsonField["stringValue"] as? String,
               let rawData = rawJsonString.data(using: .utf8),
               let members = try? JSONDecoder().decode([String].self, from: rawData) {
                self.lastSyncTimestamp = Date()
                return members
            }
            return []
        } catch {
            return []
        }
    }
    
    func saveFamilyMembers(_ members: [String]) async throws {
        guard let jsonData = try? JSONEncoder().encode(members),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let documentURL = URL(string: "\(FirebaseConfig.firestoreBaseURL)/family_data/members?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: documentURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "fields": [
                "membersJSON": [
                    "stringValue": jsonString
                ],
                "memberCount": [
                    "integerValue": "\(members.count)"
                ],
                "updatedAt": [
                    "timestampValue": ISO8601DateFormatter().string(from: Date())
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await session.data(for: request)
        self.lastSyncTimestamp = Date()
    }
    
    // MARK: - Inventaire Congélateur Partagé (Inventory Items & Locations)
    
    func fetchInventoryData() async throws -> (items: [FoodItem], locations: [String])? {
        let documentURL = URL(string: "\(FirebaseConfig.firestoreBaseURL)/family_data/inventory?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: documentURL)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any],
               let itemsRawField = fields["itemsJSON"] as? [String: Any],
               let itemsRawString = itemsRawField["stringValue"] as? String,
               let itemsData = itemsRawString.data(using: .utf8),
               let items = try? JSONDecoder().decode([FoodItem].self, from: itemsData) {
                
                var locations: [String] = ["Maison", "Chalet", "Bureau"]
                if let locField = fields["locationsJSON"] as? [String: Any],
                   let locString = locField["stringValue"] as? String,
                   let locData = locString.data(using: .utf8),
                   let decodedLoc = try? JSONDecoder().decode([String].self, from: locData) {
                    locations = decodedLoc
                }
                
                self.lastSyncTimestamp = Date()
                return (items, locations)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func saveInventoryData(items: [FoodItem], locations: [String]) async throws {
        guard let itemsData = try? JSONEncoder().encode(items),
              let itemsString = String(data: itemsData, encoding: .utf8),
              let locData = try? JSONEncoder().encode(locations),
              let locString = String(data: locData, encoding: .utf8) else {
            return
        }
        
        let documentURL = URL(string: "\(FirebaseConfig.firestoreBaseURL)/family_data/inventory?key=\(FirebaseConfig.apiKey)")!
        var request = URLRequest(url: documentURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "fields": [
                "itemsJSON": [
                    "stringValue": itemsString
                ],
                "locationsJSON": [
                    "stringValue": locString
                ],
                "itemCount": [
                    "integerValue": "\(items.count)"
                ],
                "updatedAt": [
                    "timestampValue": ISO8601DateFormatter().string(from: Date())
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await session.data(for: request)
        self.lastSyncTimestamp = Date()
    }
}

