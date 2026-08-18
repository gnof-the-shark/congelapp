import SwiftUI
import UIKit

// MARK: - Modèle de Données Recette Complète (Anti-Gaspi & TheMealDB)

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
    var thumbnailURL: String? = nil
    var area: String? = nil
    var youtubeURL: String? = nil
    var isOnlineTheMealDB: Bool = false
    var isFavorite: Bool = false
}

// MARK: - TheMealDB API Service (https://www.themealdb.com)

struct TheMealDBMeal: Codable {
    let idMeal: String?
    let strMeal: String?
    let strCategory: String?
    let strArea: String?
    let strInstructions: String?
    let strMealThumb: String?
    let strTags: String?
    let strYoutube: String?
    
    // Ingrédients 1..20
    let strIngredient1: String?
    let strIngredient2: String?
    let strIngredient3: String?
    let strIngredient4: String?
    let strIngredient5: String?
    let strIngredient6: String?
    let strIngredient7: String?
    let strIngredient8: String?
    let strIngredient9: String?
    let strIngredient10: String?
    let strIngredient11: String?
    let strIngredient12: String?
    let strIngredient13: String?
    let strIngredient14: String?
    let strIngredient15: String?
    let strIngredient16: String?
    let strIngredient17: String?
    let strIngredient18: String?
    let strIngredient19: String?
    let strIngredient20: String?
    
    // Mesures 1..20
    let strMeasure1: String?
    let strMeasure2: String?
    let strMeasure3: String?
    let strMeasure4: String?
    let strMeasure5: String?
    let strMeasure6: String?
    let strMeasure7: String?
    let strMeasure8: String?
    let strMeasure9: String?
    let strMeasure10: String?
    let strMeasure11: String?
    let strMeasure12: String?
    let strMeasure13: String?
    let strMeasure14: String?
    let strMeasure15: String?
    let strMeasure16: String?
    let strMeasure17: String?
    let strMeasure18: String?
    let strMeasure19: String?
    let strMeasure20: String?
    
    func allIngredientsWithMeasures() -> [String] {
        let ingredients = [
            strIngredient1, strIngredient2, strIngredient3, strIngredient4, strIngredient5,
            strIngredient6, strIngredient7, strIngredient8, strIngredient9, strIngredient10,
            strIngredient11, strIngredient12, strIngredient13, strIngredient14, strIngredient15,
            strIngredient16, strIngredient17, strIngredient18, strIngredient19, strIngredient20
        ]
        let measures = [
            strMeasure1, strMeasure2, strMeasure3, strMeasure4, strMeasure5,
            strMeasure6, strMeasure7, strMeasure8, strMeasure9, strMeasure10,
            strMeasure11, strMeasure12, strMeasure13, strMeasure14, strMeasure15,
            strMeasure16, strMeasure17, strMeasure18, strMeasure19, strMeasure20
        ]
        
        var result: [String] = []
        for i in 0..<ingredients.count {
            if let ing = ingredients[i]?.trimmingCharacters(in: .whitespacesAndNewlines), !ing.isEmpty {
                let measure = measures[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !measure.isEmpty {
                    result.append("\(ing) (\(measure))")
                } else {
                    result.append(ing)
                }
            }
        }
        return result
    }
}

struct TheMealDBResponse: Codable {
    let meals: [TheMealDBMeal]?
}

struct TheMealDBFilterItem: Codable {
    let strMeal: String
    let strMealThumb: String
    let idMeal: String
}

struct TheMealDBFilterResponse: Codable {
    let meals: [TheMealDBFilterItem]?
}

final class TheMealDBService {
    static let shared = TheMealDBService()
    private let baseURL = "https://www.themealdb.com/api/json/v1/1"
    
    // Traduction de base Français -> Anglais pour optimiser les requêtes TheMealDB
    private let translationDict: [String: String] = [
        "poulet": "chicken",
        "volaille": "chicken",
        "dinde": "turkey",
        "boeuf": "beef",
        "bœuf": "beef",
        "steak": "beef",
        "viande": "meat",
        "porc": "pork",
        "jambon": "ham",
        "bacon": "bacon",
        "saumon": "salmon",
        "poisson": "fish",
        "thon": "tuna",
        "cabillaud": "cod",
        "crevette": "prawns",
        "crevettes": "prawns",
        "fruit de mer": "seafood",
        "fromage": "cheese",
        "mozzarella": "mozzarella",
        "parmesan": "parmesan",
        "lait": "milk",
        "beurre": "butter",
        "tomate": "tomato",
        "tomates": "tomatoes",
        "pomme de terre": "potato",
        "pommes de terre": "potatoes",
        "carotte": "carrot",
        "carottes": "carrots",
        "oignon": "onion",
        "oignons": "onions",
        "ail": "garlic",
        "champignon": "mushroom",
        "champignons": "mushrooms",
        "courgette": "courgette",
        "haricot": "beans",
        "haricots": "beans",
        "riz": "rice",
        "pate": "pasta",
        "pâtes": "pasta",
        "pain": "bread",
        "oeuf": "egg",
        "oeufs": "eggs",
        "œufs": "eggs",
        "pomme": "apple",
        "fraise": "strawberry",
        "framboise": "raspberry",
        "chocolat": "chocolate"
    ]
    
