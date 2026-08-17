import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventaire", systemImage: "refrigerator")
                }
            
            MealGeneratorView()
                .tabItem {
                    Label("Recettes", systemImage: "fork.knife")
                }
        }
    }
}

// Modèle de données pour les aliments
struct FoodItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: Int
    var expiryDate: String
    var location: String
}

// Vue d'inventaire avec sauvegarde locale
struct InventoryView: View {
    @AppStorage("saved_items") private var savedItemsData: Data = Data()
    @State private var items: [FoodItem] = []
    
    let freeLimit = 20
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Mon Inventaire")
                            .font(.largeTitle)
                            .bold()
                        Text("\(items.count) / \(freeLimit) articles (Version Gratuite)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                List {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text("Lieu : \(item.location)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Qté : \(item.quantity)")
                                    .bold()
                                Text("Exp: \(item.expiryDate)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItem)
                }
                
                Button(action: addItem) {
                    Label("Ajouter un article", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear {
                loadItems()
            }
        }
    }
    
    func addItem() {
        if items.count < freeLimit {
            let newItem = FoodItem(id: UUID(), name: "Nouveau produit", quantity: 1, expiryDate: "30/12/2026", location: "Maison")
            items.append(newItem)
            saveItems()
        }
    }
    
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveItems()
    }
    
    // Sauvegarde les articles en arrière-plan
    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            savedItemsData = encoded
        }
    }
    
    // Charge les articles sauvegardés au démarrage
    func loadItems() {
        if let decoded = try? JSONDecoder().decode([FoodItem].self, from: savedItemsData) {
            items = decoded
        } else if items.isEmpty {
            // Éléments par défaut si la liste est vide au premier lancement
            items = [
                FoodItem(id: UUID(), name: "Steaks hachés", quantity: 4, expiryDate: "15/09/2026", location: "Congélateur - Bac 1"),
                FoodItem(id: UUID(), name: "Pains burger", quantity: 6, expiryDate: "28/08/2026", location: "Congélateur - Bac 2"),
                FoodItem(id: UUID(), name: "Légumes du jardin", quantity: 2, expiryDate: "10/10/2026", location: "Maison")
            ]
            saveItems()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
