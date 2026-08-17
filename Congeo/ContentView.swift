import SwiftUI
import Foundation
import UIKit

// MARK: - Modèles et Gestionnaires de données

enum AppTier: String, CaseIterable, Identifiable {
    case free = "Gratuite (0 $)"
    case pro = "Pro (4,99 $)"
    case family = "Famille (9,99 $)"
    
    var id: String { self.rawValue }
    
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
    
    var hasAds: Bool {
        switch self {
        case .free: return true
        case .pro, .family: return false
        }
    }
}

class LicenseManager: ObservableObject {
    @Published var currentTier: AppTier = .free {
        didSet {
            registerCurrentDeviceIfNeeded()
        }
    }
    @Published private(set) var registeredDeviceIDs: [String] = []
    @Published var deviceRegistrationError: String?
    
    private let storageKey = "registeredDeviceIDs"
    
    init() {
        registeredDeviceIDs = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        registerCurrentDeviceIfNeeded()
    }
    
    func upgrade(to tier: AppTier) {
        currentTier = tier
    }
    
    func registerCurrentDeviceIfNeeded() {
        guard let deviceID = UIDevice.current.identifierForVendor?.uuidString else { return }
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
}

struct FoodItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var location: String
    var expiryDate: Date
}

class InventoryManager: ObservableObject {
    @Published var items: [FoodItem] = [
        FoodItem(name: "Steaks hachés", quantity: 4, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 5)),
        FoodItem(name: "Légumes surgelés", quantity: 2, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 30))
    ]
    
    @Published var locations: [String] = ["Maison"]
    
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
    
    func addItem(name: String, quantity: Int, location: String, expiryDate: Date, license: LicenseManager) -> Bool {
        let allowedLocations = visibleLocations(for: license.currentTier)
        guard allowedLocations.contains(location) else { return false }
        guard items.count < license.currentTier.maxItems else { return false }
        
        let newItem = FoodItem(name: name, quantity: quantity, location: location, expiryDate: expiryDate)
        items.append(newItem)
        return true
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

struct ScannedProduct: Identifiable {
    let id = UUID()
    let barcode: String
    let name: String
    let brand: String
}

struct OpenFoodFactsResponse: Decodable {
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let brands: String?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
    }
}

actor OpenFoodFactsService {
    func fetchProduct(for barcode: String) async -> ScannedProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            guard let product = decoded.product else { return nil }
            let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let validName = name, !validName.isEmpty else { return nil }
            return ScannedProduct(barcode: barcode, name: validName, brand: product.brands ?? "Marque inconnue")
        } catch {
            return nil
        }
    }
}

final class FamilySharingManager: ObservableObject {
    @Published var members: [String] = []
    private let key = "familyMembers"
    
    init() {
        members = NSUbiquitousKeyValueStore.default.array(forKey: key) as? [String] ?? []
    }
    
    func addMember(email: String) -> Bool {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.contains("@"), !members.contains(cleaned) else { return false }
        members.append(cleaned)
        NSUbiquitousKeyValueStore.default.set(members, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
        return true
    }
    
    func removeMember(at offsets: IndexSet) {
        members.remove(atOffsets: offsets)
        NSUbiquitousKeyValueStore.default.set(members, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

// MARK: - Navigation Principale

struct MainTabView: View {
    @EnvironmentObject var license: LicenseManager
    
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventaire", systemImage: "snowflake")
                }
            
            BulkScannerView()
                .tabItem {
                    Label("Scanner", systemImage: "barcode.viewfinder")
                }
            
            ObjectFinderView()
                .tabItem {
                    Label("Trouveur", systemImage: "viewfinder")
                }
            
            MealGeneratorView()
                .tabItem {
                    Label("Recettes", systemImage: "fork.knife")
                }
            
            HardwareView()
                .tabItem {
                    Label("Caméra ESP32", systemImage: "camera.viewfinder")
                }
            
            SettingsView()
                .tabItem {
                    Label("Licence & Réglages", systemImage: "gear")
                }
        }
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

// MARK: - Vues des fonctionnalités

struct InventoryView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @State private var showingAddSheet = false
    @State private var showingAddLocationSheet = false
    @State private var selectedLocation = "Maison"
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    private var filteredItems: [FoodItem] {
        if license.currentTier == .free {
            return inventory.items.filter { $0.location == availableLocations.first ?? "Maison" }
        }
        return inventory.items.filter { $0.location == selectedLocation }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if availableLocations.count > 1 {
                    Picker("Lieu", selection: $selectedLocation) {
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                
                List {
                    ForEach(filteredItems) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text("Lieu : \(item.location)").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("Qté: \(item.quantity)").bold()
                        }
                    }
                    .onDelete(perform: inventory.deleteItems)
                }
                
                if license.currentTier.hasAds {
                    Text("📢 Espace publicitaire (Version Gratuite)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .onAppear {
                if let first = availableLocations.first {
                    selectedLocation = first
                }
            }
            .navigationTitle("Stock Congélo")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAddLocationSheet = true
                    } label: {
                        Image(systemName: "building.2.crop.circle")
                    }
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddItemView(selectedLocation: selectedLocation)
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                AddLocationView()
            }
        }
    }
}