    func translateIngredientToEnglish(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for (fr, en) in translationDict {
            if lower.contains(fr) {
                return en
            }
        }
        return lower
    }
    
    // Rechercher des repas complets par ingrédient ou terme de recherche
    func searchMeals(query: String, matchedStockNames: [String] = []) async -> [AntiWasteRecipe] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let translated = translateIngredientToEnglish(trimmed)
        let queryEncoded = (translated.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? translated)
        
        // 1. Essayer une recherche par nom complet
        if let directResults = await fetchDirectSearch(queryEncoded: queryEncoded, matchedStockNames: matchedStockNames), !directResults.isEmpty {
            return directResults
        }
        
        // 2. Sinon essayer le filtre par ingrédient principal
        if let filteredResults = await fetchFilteredByIngredient(ingredientEncoded: queryEncoded, matchedStockNames: matchedStockNames), !filteredResults.isEmpty {
            return filteredResults
        }
        
        return []
    }
    
    private func fetchDirectSearch(queryEncoded: String, matchedStockNames: [String]) async -> [AntiWasteRecipe]? {
        guard let url = URL(string: "\(baseURL)/search.php?s=\(queryEncoded)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(TheMealDBResponse.self, from: data)
            guard let meals = decoded.meals, !meals.isEmpty else { return nil }
            return meals.compactMap { self.convertToAntiWasteRecipe($0, matchedStockNames: matchedStockNames) }
        } catch {
            return nil
        }
    }
    
    private func fetchFilteredByIngredient(ingredientEncoded: String, matchedStockNames: [String]) async -> [AntiWasteRecipe]? {
        guard let url = URL(string: "\(baseURL)/filter.php?i=\(ingredientEncoded)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(TheMealDBFilterResponse.self, from: data)
            guard let meals = decoded.meals, !meals.isEmpty else { return nil }
            
            // Récupérer les détails des 5 premiers résultats pour avoir les étapes complètes
            var recipes: [AntiWasteRecipe] = []
            for item in meals.prefix(5) {
                if let detail = await fetchMealDetails(id: item.idMeal) {
                    recipes.append(convertToAntiWasteRecipe(detail, matchedStockNames: matchedStockNames))
                }
            }
            return recipes
        } catch {
            return nil
        }
    }
    
