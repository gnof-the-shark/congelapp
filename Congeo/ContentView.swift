import SwiftUI

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
    
    var hasAds: Bool {
        switch self {
        case .free: return true
        case .pro, .family: return false
        }
    }
}

class LicenseManager: ObservableObject {
    @Published var currentTier: AppTier = .free
    
    func upgrade(to tier: AppTier) {
        currentTier = tier
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
    
    @Published var locations: [String] = ["Maison", "Chalet"]
    
    func addItem(name: String, quantity: Int, location: String, expiryDate: Date, license: LicenseManager) -> Bool {
        if license.currentTier == .free && items.count >= license.currentTier.maxItems {
            return false
        }
        let newItem = FoodItem(name: name, quantity: quantity, location: location, expiryDate: expiryDate)
        items.append(newItem)
        return true
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

// MARK: - Navigation Principale

struct MainTabView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventaire", systemImage: "snowflake")
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
    @State private var selectedLocation = "Maison"

    var body: some View {
        NavigationView {
            VStack {
                if license.currentTier != .free {
                    Picker("Lieu", selection: $selectedLocation) {
                        ForEach(inventory.locations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                List {
                    ForEach(inventory.items.filter { license.currentTier == .free || $0.location == selectedLocation }) { item in
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
                
                if license.hasAds {
                    Text("📢 Espace publicitaire (Version Gratuite)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .navigationTitle("Stock Congélo")
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddItemView(selectedLocation: selectedLocation)
            }
        }
    }
}

struct AddItemView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @Environment(\.presentationMode) var presentationMode
    
    var selectedLocation: String
    
    @State private var name = ""
    @State private var quantity = 1
    @State private var expiryDate = Date()
    @State private var showAlertLimit = false

    var body: some View {
        NavigationView {
            Form {
                TextField("Nom de l'article", text: $name)
                Stepper("Quantité : \(quantity)", value: $quantity, in: 1...50)
                DatePicker("Expiration", selection: $expiryDate, displayedComponents: .date)
            }
            .navigationTitle("Ajouter un article")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let success = inventory.addItem(name: name, quantity: quantity, location: selectedLocation, expiryDate: expiryDate, license: license)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            showAlertLimit = true
                        }
                    }
                }
            }
            .alert(isPresented: $showAlertLimit) {
                Alert(title: Text("Limite atteinte"), message: Text("Passez à la version Pro ou Famille pour débloquer un inventaire illimité !"), dismissButton: .default(Text("OK")))
            }
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

struct SettingsView: View {
    @EnvironmentObject var license: LicenseManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Licence Actuelle")) {
                    Text("Formule : \(license.currentTier.rawValue)")
                        .bold()
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
                
                Section(header: Text("À propos")) {
                    Text("Congelo - Écosystème de gestion domestique intelligent.")
                    Text("Compatible iOS 16 et supérieur.")
                }
            }
            .navigationTitle("Réglages & Licences")
        }
    }
}
