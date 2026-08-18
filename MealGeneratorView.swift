import SwiftUI
import UIKit

// MARK: - Modèles de Recettes Réelles Anti-Gaspi

struct AntiWasteRecipe: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var emoji: String
    var category: String
    var prepTimeMinutes: Int
    var cookTimeMinutes: Int
    var servings: Int
    var difficulty: String
    var matchedInventoryItemNames: [String]
    var pantryStaples: [String]
    var steps: [String]
    var chefTip: String
    var isFavorite: Bool = false
}

// MARK: - Moteur Culinaire Intelligent Anti-Gaspi

struct RecipeEngine {
    static func generateRecipes(from items: [FoodItem], maxTimeMinutes: Int? = nil, isVeggieOnly: Bool = false) -> [AntiWasteRecipe] {
        guard !items.isEmpty else { return [] }
        
        // Trier par urgence de péremption d'abord
        let sortedItems = items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
        
        var availableMeat = sortedItems.filter { $0.category == .meat }
        var availableFish = sortedItems.filter { $0.category == .fish }
        var availableVeg = sortedItems.filter { $0.category == .vegetables }
        var availableBakery = sortedItems.filter { $0.category == .bakery }
        var availableDairy = sortedItems.filter { $0.category == .dairy }
        var availableFruits = sortedItems.filter { $0.category == .fruits }
        var availableReady = sortedItems.filter { $0.category == .readyMeals }
        var availableOther = sortedItems.filter { $0.category == .other }
        
        if isVeggieOnly {
            availableMeat = []
            availableFish = []
        }
        
        var results: [AntiWasteRecipe] = []
        
        // 1. Gratin Doré du Congélateur
        if let veg = availableVeg.first {
            let protein = isVeggieOnly ? nil : (availableMeat.first ?? availableFish.first)
            var matched = [veg.name]
            if let prot = protein { matched.append(prot.name) }
            if let dairy = availableDairy.first { matched.append(dairy.name) }
            
            results.append(AntiWasteRecipe(
                title: protein != nil ? "Gratin Doré au \(veg.name) & \(protein!.name)" : "Gratin Fondant de \(veg.name)",
                emoji: "🧀",
                category: "Plat au Four",
                prepTimeMinutes: 15,
                cookTimeMinutes: 25,
                servings: 4,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["Crème fraîche ou lait (20 cl)", "Fromage râpé (100g)", "1 gousse d'ail", "Sel, poivre & muscade", "Huile d'olive"],
                steps: [
                    "Préchauffez votre four à 200°C (thermostat 6-7).",
                    "Plongez \(veg.name) encore congelé dans de l'eau bouillante salée pendant 4 minutes, puis égouttez soigneusement.",
                    protein != nil ? "Coupez \(protein!.name) en dés et faites-les dorer 3 minutes à la poêle avec un filet d'huile d'olive." : "Frottez un plat à gratin avec la gousse d'ail coupée en deux.",
                    "Disposez les ingrédients dans le plat à gratin, nappez avec la crème assaisonnée de muscade, sel et poivre.",
                    "Saupoudrez généreusement de fromage râpé et enfournez 20 à 25 minutes jusqu'à obtenir une belle croûte dorée."
                ],
                chefTip: "Pour un gratin encore plus croustillant, ajoutez quelques miettes de pain rassis ou chapelure sur le dessus."
            ))
        }
        
        // 2. Poêlée Rustique Express Saveurs du Sud
        let mainIngredient = isVeggieOnly ? availableVeg.first : (availableMeat.first ?? availableFish.first ?? availableVeg.first)
        if let main = mainIngredient {
            let companion = availableVeg.first(where: { $0.id != main.id }) ?? availableOther.first
            var matched = [main.name]
            if let comp = companion { matched.append(comp.name) }
            
            results.append(AntiWasteRecipe(
                title: "Poêlée Rustique Express au \(main.name)",
                emoji: "🍳",
                category: "Poêlée Rapide",
                prepTimeMinutes: 10,
                cookTimeMinutes: 15,
                servings: 2,
                difficulty: "Très facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["2 c. à soupe d'huile d'olive", "1 oignon émincé", "Herbes de Provence", "Sel et poivre du moulin", "Un filet de jus de citron ou sauce soja"],
                steps: [
                    "Chauffez l'huile d'olive dans une grande poêle ou un wok à feu vif.",
                    "Faites suer l'oignon émincé jusqu'à ce qu'il devienne translucide.",
                    "Ajoutez directement \(main.name) sans décongélation préalable si les morceaux sont fins, ou décongelés au micro-ondes pendant 2 minutes.",
                    companion != nil ? "Incorporez \(companion!.name) et faites sauter l'ensemble pendant 8 à 10 minutes en remuant régulièrement." : "Faites sauter pendant 8 à 10 minutes en remuant régulièrement.",
                    "Assaisonnez avec les herbes de Provence, le sel, le poivre et terminez avec un filet de jus de citron."
                ],
                chefTip: "La cuisson vive sans couvrir permet d'évaporer l'eau de congélation et de dorer parfaitement les aliments."
            ))
        }
        
        // 3. Wok Gourmand & Riz Sauté Fond-de-Tiroir
        if let protein = isVeggieOnly ? nil : (availableMeat.first ?? availableFish.first) {
            let veg = availableVeg.first
            var matched = [protein.name]
            if let v = veg { matched.append(v.name) }
            
            results.append(AntiWasteRecipe(
                title: "Wok Asiatique Épicé au \(protein.name)",
                emoji: "🥢",
                category: "Wok & Sauté",
                prepTimeMinutes: 12,
                cookTimeMinutes: 12,
                servings: 3,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["Riz cuit ou nouilles (250g)", "3 c. à soupe de sauce soja", "1 c. à café d'huile de sésame", "1 gousse d'ail écrasée", "Gingembre moulu", "1 œuf battu"],
                steps: [
                    "Découpez \(protein.name) en fines lamelles.",
                    "Faites chauffer un filet d'huile dans un wok à feu très vif.",
                    "Faites dorer la viande/poisson pendant 3 minutes avec l'ail et le gingembre.",
                    veg != nil ? "Ajoutez \(veg!.name) et poursuivez la cuisson 4 minutes." : "Baissez le feu.",
                    "Poussez les aliments sur le côté du wok, versez l'œuf battu pour le brouiller rapidement, puis mélangez avec le riz et la sauce soja."
                ],
                chefTip: "Le riz de la veille légèrement sec est parfait pour cette recette anti-gaspi !"
            ))
        }
        
        // 4. Velouté Onctueux Réconfortant
        if availableVeg.count >= 1 {
            let veg1 = availableVeg[0]
            let veg2 = availableVeg.count > 1 ? availableVeg[1] : nil
            var matched = [veg1.name]
            if let v2 = veg2 { matched.append(v2.name) }
            
            results.append(AntiWasteRecipe(
                title: "Velouté Réconfortant de \(veg1.name)" + (veg2 != nil ? " & \(veg2!.name)" : ""),
                emoji: "🥣",
                category: "Soupe & Velouté",
                prepTimeMinutes: 10,
                cookTimeMinutes: 20,
                servings: 4,
                difficulty: "Très facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["1 cube de bouillon de légumes ou volaille", "600 ml d'eau", "2 c. à soupe de crème fraîche ou fromage frais", "1 noisette de beurre", "Sel & poivre"],
                steps: [
                    "Dans une casserole, faites fondre le beurre et faites revenir les légumes \(matched.joined(separator: " et ")) pendant 3 minutes.",
                    "Ajoutez l'eau chaude et émiettez le cube de bouillon.",
                    "Portez à ébullition, couvrez et laissez mijoter à feu moyen pendant 15 minutes.",
                    "Mixez finement à l'aide d'un mixeur plongeant jusqu'à consistance lisse et soyeuse.",
                    "Incorporez la crème fraîche, rectifiez l'assaisonnement et servez bien chaud avec des croûtons."
                ],
                chefTip: "Parfait pour utiliser les fins de sachets de légumes qui trainent au fond du bac !"
            ))
        }
        
        // 5. Quiche / Tarte Rustique du Placard
        if let item = sortedItems.first {
            var matched = [item.name]
            if let second = sortedItems.first(where: { $0.id != item.id }) {
                matched.append(second.name)
            }
            
            results.append(AntiWasteRecipe(
                title: "Tarte Rustique Feuilletée aux Délices de \(item.name)",
                emoji: "🥧",
                category: "Tarte & Quiche",
                prepTimeMinutes: 15,
                cookTimeMinutes: 30,
                servings: 4,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["1 pâte feuilletée ou brisée", "3 œufs entiers", "20 cl de crème liquide", "100g de fromage râpé", "Sel, poivre & muscade"],
                steps: [
                    "Préchauffez votre four à 180°C et déroulez la pâte dans un moule à tarte.",
                    "Faites revenir rapidement les ingrédients \(matched.joined(separator: " et ")) à la poêle pour évacuer l'excès d'humidité.",
                    "Dans un bol, fouettez les œufs avec la crème, le sel, le poivre et une pincée de muscade.",
                    "Disposez les ingrédients sur le fond de tarte et versez l'appareil à quiche par-dessus.",
                    "Parsemez de fromage râpé et enfournez pour 30 minutes jusqu'à ce que la tarte soit bien gonflée et dorée."
                ],
                chefTip: "Piquez le fond de tarte à la fourchette avant de garnir pour une cuisson bien croustillante."
            ))
        }
        
        // 6. Smoothie ou Dessert Fruité Anti-Gaspi
        if let fruits = availableFruits.first {
            results.append(AntiWasteRecipe(
                title: "Smoothie Bowl Vitaminé aux \(fruits.name)",
                emoji: "🍧",
                category: "Dessert & Goûter",
                prepTimeMinutes: 5,
                cookTimeMinutes: 0,
                servings: 2,
                difficulty: "Ultra Rapide",
                matchedInventoryItemNames: [fruits.name],
                pantryStaples: ["1 yaourt nature ou fromage blanc (150g)", "1 banane ou 10 cl de lait", "1 c. à soupe de miel ou sirop d'érable", "Graines de chia ou flocons d'avoine"],
                steps: [
                    "Placez les \(fruits.name) encore congelés directement dans le bol d'un blender.",
                    "Ajoutez le yaourt, la banane et le miel.",
                    "Mixez par pulsations à haute vitesse pendant 45 secondes jusqu'à texture onctueuse et crémeuse.",
                    "Versez dans des bols et décorez avec des graines ou du granola pour le croquant."
                ],
                chefTip: "Les fruits surgelés donnent une texture glacée parfaite sans avoir besoin d'ajouter de glaçons !"
            ))
        }
        
        // Filtrer par temps si demandé
        if let maxT = maxTimeMinutes {
            results = results.filter { ($0.prepTimeMinutes + $0.cookTimeMinutes) <= maxT }
        }
        
        return results
    }
}