struct AddItemView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @Environment(\.dismiss) private var dismiss
    
    var selectedLocation: String
    
    @State private var name = ""
    @State private var quantity = 1
    @State private var expiryDate = Date()
    @State private var location = "Maison"
    @State private var showAlertLimit = false
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Nom de l'article", text: $name)
                if availableLocations.count > 1 {
                    Picker("Lieu", selection: $location) {
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                } else if let firstLocation = availableLocations.first {
                    Text("Lieu : \(firstLocation)")
                }
                Stepper("Quantité : \(quantity)", value: $quantity, in: 1...50)
                DatePicker("Expiration", selection: $expiryDate, displayedComponents: .date)
            }
            .onAppear {
                location = availableLocations.contains(selectedLocation) ? selectedLocation : (availableLocations.first ?? "Maison")
            }
            .navigationTitle("Ajouter un article")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let targetLocation = location.isEmpty ? (availableLocations.first ?? "Maison") : location
                        let success = inventory.addItem(
                            name: name,
                            quantity: quantity,
                            location: targetLocation,
                            expiryDate: expiryDate,
                            license: license
                        )
                        if success {
                            dismiss()
                        } else {
                            showAlertLimit = true
                        }
                    }
                }
            }
            .alert("Limite atteinte", isPresented: $showAlertLimit) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Vérifiez les limites de licence (articles et lieux).")
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
                TextField("Nom du lieu (ex: Chalet)", text: $locationName)
            }
            .navigationTitle("Ajouter un lieu")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        if inventory.addLocation(locationName, license: license) {
                            dismiss()
                        } else {
                            showError = true
                        }
                    }
                }
            }
            .alert("Impossible d'ajouter ce lieu", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Nom déjà utilisé ou limite de lieux atteinte pour cette licence.")
            }
        }
    }
}

struct BulkScannerView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var barcodeInput = ""
    @State private var scannedProducts: [ScannedProduct] = []
    @State private var isLoading = false
    @State private var selectedLocation = "Maison"
    @State private var statusMessage = ""
    
    private let service = OpenFoodFactsService()
    
    private var availableLocations: [String] {
        inventory.visibleLocations(for: license.currentTier)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Scan Bulk (codes-barres)") {
                    TextEditor(text: $barcodeInput)
                        .frame(minHeight: 100)
                    Text("Entrez plusieurs codes-barres (séparés par virgule, espace ou saut de ligne).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if availableLocations.count > 1 {
                        Picker("Lieu cible", selection: $selectedLocation) {
                            ForEach(availableLocations, id: \.self) { loc in
                                Text(loc).tag(loc)
                            }
                        }
                    }
                    Button(isLoading ? "Chargement..." : "Récupérer depuis OpenFoodFacts") {
                        Task { await scanBulk() }
                    }
                    .disabled(isLoading)
                }
                
                if !statusMessage.isEmpty {
                    Section("Statut") {
                        Text(statusMessage)
                    }
                }
                
                if !scannedProducts.isEmpty {
                    Section("Produits détectés") {
                        ForEach(scannedProducts) { product in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.name).font(.headline)
                                Text("Marque: \(product.brand)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Code-barres: \(product.barcode)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Ajouter à l'inventaire") {
                                    let ok = inventory.addItem(
                                        name: product.name,
                                        quantity: 1,
                                        location: selectedLocation,
                                        expiryDate: Date().addingTimeInterval(86400 * 30),
                                        license: license
                                    )
                                    statusMessage = ok ? "Article ajouté: \(product.name)" : "Impossible d'ajouter \(product.name) (limite licence atteinte)."
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .onAppear {
                selectedLocation = availableLocations.first ?? "Maison"
            }
            .navigationTitle("Scanner Bulk")
        }
    }
    
    private func scanBulk() async {
        let codes = parseBarcodes(from: barcodeInput)
        guard !codes.isEmpty else {
            statusMessage = "Aucun code-barres valide."
            return
        }
        
        isLoading = true
        scannedProducts = []
        statusMessage = ""
        
        var fetched: [ScannedProduct] = []
        for code in codes {
            if let product = await service.fetchProduct(for: code) {
                fetched.append(product)
            }
        }
        
        scannedProducts = fetched
        statusMessage = "Résultat: \(fetched.count) / \(codes.count) produit(s) trouvés sur OpenFoodFacts."
        isLoading = false
    }
    
    private func parseBarcodes(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",; \n\t")
        let values = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
    }
}

