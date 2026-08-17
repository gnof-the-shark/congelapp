import SwiftUI

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