// MARK: - Vue Complète du Générateur de Recettes

struct MealGeneratorView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    @State private var recipes: [AntiWasteRecipe] = []
    @State private var selectedRecipe: AntiWasteRecipe? = nil
    @State private var maxTimeFilter: Int = 45
    @State private var isVeggieOnly = false
    @State private var favorites: [AntiWasteRecipe] = []
    @State private var showingFavoritesOnly = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var shareSheetItem: String? = nil
    
    private let favKey = "congelo_saved_favorite_recipes"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !license.currentTier.hasAntiWasteRecipeGenerator {
                    VStack(spacing: 20) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                        }
                        
                        Text("Générateur Culinaire Anti-Gaspi")
                            .font(.title2)
                            .bold()
                        
                        Text("Transformez instantanément vos produits proches de la date limite en délicieux repas équilibrés avec étapes détaillées et déduction automatique du stock.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureBenefitRow(icon: "bolt.fill", title: "Priorité aux dates courtes", description: "Cible d'abord les aliments à consommer en urgence")
                            FeatureBenefitRow(icon: "list.bullet.clipboard.fill", title: "Recettes pas-à-pas", description: "Temps, portions, difficulté et ingrédients du placard")
                            FeatureBenefitRow(icon: "minus.circle.fill", title: "Déstockage en 1 clic", description: "Met à jour automatiquement votre inventaire")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Button {
                            license.upgrade(to: .family)
                        } label: {
                            Text("Passer à la formule Famille (9,99 $)")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                } else if inventory.items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Votre congélateur est vide")
                            .font(.title3)
                            .bold()
                        Text("Ajoutez des articles dans votre inventaire pour générer des recettes sur-mesure.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    // Barre de filtres et d'actions
                    VStack(spacing: 10) {
                        HStack {
                            Picker("Affichage", selection: $showingFavoritesOnly) {
                                Text("Idées Recettes (\(recipes.count))").tag(false)
                                Text("Mes Favoris (\(favorites.count))").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        if !showingFavoritesOnly {
                            HStack(spacing: 12) {
                                Menu {
                                    Button("Tous les temps") { maxTimeFilter = 90; refreshRecipes() }
                                    Button("Moins de 20 min (Express)") { maxTimeFilter = 20; refreshRecipes() }
                                    Button("Moins de 35 min") { maxTimeFilter = 35; refreshRecipes() }
                                    Button("Moins de 50 min") { maxTimeFilter = 50; refreshRecipes() }
                                } label: {
                                    HStack {
                                        Image(systemName: "clock")
                                        Text(maxTimeFilter >= 90 ? "Temps : Tous" : "< \(maxTimeFilter) min")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(8)
                                }
                                
                                Button {
                                    isVeggieOnly.toggle()
                                    refreshRecipes()
                                } label: {
                                    HStack {
                                        Image(systemName: isVeggieOnly ? "leaf.fill" : "leaf")
                                        Text("100% Végétarien")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isVeggieOnly ? Color.green : Color.secondary.opacity(0.12))
                                    .foregroundColor(isVeggieOnly ? .white : .primary)
                                    .cornerRadius(8)
                                }
                                
                                Spacer()
                                
                                Button {
                                    refreshRecipes()
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.cyan.opacity(0.15))
                                        .foregroundColor(.cyan)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 6)
                    
                    // Liste des recettes
                    let displayedList = showingFavoritesOnly ? favorites : recipes
                    
                    if displayedList.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: showingFavoritesOnly ? "heart.slash" : "sparkles")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text(showingFavoritesOnly ? "Aucune recette favorite enregistrée" : "Aucune recette trouvée avec ces critères")
                                .font(.headline)
                            Text(showingFavoritesOnly ? "Appuyez sur le cœur d'une recette pour la retrouver ici facilement." : "Essayez d'augmenter le temps limite ou d'ajouter d'autres types d'aliments.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(displayedList) { recipe in
                                RecipeCardView(
                                    recipe: recipe,
                                    isFav: favorites.contains(where: { $0.title == recipe.title }),
                                    onToggleFav: { toggleFavorite(recipe) },
                                    onCook: { cookRecipe(recipe) },
                                    onShare: { shareRecipe(recipe) }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Recettes Anti-Gaspi")
            .onAppear {
                loadFavorites()
                refreshRecipes()
            }
            .overlay(
                VStack {
                    if showToast {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toastMessage)
                                .font(.subheadline)
                                .bold()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                        .shadow(radius: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                    }
                    Spacer()
                }
                .animation(.easeInOut, value: showToast)
            )
            .sheet(item: Binding(
                get: { shareSheetItem.map { ShareableText(text: $0) } },
                set: { shareSheetItem = $0?.text }
            )) { shareable in
                ActivityViewController(activityItems: [shareable.text])
            }
        }
    }
    
    private func refreshRecipes() {
        recipes = RecipeEngine.generateRecipes(
            from: inventory.items,
            maxTimeMinutes: maxTimeFilter >= 90 ? nil : maxTimeFilter,
            isVeggieOnly: isVeggieOnly
        )
    }
    
    private func cookRecipe(_ recipe: AntiWasteRecipe) {
        var consumedNames: [String] = []
        for name in recipe.matchedInventoryItemNames {
            if let matchedItem = inventory.items.first(where: { $0.name.lowercased() == name.lowercased() || name.lowercased().contains($0.name.lowercased()) }) {
                inventory.consumeItem(withId: matchedItem.id, count: 1)
                consumedNames.append(matchedItem.name)
            }
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        triggerToast("Cuisiné ! Stocks déduits : \(consumedNames.joined(separator: ", "))")
        refreshRecipes()
    }
    
    private func toggleFavorite(_ recipe: AntiWasteRecipe) {
        if let idx = favorites.firstIndex(where: { $0.title == recipe.title }) {
            favorites.remove(at: idx)
            triggerToast("Retiré des favoris")
        } else {
            var fav = recipe
            fav.isFavorite = true
            favorites.append(fav)
            triggerToast("Ajouté aux favoris ❤️")
        }
        saveFavorites()
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: favKey)
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favKey),
           let decoded = try? JSONDecoder().decode([AntiWasteRecipe].self, from: data) {
            favorites = decoded
        }
    }
    
    private func shareRecipe(_ recipe: AntiWasteRecipe) {
        var text = "🍳 Recette Anti-Gaspi Congelo : \(recipe.title)\n"
        text += "⏱️ Préparation : \(recipe.prepTimeMinutes) min • Cuisson : \(recipe.cookTimeMinutes) min • \(recipe.servings) pers.\n\n"
        text += "❄️ Ingrédients du congélateur :\n"
        for item in recipe.matchedInventoryItemNames {
            text += "• \(item)\n"
        }
        text += "\n🧂 Du placard :\n"
        for staple in recipe.pantryStaples {
            text += "• \(staple)\n"
        }
        text += "\n👨‍🍳 Préparation :\n"
        for (i, step) in recipe.steps.enumerated() {
            text += "\(i + 1). \(step)\n"
        }
        text += "\n💡 Astuce du Chef : \(recipe.chefTip)"
        shareSheetItem = text
    }
    
    private func triggerToast(_ msg: String) {
        toastMessage = msg
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }
}

struct ShareableText: Identifiable {
    var id = UUID()
    var text: String
}

struct FeatureBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .bold()
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Carte Visuelle d'une Recette

struct RecipeCardView: View {
    let recipe: AntiWasteRecipe
    let isFav: Bool
    let onToggleFav: () -> Void
    let onCook: () -> Void
    let onShare: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête
            HStack(alignment: .top) {
                Text(recipe.emoji)
                    .font(.system(size: 36))
                    .padding(8)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .bold()
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label("\(recipe.prepTimeMinutes + recipe.cookTimeMinutes) min", systemImage: "clock")
                        Text("•")
                        Label("\(recipe.servings) pers.", systemImage: "person.2")
                        Text("•")
                        Text(recipe.difficulty)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onToggleFav) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .foregroundColor(isFav ? .red : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            
            // Ingrédients utilisés du congélateur
            VStack(alignment: .leading, spacing: 4) {
                Text("Ingrédients utilisés du stock :")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.matchedInventoryItemNames, id: \.self) { item in
                            HStack(spacing: 4) {
                                Image(systemName: "snowflake")
                                    .font(.caption2)
                                Text(item)
                                    .font(.caption2)
                                    .bold()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Vue dépliée : Ingrédients placard + Étapes de préparation
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("🧂 À ajouter depuis le placard :")
                        .font(.caption)
                        .bold()
                    
                    ForEach(recipe.pantryStaples, id: \.self) { staple in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(staple)
                                .font(.caption)
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("👨‍🍳 Étapes de préparation :")
                        .font(.caption)
                        .bold()
                    
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.caption2)
                                .bold()
                                .frame(width: 18, height: 18)
                                .background(Color.cyan)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                            Text(step)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 1)
                    }
                }
                
                // Astuce anti-gaspi
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Astuce : \(recipe.chefTip)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Boutons d'action
            HStack {
                Button {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Moins de détails" : "Voir la recette complète")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .bold()
                    .foregroundColor(.cyan)
                }
                
                Spacer()
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.borderless)
                
                Button(action: onCook) {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                        Text("Cuisiner & Déstocker")
                    }
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