struct ObjectFinderView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var selectedItemID: UUID?
    @State private var isSearching = false
    @State private var found = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                if !license.currentTier.hasAILocator {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Le trouveur visuel est disponible en Pro et Famille.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    if inventory.items.isEmpty {
                        Text("Ajoutez d'abord des produits à l'inventaire.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Produit à trouver", selection: $selectedItemID) {
                            ForEach(inventory.items) { item in
                                Text(item.name).tag(Optional(item.id))
                            }
                        }
                        .pickerStyle(.menu)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                                .frame(height: 240)
                                .overlay(
                                    Text("Vue caméra iPhone")
                                        .foregroundColor(.white.opacity(0.7))
                                )
                            
                            if found {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 4)
                                    .frame(width: 180, height: 90)
                                    .offset(x: 35, y: -20)
                            }
                        }
                        
                        Text("Analyse visuelle inspirée des images de référence OpenFoodFacts.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(isSearching ? "Analyse en cours..." : "Trouver dans le frigo/congélo") {
                            runDetection()
                        }
                        .disabled(isSearching || selectedItemID == nil)
                        .buttonStyle(.borderedProminent)
                    }
                }
                Spacer()
            }
            .padding()
            .onAppear {
                selectedItemID = inventory.items.first?.id
            }
            .navigationTitle("Trouveur d'objet")
        }
    }
    
    private func runDetection() {
        isSearching = true
        found = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            found = true
            isSearching = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct HardwareView: View {
    @State private var isConnected = false
    @State private var streamURL = "http://192.168.1.50/stream"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Station ESP32-CAM (Matériel Optionnel)")) {
                    TextField("Adresse IP du module", text: $streamURL)
                    Toggle("Activer le flux vidéo", isOn: $isConnected)
                }
                
                Section(header: Text("Aperçu de la caméra (Fisheye)")) {
                    if isConnected {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 220)
                            .overlay(
                                Text("🔴 Flux direct ESP32-CAM actif\n(Porte du congélateur)")
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            )
                            .cornerRadius(8)
                    } else {
                        Text("Module déconnecté ou en veille.")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Informations du Kit")) {
                    Text("Coût de revient estimé : 15,00 $")
                    Text("Prix public conseillé : 25,00 $ (Marge fixe : 10 $)")
                }
            }
            .navigationTitle("Boîtier Matériel")
        }
    }
}

struct FamilySharingView: View {
    @StateObject private var familySharing = FamilySharingManager()
    @State private var newMemberEmail = ""
    @State private var showError = false
    
    var body: some View {
        Form {
            Section("Partager via iCloud") {
                TextField("Email d'un membre", text: $newMemberEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Ajouter le membre") {
                    if familySharing.addMember(email: newMemberEmail) {
                        newMemberEmail = ""
                    } else {
                        showError = true
                    }
                }
            }
            
            Section("Membres de la famille") {
                if familySharing.members.isEmpty {
                    Text("Aucun membre pour le moment.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(familySharing.members, id: \.self) { member in
                        Text(member)
                    }
                    .onDelete(perform: familySharing.removeMember)
                }
            }
        }
        .navigationTitle("Partage Familial")
        .alert("Adresse invalide ou déjà présente", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var license: LicenseManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Licence Actuelle")) {
                    Text("Formule : \(license.currentTier.rawValue)")
                        .bold()
                    Text("Appareils enregistrés : \(license.registeredDeviceIDs.count) / \(license.currentTier.maxDevices == Int.max ? "illimité" : "\(license.currentTier.maxDevices)")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let error = license.deviceRegistrationError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Modifier la Licence (Achat Unique)")) {
                    Button("Passer à la Version Gratuite (0 $)") {
                        license.upgrade(to: .free)
                    }
                    Button("Acheter la Version Pro (4,99 $)") {
                        license.upgrade(to: .pro)
                    }
                    Button("Acheter la Version Famille (9,99 $)") {
                        license.upgrade(to: .family)
                    }
                }
                
                if license.currentTier.hasFamilySharing {
                    Section(header: Text("Partage familial")) {
                        NavigationLink("Gérer le partage iCloud") {
                            FamilySharingView()
                        }
                    }
                }
                
                Section(header: Text("À propos")) {
                    Text("Congelo - Écosystème de gestion domestique intelligent.")
                    Text("Compatible iOS 16 et supérieur.")
                }
            }
            .navigationTitle("Réglages & Licences")
        }
    }
}
