import Foundation

struct FoodItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var quantity: Int
    var location: String // Ex: "Maison", "Chalet"
    var expiryDate: Date
}

class InventoryManager: ObservableObject {
    @Published var items: [FoodItem] = [
        FoodItem(name: "Steaks hachés", quantity: 4, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 5)),
        FoodItem(name: "Légumes surgelés", quantity: 2, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 30))
    ]
    
    @Published var locations: [String] = ["Maison", "Chalet"]
    
    func addItem(name: String, quantity: Int, location: String, expiryDate: Date, license: LicenseManager) -> Bool {
        if license.currentTier == .free && items.count >= license.maxTierLimitCheck() {
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

extension LicenseManager {
    func maxTierLimitCheck() -> Int {
        return self.currentTier.maxItems
    }
}
