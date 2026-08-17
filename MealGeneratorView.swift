import SwiftUI

struct MealGeneratorView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    @State private var generatedRecipe = "Appuyez sur générer pour concocter un repas avec les stocks proches de péremption."

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if license.currentTier.hasAntiWasteRecipeGenerator {
                    Text("🍳 Générateur Intelligent Anti-Gaspi")
                        .font(.title2)
                        .bold()
                        .padding()
                    
                    Text(generatedRecipe)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                    Button("Générer une recette") {
                        let itemsList = inventory.items.map { $0.name }.joined(separator: ", ")
                        if itemsList.isEmpty {
                            generatedRecipe = "Votre inventaire est vide !"
                        } else {
                            generatedRecipe = "Recette suggérée basée sur : \n\(itemsList)\n\n-> Poêlée rapide anti-gaspi assaisonnée aux herbes !"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Fonction réservée à la Version Famille")
                            .font(.headline)
                        Text("Passez à la licence Famille (9,99 $) pour débloquer le générateur de repas anti-gaspi complet.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                }
                Spacer()
            }
            .navigationTitle("Recettes Anti-Gaspi")
        }
    }
}
