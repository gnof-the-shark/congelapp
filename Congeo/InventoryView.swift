import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @State private var showingAddSheet = false
    @State private var selectedLocation = "Maison"

    var body: some View {
        NavigationView {
            VStack {
                // Filtre des lieux si Pro ou Famille
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