    func fetchMealDetails(id: String) async -> TheMealDBMeal? {
        guard let url = URL(string: "\(baseURL)/lookup.php?i=\(id)") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(TheMealDBResponse.self, from: data)
            return decoded.meals?.first
        } catch {
            return nil
        }
    }
    
    // Obtenir une recette aléatoire pour inspiration
    func fetchRandomMeal(matchedStockNames: [String] = []) async -> AntiWasteRecipe? {
        guard let url = URL(string: "\(baseURL)/random.php") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(TheMealDBResponse.self, from: data)
            guard let meal = decoded.meals?.first else { return nil }
            return convertToAntiWasteRecipe(meal, matchedStockNames: matchedStockNames)
        } catch {
            return nil
        }
    }
    
    private func convertToAntiWasteRecipe(_ meal: TheMealDBMeal, matchedStockNames: [String]) -> AntiWasteRecipe {
        let title = meal.strMeal ?? "Recette TheMealDB"
        let category = meal.strCategory ?? "Gourmet"
        let area = meal.strArea
        let allIngredients = meal.allIngredientsWithMeasures()
        
        // Découper les instructions en étapes
        var steps: [String] = []
        if let rawInstructions = meal.strInstructions {
            let lines = rawInstructions.components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if lines.count > 1 {
                steps = lines
            } else if let single = lines.first {
                // Découpage par phrases
                let sentences = single.components(separatedBy: ". ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                steps = sentences.map { $0.hasSuffix(".") ? $0 : "\($0)." }
            }
        }
        
        if steps.isEmpty {
            steps = ["Suivez les instructions fournies dans la fiche TheMealDB pour préparer ce délicieux plat."]
        }
        
        // Identifier les ingrédients qui matchent avec le stock
        var matched = matchedStockNames.filter { stockName in
            allIngredients.contains { ing in
                ing.localizedCaseInsensitiveContains(stockName) || stockName.localizedCaseInsensitiveContains(ing)
            }
        }
        if matched.isEmpty && !matchedStockNames.isEmpty {
            matched = [matchedStockNames.first!]
        }
        
        let emoji = categoryEmoji(for: category)
        
        return AntiWasteRecipe(
            title: title,
            emoji: emoji,
            category: category,
            prepTimeMinutes: 15,
            cookTimeMinutes: 25,
            servings: 4,
            difficulty: "Standard",
            matchedInventoryItemNames: matched,
            pantryStaples: allIngredients,
            steps: steps,
            chefTip: "Recette issue de la base TheMealDB. N'hésitez pas à ajuster les assaisonnements selon vos goûts !",
            thumbnailURL: meal.strMealThumb,
            area: area,
            youtubeURL: meal.strYoutube,
            isOnlineTheMealDB: true,
            isFavorite: false
        )
    }
    
    private func categoryEmoji(for category: String) -> String {
        switch category.lowercased() {
        case "beef": return "🥩"
        case "chicken": return "🍗"
        case "dessert": return "🍰"
        case "lamb": return "🍖"
        case "pasta": return "🍝"
        case "pork": return "🥓"
        case "seafood": return "🐟"
        case "side": return "🥗"
        case "starter": return "🥟"
        case "vegan", "vegetarian": return "🥦"
        case "breakfast": return "🍳"
        case "goat": return "🍲"
        default: return "🍽️"
        }
    }
}

// MARK: - Moteur Culinaire Intelligent Local Anti-Gaspi

struct RecipeEngine {
    static func generateRecipes(from items: [FoodItem], maxTimeMinutes: Int? = nil, isVeggieOnly: Bool = false) -> [AntiWasteRecipe] {
        guard !items.isEmpty else { return [] }
        
        let sortedItems = items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
        
        var availableMeat = sortedItems.filter { $0.category == .meat }
        var availableFish = sortedItems.filter { $0.category == .fish }
        var availableVeg = sortedItems.filter { $0.category == .vegetables }
        var availableDairy = sortedItems.filter { $0.category == .dairy }
        var availableFruits = sortedItems.filter { $0.category == .fruits }
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
                chefTip: "Parfait pour utiliser les fins de sachets de légumes qui traînent au fond du bac !"
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
        
        if let maxT = maxTimeMinutes {
            results = results.filter { ($0.prepTimeMinutes + $0.cookTimeMinutes) <= maxT }
        }
        
        return results
    }
}

// MARK: - Vue Complète du Générateur de Recettes (Anti-Gaspi & TheMealDB)

struct MealGeneratorView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    enum RecipeTabSection: Int {
        case antiWaste = 0
        case theMealDB = 1
        case favorites = 2
    }
    
    @State private var currentTabSection: RecipeTabSection = .antiWaste
    @State private var localRecipes: [AntiWasteRecipe] = []
    @State private var onlineMealDBRecipes: [AntiWasteRecipe] = []
    @State private var favorites: [AntiWasteRecipe] = []
    
    @State private var maxTimeFilter: Int = 45
    @State private var isVeggieOnly = false
    @State private var onlineSearchQuery = ""
    @State private var isFetchingOnline = false
    
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
                        
                        Text("Générateur Culinaire Anti-Gaspi & TheMealDB")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Transformez instantanément vos produits proches de la date limite en délicieux repas équilibrés avec étapes détaillées, inspirations mondiales TheMealDB et déduction automatique du stock.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureBenefitRow(icon: "bolt.fill", title: "Priorité aux dates courtes", description: "Cible d'abord les aliments à consommer en urgence")
                            FeatureBenefitRow(icon: "globe.europe.africa.fill", title: "Inspirations TheMealDB", description: "Accès à des milliers de recettes du monde avec photos")
                            FeatureBenefitRow(icon: "list.bullet.clipboard.fill", title: "Recettes pas-à-pas", description: "Ingrédients complets, mesures et étapes guidées")
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
                } else {
                    // Sélecteur d'onglets de recettes
                    VStack(spacing: 8) {
                        Picker("Section", selection: $currentTabSection) {
                            Text("Anti-Gaspi (\(localRecipes.count))").tag(RecipeTabSection.antiWaste)
                            Text("TheMealDB 🌐").tag(RecipeTabSection.theMealDB)
                            Text("Favoris (\(favorites.count))").tag(RecipeTabSection.favorites)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Contrôles spécifiques à chaque sous-onglet
                        if currentTabSection == .antiWaste {
                            HStack(spacing: 12) {
                                Menu {
                                    Button("Tous les temps") { maxTimeFilter = 90; refreshLocalRecipes() }
                                    Button("Moins de 20 min (Express)") { maxTimeFilter = 20; refreshLocalRecipes() }
                                    Button("Moins de 35 min") { maxTimeFilter = 35; refreshLocalRecipes() }
                                    Button("Moins de 50 min") { maxTimeFilter = 50; refreshLocalRecipes() }
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
                                    refreshLocalRecipes()
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
                                    refreshLocalRecipes()
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
                        } else if currentTabSection == .theMealDB {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.secondary)
                                        TextField("Ingrédient ou plat (ex: Poulet, Salmon, Pasta)...", text: $onlineSearchQuery)
                                            .onSubmit {
                                                Task { await searchTheMealDB() }
                                            }
                                        if !onlineSearchQuery.isEmpty {
                                            Button {
                                                onlineSearchQuery = ""
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    
                                    Button {
                                        Task { await searchTheMealDB() }
                                    } label: {
                                        Text("Chercher")
                                            .font(.caption)
                                            .bold()
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.cyan)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .disabled(isFetchingOnline)
                                }
                                
                                HStack(spacing: 8) {
                                    Button {
                                        Task { await fetchAutoTheMealDBFromStock() }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                            Text("Suggérer selon mon stock")
                                        }
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(6)
                                    }
                                    
                                    Button {
                                        Task { await fetchRandomTheMealDB() }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "dice.fill")
                                            Text("Surprise TheMealDB")
                                        }
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.purple.opacity(0.15))
                                        .foregroundColor(.purple)
                                        .cornerRadius(6)
                                    }
                                    
                                    Spacer()
                                    
                                    if isFetchingOnline {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 6)
                    
                    // Liste de contenu selon l'onglet
                    Group {
                        switch currentTabSection {
                        case .antiWaste:
                            if localRecipes.isEmpty {
                                emptyStateView(
                                    icon: "sparkles",
                                    title: "Aucune recette locale trouvée",
                                    message: inventory.items.isEmpty ? "Ajoutez des aliments à votre inventaire pour générer des recettes." : "Modifiez les filtres de temps pour voir plus d'idées."
                                )
                            } else {
                                recipeListView(recipes: localRecipes)
                            }
                            
                        case .theMealDB:
                            if isFetchingOnline && onlineMealDBRecipes.isEmpty {
                                VStack(spacing: 16) {
                                    Spacer()
                                    ProgressView("Chargement depuis TheMealDB...")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            } else if onlineMealDBRecipes.isEmpty {
                                emptyStateView(
                                    icon: "globe.europe.africa",
                                    title: "Recettes TheMealDB",
                                    message: "Recherchez un ingrédient ou appuyez sur 'Suggérer selon mon stock' pour charger des recettes mondiales en ligne."
                                )
                            } else {
                                recipeListView(recipes: onlineMealDBRecipes)
                            }
                            
                        case .favorites:
                            if favorites.isEmpty {
                                emptyStateView(
                                    icon: "heart.slash",
                                    title: "Aucun favori enregistré",
                                    message: "Appuyez sur le cœur d'une recette pour l'ajouter à vos favoris."
                                )
                            } else {
                                recipeListView(recipes: favorites)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recettes & TheMealDB")
            .onAppear {
                loadFavorites()
                refreshLocalRecipes()
                if onlineMealDBRecipes.isEmpty && !inventory.items.isEmpty {
                    Task { await fetchAutoTheMealDBFromStock() }
                }
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
    
    // MARK: - Vues Réutilisables
    
    @ViewBuilder
    private func recipeListView(recipes: [AntiWasteRecipe]) -> some View {
        List {
            ForEach(recipes) { recipe in
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
    
    @ViewBuilder
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    // MARK: - Logique Métier
    
    private func refreshLocalRecipes() {
        localRecipes = RecipeEngine.generateRecipes(
            from: inventory.items,
            maxTimeMinutes: maxTimeFilter >= 90 ? nil : maxTimeFilter,
            isVeggieOnly: isVeggieOnly
        )
    }
    
    private func searchTheMealDB() async {
        guard !onlineSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isFetchingOnline = true
        let stockNames = inventory.items.map { $0.name }
        let results = await TheMealDBService.shared.searchMeals(query: onlineSearchQuery, matchedStockNames: stockNames)
        DispatchQueue.main.async {
            self.onlineMealDBRecipes = results
            self.isFetchingOnline = false
            if results.isEmpty {
                self.triggerToast("Aucune recette TheMealDB trouvée pour '\(self.onlineSearchQuery)'")
            }
        }
    }
    
    private func fetchAutoTheMealDBFromStock() async {
        guard !inventory.items.isEmpty else { return }
        isFetchingOnline = true
        let urgentItem = inventory.items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }.first?.name ?? "Chicken"
        let stockNames = inventory.items.map { $0.name }
        let results = await TheMealDBService.shared.searchMeals(query: urgentItem, matchedStockNames: stockNames)
        DispatchQueue.main.async {
            if !results.isEmpty {
                self.onlineMealDBRecipes = results
            }
            self.isFetchingOnline = false
        }
    }
    
    private func fetchRandomTheMealDB() async {
        isFetchingOnline = true
        let stockNames = inventory.items.map { $0.name }
        if let randomRecipe = await TheMealDBService.shared.fetchRandomMeal(matchedStockNames: stockNames) {
            DispatchQueue.main.async {
                self.onlineMealDBRecipes = [randomRecipe] + self.onlineMealDBRecipes.filter { $0.title != randomRecipe.title }
                self.isFetchingOnline = false
                self.triggerToast("Nouvelle recette TheMealDB découverte 🎲")
            }
        } else {
            DispatchQueue.main.async {
                self.isFetchingOnline = false
            }
        }
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
        if consumedNames.isEmpty {
            triggerToast("Cuisiné ! Bon appétit 🍽️")
        } else {
            triggerToast("Cuisiné ! Stocks déduits : \(consumedNames.joined(separator: ", "))")
        }
        refreshLocalRecipes()
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
        var text = "🍳 Recette Congelo : \(recipe.title)\n"
        if let area = recipe.area {
            text += "🌍 Origine : \(area)\n"
        }
        text += "⏱️ Préparation : \(recipe.prepTimeMinutes) min • Cuisson : \(recipe.cookTimeMinutes) min • \(recipe.servings) pers.\n\n"
        
        if !recipe.matchedInventoryItemNames.isEmpty {
            text += "❄️ Ingrédients du congélateur :\n"
            for item in recipe.matchedInventoryItemNames {
                text += "• \(item)\n"
            }
            text += "\n"
        }
        
        text += "🧂 Ingrédients complets :\n"
        for staple in recipe.pantryStaples {
            text += "• \(staple)\n"
        }
        
        text += "\n👨‍🍳 Préparation :\n"
        for (i, step) in recipe.steps.enumerated() {
            text += "\(i + 1). \(step)\n"
        }
        
        if let yt = recipe.youtubeURL, !yt.isEmpty {
            text += "\n📺 Vidéo : \(yt)\n"
        }
        
        text += "\n💡 Astuce : \(recipe.chefTip)"
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
            HStack(alignment: .top, spacing: 12) {
                if let thumb = recipe.thumbnailURL, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Text(recipe.emoji)
                                .font(.system(size: 32))
                                .frame(width: 60, height: 60)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            ProgressView()
                                .frame(width: 60, height: 60)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text(recipe.emoji)
                        .font(.system(size: 32))
                        .frame(width: 60, height: 60)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recipe.title)
                            .font(.headline)
                            .bold()
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if recipe.isOnlineTheMealDB {
                            Text("TheMealDB")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        if let area = recipe.area, !area.isEmpty {
                            Text(area)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.orange)
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Label("\(recipe.prepTimeMinutes + recipe.cookTimeMinutes) min", systemImage: "clock")
                        Text("•")
                        Label("\(recipe.servings) pers.", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Button(action: onToggleFav) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .foregroundColor(isFav ? .red : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            
            // Ingrédients utilisés du congélateur
            if !recipe.matchedInventoryItemNames.isEmpty {
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
            }
            
            // Vue dépliée : Ingrédients complets + Étapes de préparation
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("🧂 Ingrédients & Assaisonnements :")
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
                
                // Astuce anti-gaspi ou lien vidéo
                if let yt = recipe.youtubeURL, let ytURL = URL(string: yt) {
                    Link(destination: ytURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .foregroundColor(.red)
                            Text("Voir le tutoriel vidéo sur YouTube")
                                .font(.caption)
                                .bold()
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
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
