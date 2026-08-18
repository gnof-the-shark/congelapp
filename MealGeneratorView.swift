import SwiftUI
import UIKit

// MARK: - Modèle de Données Recette Anti-Gaspi Complète

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
    var isFavorite: Bool = false
    var itemsToBuyCount: Int = 0
    var missingIngredients: [String] = []
}

// MARK: - Modèles Décodables de l'API

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
    
    func allRawIngredientsWithMeasures() -> [(ingredient: String, measure: String)] {
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
        
        var result: [(ingredient: String, measure: String)] = []
        for i in 0..<ingredients.count {
            if let ing = ingredients[i]?.trimmingCharacters(in: .whitespacesAndNewlines), !ing.isEmpty {
                let measure = measures[i]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                result.append((ingredient: ing, measure: measure))
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

// MARK: - Moteur de Traduction Culinaire Français <-> Anglais

final class FrenchCulinaryTranslator {
    static let shared = FrenchCulinaryTranslator()
    
    // Traduction Français -> Anglais pour les requêtes de recherche
    private let frenchToEnglishTerms: [(fr: String, en: String)] = [
        ("poulet", "chicken"),
        ("volaille", "chicken"),
        ("dinde", "turkey"),
        ("canard", "duck"),
        ("boeuf", "beef"),
        ("bœuf", "beef"),
        ("steak", "beef"),
        ("viande hachee", "beef"),
        ("viande hachée", "beef"),
        ("viande", "meat"),
        ("porc", "pork"),
        ("jambon", "ham"),
        ("lardons", "bacon"),
        ("bacon", "bacon"),
        ("saumon", "salmon"),
        ("poisson", "fish"),
        ("cabillaud", "cod"),
        ("morue", "cod"),
        ("thon", "tuna"),
        ("crevette", "prawns"),
        ("crevettes", "prawns"),
        ("gambas", "prawns"),
        ("moule", "mussels"),
        ("moules", "mussels"),
        ("fruits de mer", "seafood"),
        ("fruit de mer", "seafood"),
        ("fromage", "cheese"),
        ("mozzarella", "mozzarella"),
        ("parmesan", "parmesan"),
        ("cheddar", "cheddar"),
        ("gruyere", "cheese"),
        ("gruyère", "cheese"),
        ("beurre", "butter"),
        ("creme", "cream"),
        ("crème", "cream"),
        ("lait", "milk"),
        ("tomate", "tomato"),
        ("tomates", "tomatoes"),
        ("pomme de terre", "potato"),
        ("pommes de terre", "potatoes"),
        ("patate", "potato"),
        ("patates", "potatoes"),
        ("carotte", "carrot"),
        ("carottes", "carrots"),
        ("oignon", "onion"),
        ("oignons", "onions"),
        ("ail", "garlic"),
        ("champignon", "mushroom"),
        ("champignons", "mushrooms"),
        ("courgette", "courgettes"),
        ("courgettes", "courgettes"),
        ("aubergine", "aubergine"),
        ("aubergines", "aubergine"),
        ("haricot", "beans"),
        ("haricots", "beans"),
        ("haricots verts", "green beans"),
        ("petits pois", "peas"),
        ("pois", "peas"),
        ("poivron", "pepper"),
        ("poivrons", "pepper"),
        ("brocoli", "broccoli"),
        ("brocolis", "broccoli"),
        ("epinard", "spinach"),
        ("epinards", "spinach"),
        ("épinard", "spinach"),
        ("épinards", "spinach"),
        ("chou", "cabbage"),
        ("riz", "rice"),
        ("pate", "pasta"),
        ("pates", "pasta"),
        ("pâte", "pasta"),
        ("pâtes", "pasta"),
        ("spaghetti", "spaghetti"),
        ("nouille", "noodles"),
        ("nouilles", "noodles"),
        ("pain", "bread"),
        ("oeuf", "egg"),
        ("oeufs", "eggs"),
        ("œuf", "egg"),
        ("œufs", "eggs"),
        ("pomme", "apple"),
        ("pommes", "apple"),
        ("poire", "pear"),
        ("poires", "pear"),
        ("fraise", "strawberry"),
        ("fraises", "strawberry"),
        ("framboise", "raspberry"),
        ("framboises", "raspberry"),
        ("chocolat", "chocolate"),
        ("citron", "lemon"),
        ("yogourt", "yogurt"),
        ("yogurt", "yogurt"),
        ("yaourt", "yogurt"),
        ("skyr", "yogurt"),
        ("fromage blanc", "yogurt"),
        ("glace", "ice cream"),
        ("creme glacee", "ice cream"),
        ("crème glacée", "ice cream"),
        ("sorbet", "ice cream")
    ]
    
    // Dictionnaire de traduction Anglais -> Français des ingrédients
    private let englishToFrenchIngredients: [String: String] = [
        "yogurt": "Yaourt / Yogourt",
        "greek yogurt": "Yaourt grec",
        "ice cream": "Glace / Crème glacée",
        "vanilla ice cream": "Glace à la vanille",
        "chicken": "Poulet",
        "chicken breast": "Blanc de poulet",
        "chicken breasts": "Blancs de poulet",
        "chicken thighs": "Cuisses de poulet",
        "beef": "Bœuf",
        "ground beef": "Bœuf haché",
        "minced beef": "Bœuf haché",
        "beef steak": "Steak de bœuf",
        "pork": "Porc",
        "pork chops": "Côtes de porc",
        "bacon": "Bacon / Lardons",
        "ham": "Jambon",
        "salmon": "Saumon",
        "fish": "Poisson",
        "cod": "Cabillaud",
        "tuna": "Thon",
        "prawns": "Crevettes",
        "shrimp": "Crevettes",
        "mussels": "Moules",
        "cheese": "Fromage",
        "cheddar cheese": "Cheddar",
        "mozzarella": "Mozzarella",
        "parmesan": "Parmesan",
        "parmesan cheese": "Parmesan",
        "butter": "Beurre",
        "milk": "Lait",
        "heavy cream": "Crème liquide",
        "cream": "Crème",
        "eggs": "Œufs",
        "egg": "Œuf",
        "egg yolk": "Jaune d'œuf",
        "egg whites": "Blancs d'œufs",
        "garlic": "Ail",
        "garlic clove": "Gousse d'ail",
        "garlic cloves": "Gousses d'ail",
        "onion": "Oignon",
        "onions": "Oignons",
        "red onion": "Oignon rouge",
        "shallots": "Échalotes",
        "tomato": "Tomate",
        "tomatoes": "Tomates",
        "tomato puree": "Purée de tomates",
        "tomato paste": "Concentré de tomates",
        "chopped tomatoes": "Tomates concassées",
        "potato": "Pomme de terre",
        "potatoes": "Pommes de terre",
        "carrots": "Carottes",
        "carrot": "Carotte",
        "mushrooms": "Champignons",
        "mushroom": "Champignon",
        "broccoli": "Brocolis",
        "spinach": "Épinards",
        "green beans": "Haricots verts",
        "peas": "Petits pois",
        "peppers": "Poivrons",
        "red pepper": "Poivron rouge",
        "green pepper": "Poivron vert",
        "courgettes": "Courgettes",
        "zucchini": "Courgettes",
        "aubergine": "Aubergine",
        "eggplant": "Aubergine",
        "rice": "Riz",
        "basmati rice": "Riz basmati",
        "pasta": "Pâtes",
        "spaghetti": "Spaghetti",
        "penne": "Penne",
        "noodles": "Nouilles",
        "bread": "Pain",
        "flour": "Farine",
        "plain flour": "Farine",
        "sugar": "Sucre",
        "brown sugar": "Sucre roux",
        "salt": "Sel",
        "black pepper": "Poivre noir",
        "pepper": "Poivre",
        "olive oil": "Huile d'olive",
        "vegetable oil": "Huile végétale",
        "sunflower oil": "Huile de tournesol",
        "sesame oil": "Huile de sésame",
        "soy sauce": "Sauce soja",
        "worcestershire sauce": "Sauce Worcestershire",
        "vinegar": "Vinaigre",
        "balsamic vinegar": "Vinaigre balsamique",
        "lemon": "Citron",
        "lemon juice": "Jus de citron",
        "lime": "Citron vert",
        "parsley": "Persil",
        "coriander": "Coriandre",
        "basil": "Basilic",
        "thyme": "Thym",
        "rosemary": "Romarin",
        "oregano": "Origan",
        "paprika": "Paprika",
        "cumin": "Cumin",
        "ginger": "Gingembre",
        "chilli": "Piment",
        "chili powder": "Piment en poudre",
        "chicken stock": "Bouillon de volaille",
        "beef stock": "Bouillon de bœuf",
        "vegetable stock": "Bouillon de légumes",
        "water": "Eau",
        "honey": "Miel",
        "mustard": "Moutarde",
        "dijon mustard": "Moutarde de Dijon",
        "mayonnaise": "Mayonnaise",
        "strawberries": "Fraises",
        "apples": "Pommes",
        "chocolate": "Chocolat"
    ]
    
    // Traduction des catégories en français
    private let categoriesMap: [String: String] = [
        "beef": "Bœuf",
        "chicken": "Volaille & Poulet",
        "dessert": "Dessert",
        "lamb": "Agneau",
        "miscellaneous": "Plat Maison",
        "pasta": "Pâtes & Risotto",
        "pork": "Porc",
        "seafood": "Poissons & Fruits de mer",
        "side": "Accompagnement",
        "starter": "Entrée",
        "vegan": "100% Végétalien",
        "vegetarian": "Végétarien",
        "breakfast": "Petit-Déjeuner",
        "goat": "Plat Mijoté"
    ]
    
    // Traduction des origines culinaires
    private let areasMap: [String: String] = [
        "american": "Américaine",
        "british": "Britannique",
        "canadian": "Canadienne",
        "chinese": "Chinoise",
        "croatian": "Croate",
        "dutch": "Hollandaise",
        "egyptian": "Égyptienne",
        "filipino": "Philippine",
        "french": "Française",
        "greek": "Grecque",
        "indian": "Indienne",
        "irish": "Irlandaise",
        "italian": "Italienne",
        "jamaican": "Jamaïcaine",
        "japanese": "Japonaise",
        "kenyan": "Kényane",
        "malaysian": "Malaise",
        "mexican": "Mexicaine",
        "moroccan": "Marocaine",
        "polish": "Polonaise",
        "portuguese": "Portugaise",
        "russian": "Russe",
        "spanish": "Espagnole",
        "thai": "Thaïlandaise",
        "tunisian": "Tunisienne",
        "turkish": "Turque",
        "vietnamese": "Vietnamienne"
    ]
    
    func translateSearchTermToEnglish(_ frenchQuery: String) -> String {
        let clean = frenchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for pair in frenchToEnglishTerms {
            if clean.contains(pair.fr) {
                return pair.en
            }
        }
        return clean
    }
    
    func translateCategory(_ category: String?) -> String {
        guard let cat = category?.lowercased() else { return "Plat Chaud" }
        return categoriesMap[cat] ?? category?.capitalized ?? "Plat Chaud"
    }
    
    func translateArea(_ area: String?) -> String? {
        guard let a = area?.lowercased() else { return nil }
        return areasMap[a] ?? area?.capitalized
    }
    
    func translateTitle(_ title: String) -> String {
        var translated = title
        
        let replacements: [(en: String, fr: String)] = [
            ("Chicken Handi", "Poulet Handi à l'indienne"),
            ("Chicken Alfredo", "Pâtes au Poulet & Crème Alfredo"),
            ("Chicken Curry", "Curry de Poulet Savoureux"),
            ("Chicken Fajitas", "Fajitas au Poulet Grillé"),
            ("Chicken Quesadilla", "Quesadilla Gourmande au Poulet"),
            ("Chicken Soup", "Soupe Réconfortante au Poulet"),
            ("Chicken Wings", "Ailes de Poulet Dorées"),
            ("Beef Stroganoff", "Bœuf Stroganoff Fondant"),
            ("Beef Bourguignon", "Bœuf Bourguignon Traditionnel"),
            ("Beef Stew", "Ragoût de Bœuf Rustique"),
            ("Beef Wellington", "Bœuf Wellington en Croûte"),
            ("Beef and Mustard Pie", "Tourte au Bœuf & Moutarde"),
            ("Salmon Pesto", "Pavé de Saumon au Pesto"),
            ("Grilled Salmon", "Saumon Grillé aux Herbes"),
            ("Fish and Chips", "Fish & Chips Traditionnel"),
            ("Spaghetti Bolognese", "Spaghetti à la Bolognaise"),
            ("Spaghetti Carbonara", "Spaghetti Carbonara"),
            ("Lasagne", "Lasagnes Maison au Four"),
            ("Vegetable Soup", "Velouté de Légumes du Jardin"),
            ("Vegetable Curry", "Curry Doux de Légumes"),
            ("Mushroom Risotto", "Risotto Crémeux aux Champignons"),
            ("French Onion Soup", "Soupe à l'Oignon Gratinée"),
            ("Apple Pie", "Tarte aux Pommes Dorée"),
            ("Chocolate Cake", "Gâteau Moelleux au Chocolat"),
            ("Pancakes", "Pancakes Moelleux Maison"),
            ("Chicken", "Poulet"),
            ("Beef", "Bœuf"),
            ("Salmon", "Saumon"),
            ("Fish", "Poisson"),
            ("Pork", "Porc"),
            ("Soup", "Soupe"),
            ("Stew", "Ragoût"),
            ("Pie", "Tourte"),
            ("Salad", "Salade"),
            ("Fried", "Poêlée de"),
            ("Grilled", "Grillade de"),
            ("Roasted", "Rôti de"),
            ("Baked", "Gratin de"),
            ("with", "au"),
            ("and", "et")
        ]
        
        for rep in replacements {
            if translated.contains(rep.en) {
                translated = translated.replacingOccurrences(of: rep.en, with: rep.fr)
            }
        }
        
        return translated
    }
    
    func translateIngredientItem(rawIngredient: String, rawMeasure: String) -> String {
        let cleanIng = rawIngredient.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let frIng = englishToFrenchIngredients[cleanIng] ?? rawIngredient.capitalized
        
        var frMeasure = rawMeasure.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let measureReplacements: [(en: String, fr: String)] = [
            ("tablespoons", "c. à soupe"),
            ("tablespoon", "c. à soupe"),
            ("tbsp", "c. à soupe"),
            ("tbsps", "c. à soupe"),
            ("teaspoons", "c. à café"),
            ("teaspoon", "c. à café"),
            ("tsp", "c. à café"),
            ("tsps", "c. à café"),
            ("cups", "tasses"),
            ("cup", "tasse"),
            ("ounces", "oz"),
            ("ounce", "oz"),
            ("pounds", "lb"),
            ("pound", "lb"),
            ("pinch", "pincée"),
            ("cloves", "gousses"),
            ("clove", "gousse"),
            ("slices", "tranches"),
            ("slice", "tranche"),
            ("diced", "coupé en dés"),
            ("chopped", "émincé"),
            ("minced", "haché"),
            ("grated", "râpé"),
            ("to taste", "selon votre goût")
        ]
        
        for m in measureReplacements {
            frMeasure = frMeasure.replacingOccurrences(of: m.en, with: m.fr, options: .caseInsensitive)
        }
        
        if frMeasure.isEmpty {
            return frIng
        } else {
            return "\(frIng) (\(frMeasure))"
        }
    }
    
    func translateInstructions(_ rawInstructions: String) -> [String] {
        let lines = rawInstructions.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("STEP") && !$0.hasPrefix("Step") }
        
        var sentences: [String] = []
        if lines.count > 1 {
            sentences = lines
        } else if let single = lines.first {
            let parts = single.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            sentences = parts
        }
        
        if sentences.isEmpty {
            return ["Préparez les ingrédients selon la liste ci-dessus.", "Faites cuire à feu moyen jusqu'à obtention d'une belle texture dorée.", "Servez bien chaud et dégustez !"]
        }
        
        // Traduction des phrases culinaires courantes
        let instructionReplacements: [(en: String, fr: String)] = [
            ("Preheat oven to", "Préchauffez votre four à"),
            ("Preheat the oven to", "Préchauffez votre four à"),
            ("Heat the oil in a large", "Faites chauffer l'huile dans un(e) grand(e)"),
            ("Heat oil in a large", "Faites chauffer l'huile dans un(e) grand(e)"),
            ("Heat the oil in a pan", "Faites chauffer un filet d'huile dans une poêle"),
            ("Heat oil in a pan", "Faites chauffer un filet d'huile dans une poêle"),
            ("In a large bowl", "Dans un grand saladier"),
            ("In a medium bowl", "Dans un bol moyen"),
            ("In a small bowl", "Dans un petit bol"),
            ("In a large pot", "Dans une grande casserole"),
            ("In a large saucepan", "Dans une grande sauteuse"),
            ("Mix together", "Mélangez soigneusement ensemble"),
            ("Stir in the", "Incorporez"),
            ("Stir in", "Incorporez"),
            ("Season with salt and pepper", "Assaisonnez avec du sel et du poivre"),
            ("Season with salt & pepper", "Assaisonnez avec du sel et du poivre"),
            ("Cook until golden brown", "Faites cuire jusqu'à ce que ce soit bien doré"),
            ("Cook for", "Laissez cuire pendant"),
            ("Bake for", "Enfournez pendant"),
            ("Bring to a boil", "Portez à ébullition"),
            ("Reduce heat and simmer", "Baissez le feu et laissez mijoter"),
            ("Serve hot", "Servez immédiatement bien chaud"),
            ("Serve with", "Servez accompagné de"),
            ("Garnish with", "Garnissez avec"),
            ("Let cool", "Laissez tiédir"),
            ("Drain and rinse", "Égouttez soigneusement"),
            ("Chop the", "Émincez finement"),
            ("Dice the", "Coupez en dés"),
            ("Melt the butter", "Faites fondre le beurre"),
            ("Whisk together", "Fouettez ensemble"),
            ("Add the", "Ajoutez"),
            ("Add", "Ajoutez")
        ]
        
        var translatedSteps: [String] = []
        for s in sentences {
            var step = s
            for rep in instructionReplacements {
                step = step.replacingOccurrences(of: rep.en, with: rep.fr, options: .caseInsensitive)
            }
            if !step.hasSuffix(".") {
                step += "."
            }
            translatedSteps.append(step)
        }
        
        return translatedSteps
    }
}

// MARK: - TheMealDB API Service (https://www.themealdb.com)

final class TheMealDBService {
    static let shared = TheMealDBService()
    private let baseURL = "https://www.themealdb.com/api/json/v1/1"
    
    func searchMeals(query: String, matchedStockNames: [String] = []) async -> [AntiWasteRecipe] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let translatedToEnglish = FrenchCulinaryTranslator.shared.translateSearchTermToEnglish(trimmed)
        let queryEncoded = (translatedToEnglish.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? translatedToEnglish)
        
        var results: [AntiWasteRecipe] = []
        
        // 1. Recherche par mot-clé
        if let directResults = await fetchDirectSearch(queryEncoded: queryEncoded, matchedStockNames: matchedStockNames), !directResults.isEmpty {
            results.append(contentsOf: directResults)
        }
        
        // 2. Recherche par filtre ingrédient
        if let filteredResults = await fetchFilteredByIngredient(ingredientEncoded: queryEncoded, matchedStockNames: matchedStockNames), !filteredResults.isEmpty {
            for r in filteredResults {
                if !results.contains(where: { $0.title == r.title }) {
                    results.append(r)
                }
            }
        }
        
        // Tri prioritaire : Recettes demandant le MOINS d'ingrédients supplémentaires à acheter
        results.sort {
            if $0.itemsToBuyCount != $1.itemsToBuyCount {
                return $0.itemsToBuyCount < $1.itemsToBuyCount
            }
            return $0.matchedInventoryItemNames.count > $1.matchedInventoryItemNames.count
        }
        
        return results
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
            
            var recipes: [AntiWasteRecipe] = []
            for item in meals.prefix(8) {
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
        let rawTitle = meal.strMeal ?? "Recette Gourmande Anti-Gaspi"
        let frenchTitle = FrenchCulinaryTranslator.shared.translateTitle(rawTitle)
        let frenchCategory = FrenchCulinaryTranslator.shared.translateCategory(meal.strCategory)
        let frenchArea = FrenchCulinaryTranslator.shared.translateArea(meal.strArea)
        
        let rawIngredients = meal.allRawIngredientsWithMeasures()
        let translatedIngredients = rawIngredients.map {
            FrenchCulinaryTranslator.shared.translateIngredientItem(rawIngredient: $0.ingredient, rawMeasure: $0.measure)
        }
        
        let steps = FrenchCulinaryTranslator.shared.translateInstructions(meal.strInstructions ?? "")
        
        // Trouver les ingrédients du congélateur utilisés dans cette recette
        var matched: [String] = []
        var missing: [String] = []
        
        for raw in rawIngredients {
            let ingLower = raw.ingredient.lowercased()
            let translatedItem = FrenchCulinaryTranslator.shared.translateIngredientItem(rawIngredient: raw.ingredient, rawMeasure: raw.measure)
            
            var isFreezerMatch = false
            for stock in matchedStockNames {
                let stockLower = stock.lowercased()
                let stockEn = FrenchCulinaryTranslator.shared.translateSearchTermToEnglish(stockLower)
                
                if ingLower.contains(stockLower) || stockLower.contains(ingLower) ||
                   ingLower.contains(stockEn) || stockEn.contains(ingLower) {
                    isFreezerMatch = true
                    if !matched.contains(stock) {
                        matched.append(stock)
                    }
                    break
                }
            }
            
            if !isFreezerMatch {
                missing.append(translatedItem)
            }
        }
        
        if matched.isEmpty && !matchedStockNames.isEmpty {
            matched = [matchedStockNames.first!]
        }
        
        let emoji = categoryEmoji(for: meal.strCategory ?? "")
        
        return AntiWasteRecipe(
            title: frenchTitle,
            emoji: emoji,
            category: frenchCategory,
            prepTimeMinutes: 15,
            cookTimeMinutes: 25,
            servings: 4,
            difficulty: "Facile",
            matchedInventoryItemNames: matched,
            pantryStaples: translatedIngredients,
            steps: steps,
            chefTip: "Idéale pour utiliser vos aliments congelés en priorité et éviter tout gaspillage alimentaire !",
            thumbnailURL: meal.strMealThumb,
            area: frenchArea,
            youtubeURL: meal.strYoutube,
            isFavorite: false,
            itemsToBuyCount: missing.count,
            missingIngredients: missing
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

// MARK: - Moteur Culinaire Local de Secours (100% Hors-Ligne & Conscient des Ingrédients)

typealias RecipeEngine = LocalRecipeEngine

struct LocalRecipeEngine {
    static func generateRecipes(from items: [FoodItem], maxTimeMinutes: Int? = nil, isVeggieOnly: Bool = false) -> [AntiWasteRecipe] {
        guard !items.isEmpty else { return [] }
        
        let sortedItems = items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
        
        var availableMeat = sortedItems.filter { isMeatLike($0) }
        var availableFish = sortedItems.filter { isFishLike($0) }
        let availableVeg = sortedItems.filter { isVegetableLike($0) }
        let availableFruits = sortedItems.filter { isFruitLike($0) }
        let availableBread = sortedItems.filter { isBreadLike($0) }
        let availablePastaRice = sortedItems.filter { isPastaOrRiceLike($0) }
        
        if isVeggieOnly {
            availableMeat = []
            availableFish = []
        }
        
        var results: [AntiWasteRecipe] = []
        
        // --- 1. SPÉCIALITÉ YOGOURT / YAOURT / SKYR / FROMAGE BLANC ---
        if let yogurtItem = sortedItems.first(where: { isYogurtLike($0) }) {
            let fruitComp = availableFruits.first
            var matchedYogurt = [yogurtItem.name]
            if let f = fruitComp { matchedYogurt.append(f.name) }
            
            // Gâteau Moelleux au Yaourt Familial (Pas de poêle !)
            results.append(AntiWasteRecipe(
                title: "Gâteau Moelleux Familial au \(yogurtItem.name)",
                emoji: "🍰",
                category: "Pâtisserie & Dessert",
                prepTimeMinutes: 10,
                cookTimeMinutes: 35,
                servings: 6,
                difficulty: "Très facile",
                matchedInventoryItemNames: [yogurtItem.name],
                pantryStaples: ["3 œufs entiers", "2 pots de sucre", "3 pots de farine", "1/2 pot d'huile végétale", "1 sachet de levure chimique", "1 sachet de sucre vanillé"],
                steps: [
                    "Préchauffez votre four à 180°C (thermostat 6) et beurrez un moule à manqué.",
                    "Videz le \(yogurtItem.name) dans un grand saladier (le pot servira d'unité de mesure).",
                    "Ajoutez les 3 œufs et les 2 pots de sucre, puis fouettez vigoureusement jusqu'à ce que le mélange blanchisse.",
                    "Incorporez progressivement les 3 pots de farine et le sachet de levure chimique en mélangeant avec une spatule.",
                    "Versez le 1/2 pot d'huile et le sucre vanillé pour obtenir une pâte lisse et homogène.",
                    "Versez dans le moule et enfournez pendant 30 à 35 minutes jusqu'à ce que la pointe d'un couteau ressorte sèche."
                ],
                chefTip: "Le grand classique anti-gaspillage : inratable, moelleux et idéal pour écouler tous types de yaourts ou skyr !"
            ))
            
            // Parfait & Bol Fraîcheur au Yaourt & Miel
            results.append(AntiWasteRecipe(
                title: fruitComp != nil ? "Parfait Fraîcheur au \(yogurtItem.name) & \(fruitComp!.name)" : "Bol Douceur au \(yogurtItem.name), Miel & Granola",
                emoji: "🍧",
                category: "Petit-Déjeuner & Dessert",
                prepTimeMinutes: 5,
                cookTimeMinutes: 0,
                servings: 2,
                difficulty: "Ultra Rapide",
                matchedInventoryItemNames: matchedYogurt,
                pantryStaples: ["2 c. à soupe de miel ou sirop d'érable", "4 c. à soupe de flocons d'avoine ou granola", "Une pincée de cannelle", "Quelques amandes ou noix"],
                steps: [
                    "Déposez généreusement le \(yogurtItem.name) bien frais dans deux jolis bols ou verrines.",
                    fruitComp != nil ? "Ajoutez les \(fruitComp!.name) décongelés ou mixés en coulis par-dessus." : "Nappez d'un filet de miel doré.",
                    "Saupoudrez de flocons d'avoine croustillants et d'une pincée de cannelle.",
                    "Dégustez immédiatement à la cuillère pour un petit-déjeuner ou goûter sain et onctueux."
                ],
                chefTip: "Aucune cuisson nécessaire : préserve toute la fraîcheur et les ferments lactiques du produit."
            ))
            
            // Sauce Fraîcheur Méditerranéenne façon Tzatziki
            results.append(AntiWasteRecipe(
                title: "Sauce Fraîcheur au \(yogurtItem.name), Ail & Fines Herbes",
                emoji: "🥗",
                category: "Sauce & Tartinade",
                prepTimeMinutes: 8,
                cookTimeMinutes: 0,
                servings: 4,
                difficulty: "Facile",
                matchedInventoryItemNames: [yogurtItem.name],
                pantryStaples: ["1 gousse d'ail pressée", "1 c. à soupe d'huile d'olive", "Jus de 1/2 citron", "Sel fin et poivre blanc", "Menthe, aneth ou ciboulette fraîche"],
                steps: [
                    "Versez le \(yogurtItem.name) dans un bol.",
                    "Ajoutez l'ail pressé, le jus de citron et l'huile d'olive.",
                    "Ciselez finement les herbes et incorporez-les en mélangeant délicatement.",
                    "Salez, poivrez et réservez 15 minutes au réfrigérateur avant de servir avec du pain grillé ou des crudités."
                ],
                chefTip: "Parfait pour tremper des légumes croquants ou accompagner une grillade estivale."
            ))
        }
        
        // --- 2. SPÉCIALITÉ GLACE / CRÈME GLACÉE / SORBET ---
        if let iceCreamItem = sortedItems.first(where: { isIceCreamLike($0) }) {
            let fruitComp = availableFruits.first
            var matched = [iceCreamItem.name]
            if let f = fruitComp { matched.append(f.name) }
            
            results.append(AntiWasteRecipe(
                title: "Coupe Gourmande Glacée au \(iceCreamItem.name) & Coulis Maison",
                emoji: "🍨",
                category: "Dessert Glacé",
                prepTimeMinutes: 5,
                cookTimeMinutes: 2,
                servings: 2,
                difficulty: "Très facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["50g de chocolat noir ou 2 c. à soupe de miel", "Amandes effilées ou biscuits émiettés", "2 c. à soupe de lait"],
                steps: [
                    "Sortez le \(iceCreamItem.name) 5 minutes avant pour faciliter le pochage.",
                    "Dans une petite coupelle, faites fondre le chocolat avec le lait 30 secondes au micro-ondes.",
                    fruitComp != nil ? "Faites tiédir les \(fruitComp!.name) avec une cuillère de sucre pour former un coulis minute." : "Formez 2 belles boules de glace par coupe.",
                    "Nappez du coulis chaud sur la glace froide et parsemez d'amandes effilées."
                ],
                chefTip: "Le contraste thermique chaud-froid sublime la dégustation !"
            ))
        }
        
        // --- 3. SPÉCIALITÉ PAIN / BRIOCHE ---
        if let breadItem = sortedItems.first(where: { isBreadLike($0) }) {
            results.append(AntiWasteRecipe(
                title: "Pain Perdu Doré Moelleux au \(breadItem.name)",
                emoji: "🍞",
                category: "Dessert & Goûter",
                prepTimeMinutes: 5,
                cookTimeMinutes: 6,
                servings: 3,
                difficulty: "Très facile",
                matchedInventoryItemNames: [breadItem.name],
                pantryStaples: ["2 œufs entiers", "20 cl de lait", "40g de sucre roux", "20g de beurre", "1 pincée de cannelle"],
                steps: [
                    "Dans une assiette creuse, battez les 2 œufs avec le lait, le sucre et la cannelle.",
                    "Coupez le \(breadItem.name) en tranches épaisses et trempez-les des deux côtés pour bien les imbiber.",
                    "Faites fondre le beurre dans une poêle chaude à feu moyen.",
                    "Déposez les tranches et faites-les dorer 2 à 3 minutes de chaque côté jusqu'à belle coloration dorée.",
                    "Servez chaud saupoudré d'un voile de sucre glace ou de sirop d'érable."
                ],
                chefTip: "La reine des recettes anti-gaspillage pour redonner une texture ultra-moelleuse au pain décongelé."
            ))
        }
        
        // --- 4. SPÉCIALITÉ FROMAGE DÉCONGELÉ ---
        if let cheeseItem = sortedItems.first(where: { isCheeseLike($0) }) {
            let breadComp = availableBread.first
            var matched = [cheeseItem.name]
            if let b = breadComp { matched.append(b.name) }
            
            results.append(AntiWasteRecipe(
                title: "Croque-Monsieur Croustillant au \(cheeseItem.name) Fondu",
                emoji: "🥪",
                category: "Snack Chaud",
                prepTimeMinutes: 10,
                cookTimeMinutes: 10,
                servings: 2,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["4 tranches de pain de mie ou pain", "2 tranches de jambon (optionnel)", "20g de beurre", "1 c. à soupe de crème fraîche", "Poivre"],
                steps: [
                    "Tartinez légèrement les tranches de pain avec une fine couche de beurre et de crème.",
                    "Déposez de généreuses tranches ou copeaux de \(cheeseItem.name) à l'intérieur.",
                    "Refermez les sandwiches et déposez encore un peu de \(cheeseItem.name) râpé sur le dessus.",
                    "Enfournez à 200°C pendant 10 minutes ou faites dorer dans une poêle avec une noisette de beurre jusqu'à ce que le fromage soit bien filant."
                ],
                chefTip: "Le fromage décongelé fond encore plus rapidement et libère toutes ses saveurs."
            ))
        }
        
        // --- 5. SPÉCIALITÉ FRUITS SURGELÉS ---
        if let fruitItem = availableFruits.first {
            results.append(AntiWasteRecipe(
                title: "Crumble Croustillant Doré aux \(fruitItem.name)",
                emoji: "🥧",
                category: "Dessert au Four",
                prepTimeMinutes: 12,
                cookTimeMinutes: 25,
                servings: 4,
                difficulty: "Facile",
                matchedInventoryItemNames: [fruitItem.name],
                pantryStaples: ["100g de farine", "80g de beurre froid en dés", "80g de sucre roux", "1 sachet de sucre vanillé", "1 pincée de cannelle"],
                steps: [
                    "Préchauffez votre four à 180°C (th. 6).",
                    "Disposez directement les \(fruitItem.name) surgelés dans un plat à gratin et saupoudrez d'un peu de sucre.",
                    "Dans un saladier, mélangez la farine, le sucre roux, la vanille et le beurre froid coupé en petits dés.",
                    "Sablez du bout des doigts pour obtenir une texture grumeleuse et friable.",
                    "Répartissez le crumble sur les fruits sans tasser.",
                    "Enfournez 25 à 30 minutes jusqu'à ce que la croûte soit bien dorée et que le jus des fruits bouillonne sur les côtés."
                ],
                chefTip: "Servez tiède avec une boule de glace vanille pour un délice irrésistible."
            ))
        }
        
        // --- 6. SPÉCIALITÉ POISSON & FRUITS DE MER ---
        if let fishItem = isVeggieOnly ? nil : availableFish.first {
            let vegComp = availableVeg.first
            var matched = [fishItem.name]
            if let v = vegComp { matched.append(v.name) }
            
            results.append(AntiWasteRecipe(
                title: "Papillote Délicate de \(fishItem.name) aux Agrumes & Fines Herbes",
                emoji: "🐟",
                category: "Poisson au Four",
                prepTimeMinutes: 10,
                cookTimeMinutes: 18,
                servings: 2,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["1 citron jaune ou vert en rondelles", "2 c. à soupe d'huile d'olive", "Thym ou aneth frais", "Sel fin et poivre du moulin"],
                steps: [
                    "Préchauffez votre four à 190°C.",
                    "Découpez de grandes feuilles de papier cuisson ou d'aluminium.",
                    "Déposez le \(fishItem.name) au centre de chaque feuille.",
                    vegComp != nil ? "Ajoutez quelques rondelles de \(vegComp!.name) autour du poisson." : "Arrosez d'un filet d'huile d'olive et de jus de citron.",
                    "Déposez 2 rondelles de citron sur le poisson, saupoudrez d'herbes aromatiques, de sel et de poivre.",
                    "Fermez hermétiquement la papillote en repliant les bords et enfournez pendant 15 à 18 minutes."
                ],
                chefTip: "La cuisson en papillote préserve la chair délicate du poisson surgelé sans jamais l'assécher."
            ))
        }
        
        // --- 7. SPÉCIALITÉ VIANDES & VOLAILLES ---
        if let meatItem = isVeggieOnly ? nil : availableMeat.first {
            let vegComp = availableVeg.first
            var matched = [meatItem.name]
            if let v = vegComp { matched.append(v.name) }
            
            results.append(AntiWasteRecipe(
                title: "Poêlée Rustique Savoureuse au \(meatItem.name)",
                emoji: "🥩",
                category: "Poêlée & Sauté",
                prepTimeMinutes: 10,
                cookTimeMinutes: 15,
                servings: 2,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["2 c. à soupe d'huile d'olive ou beurre", "1 oignon émincé", "1 gousse d'ail", "Herbes de Provence", "Sel et poivre"],
                steps: [
                    "Faites chauffer l'huile dans une poêle à feu moyen-vif.",
                    "Faites suer l'oignon émincé et la gousse d'ail écrasée pendant 2 minutes.",
                    "Ajoutez le \(meatItem.name) découpé en morceaux et faites-le dorer sur toutes ses faces.",
                    vegComp != nil ? "Incorporez les \(vegComp!.name) et poursuivez la cuisson 8 minutes en remuant." : "Baissez à feu moyen et laissez cuire à cœur 6 à 8 minutes.",
                    "Assaisonnez avec les herbes de Provence, le sel et le poivre avant de dresser bien chaud."
                ],
                chefTip: "Pour les viandes épaisses, prévoyez une décongélation lente au frigo pour garder toute la tendreté."
            ))
        }
        
        // --- 8. SPÉCIALITÉ LÉGUMES SURGELÉS (Gratin ou Velouté) ---
        if let vegItem = availableVeg.first {
            let secondVeg = availableVeg.first(where: { $0.id != vegItem.id })
            var matched = [vegItem.name]
            if let v2 = secondVeg { matched.append(v2.name) }
            
            // Gratin Fondant
            results.append(AntiWasteRecipe(
                title: "Gratin Fondant Doré de \(vegItem.name)",
                emoji: "🧀",
                category: "Gratin au Four",
                prepTimeMinutes: 12,
                cookTimeMinutes: 25,
                servings: 4,
                difficulty: "Facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["20 cl de crème fraîche", "100g de fromage râpé (gruyère ou mozzarella)", "1 gousse d'ail", "1 pincée de muscade", "Sel et poivre"],
                steps: [
                    "Préchauffez votre four à 200°C.",
                    "Plongez les \(vegItem.name) surgelés dans une casserole d'eau bouillante salée pendant 4 minutes, puis égouttez soigneusement.",
                    "Frottez le fond d'un plat à gratin avec la gousse d'ail coupée en deux.",
                    "Disposez les légumes dans le plat, nappez de crème assaisonnée de muscade, sel et poivre.",
                    "Recouvrez généreusement de fromage râpé et enfournez pour 20 à 25 minutes jusqu'à belle croûte gratinée."
                ],
                chefTip: "Bien égoutter les légumes surgelés permet d'éviter de détremper le gratin."
            ))
            
            // Velouté Réconfortant
            results.append(AntiWasteRecipe(
                title: "Velouté Onctueux Réconfortant de \(vegItem.name)",
                emoji: "🥣",
                category: "Soupe & Velouté",
                prepTimeMinutes: 8,
                cookTimeMinutes: 18,
                servings: 4,
                difficulty: "Très facile",
                matchedInventoryItemNames: matched,
                pantryStaples: ["1 cube de bouillon de légumes", "600 ml d'eau chaude", "2 c. à soupe de crème fraîche", "1 noisette de beurre", "Sel & poivre"],
                steps: [
                    "Dans une casserole, faites fondre la noisette de beurre et faites suer les \(vegItem.name) pendant 3 minutes.",
                    "Versez l'eau chaude et émiettez le cube de bouillon.",
                    "Portez à ébullition, couvrez et laissez mijoter à feu moyen pendant 15 minutes.",
                    "Mixez finement au mixeur plongeant jusqu'à obtenir une texture soyeuse et veloutée.",
                    "Incorporez la crème fraîche, assaisonnez à votre convenance et servez bien chaud avec des croûtons."
                ],
                chefTip: "Une excellente façon de valoriser les fonds de sachets de légumes du congélateur !"
            ))
        }
        
        // --- 9. SPÉCIALITÉ PÂTES / RIZ / FÉCULENTS ---
        if let starchItem = availablePastaRice.first {
            results.append(AntiWasteRecipe(
                title: "Riz ou Pâtes Sautées Express au \(starchItem.name)",
                emoji: "🥢",
                category: "Wok & Poêlée",
                prepTimeMinutes: 8,
                cookTimeMinutes: 10,
                servings: 2,
                difficulty: "Très facile",
                matchedInventoryItemNames: [starchItem.name],
                pantryStaples: ["2 c. à soupe de sauce soja ou huile d'olive", "1 œuf battu", "1 gousse d'ail émincée", "1 oignon nouveau ou persil"],
                steps: [
                    "Faites chauffer une cuillère d'huile dans un wok ou une poêle à feu vif.",
                    "Ajoutez l'ail et faites revenir 1 minute.",
                    "Versez le \(starchItem.name) et faites sauter vivement pendant 5 minutes en remuant.",
                    "Poussez les féculents sur le côté, versez l'œuf battu pour le brouiller rapidement, puis mélangez le tout.",
                    "Arrosez de sauce soja et parsemez d'herbes fraîches avant de servir."
                ],
                chefTip: "Le plat minute idéal pour recycler les restes de féculents congelés."
            ))
        }
        
        // Calcul des ingrédients à acheter pour chaque recette locale et tri par le moins d'achats
        let freezerNames = items.map { $0.name }
        var finalizedResults: [AntiWasteRecipe] = []
        
        for r in results {
            var recipe = r
            var missing: [String] = []
            for staple in recipe.pantryStaples {
                let stapleLower = staple.lowercased()
                let isFreezerMatch = freezerNames.contains { name in
                    let nameLower = name.lowercased()
                    return stapleLower.contains(nameLower) || nameLower.contains(stapleLower)
                }
                if !isFreezerMatch {
                    missing.append(staple)
                }
            }
            recipe.missingIngredients = missing
            recipe.itemsToBuyCount = missing.count
            finalizedResults.append(recipe)
        }
        
        // Tri prioritaire : Recettes avec le MOINS d'ingrédients à acheter
        finalizedResults.sort {
            if $0.itemsToBuyCount != $1.itemsToBuyCount {
                return $0.itemsToBuyCount < $1.itemsToBuyCount
            }
            return $0.matchedInventoryItemNames.count > $1.matchedInventoryItemNames.count
        }
        
        if let maxT = maxTimeMinutes {
            finalizedResults = finalizedResults.filter { ($0.prepTimeMinutes + $0.cookTimeMinutes) <= maxT }
        }
        
        return finalizedResults
    }
    
    // MARK: - Détection Intelligente de la Nature Culinaire des Aliments
    
    private static func isYogurtLike(_ item: FoodItem) -> Bool {
        let n = item.name.lowercased()
        return n.contains("yaourt") || n.contains("yogourt") || n.contains("yogurt") ||
               n.contains("skyr") || n.contains("fromage blanc") || n.contains("petit suisse") ||
               n.contains("faisselle") || n.contains("yoghurt")
    }
    
    private static func isIceCreamLike(_ item: FoodItem) -> Bool {
        let n = item.name.lowercased()
        return n.contains("glace") || n.contains("sorbet") || n.contains("ice cream") ||
               n.contains("creme glacee") || n.contains("crème glacée") || n.contains("eskimo") ||
               n.contains("magnum") || n.contains("cornet")
    }
    
    private static func isCheeseLike(_ item: FoodItem) -> Bool {
        if isYogurtLike(item) { return false }
        let n = item.name.lowercased()
        return n.contains("fromage") || n.contains("cheese") || n.contains("mozzarella") ||
               n.contains("parmesan") || n.contains("cheddar") || n.contains("gruyère") ||
               n.contains("gruyere") || n.contains("raclette") || n.contains("comté") ||
               n.contains("comte") || n.contains("chèvre") || n.contains("chevre") ||
               n.contains("gouda") || n.contains("camembert") || n.contains("emmental")
    }
    
    private static func isFruitLike(_ item: FoodItem) -> Bool {
        if item.category == .fruits { return true }
        let n = item.name.lowercased()
        return n.contains("fraise") || n.contains("framboise") || n.contains("myrtille") ||
               n.contains("pomme") || n.contains("poire") || n.contains("mangue") ||
               n.contains("ananas") || n.contains("mûre") || n.contains("cerise") ||
               n.contains("banane") || n.contains("fruit") || n.contains("baie")
    }
    
    private static func isMeatLike(_ item: FoodItem) -> Bool {
        if item.category == .meat { return true }
        let n = item.name.lowercased()
        return n.contains("poulet") || n.contains("boeuf") || n.contains("bœuf") ||
               n.contains("steak") || n.contains("porc") || n.contains("jambon") ||
               n.contains("dinde") || n.contains("canard") || n.contains("lardon") ||
               n.contains("bacon") || n.contains("viande") || n.contains("saucisse") ||
               n.contains("haché") || n.contains("hache") || n.contains("agneau") ||
               n.contains("veau")
    }
    
    private static func isFishLike(_ item: FoodItem) -> Bool {
        if item.category == .fish { return true }
        let n = item.name.lowercased()
        return n.contains("saumon") || n.contains("poisson") || n.contains("cabillaud") ||
               n.contains("morue") || n.contains("thon") || n.contains("crevette") ||
               n.contains("gambas") || n.contains("moule") || n.contains("colin") ||
               n.contains("lieu") || n.contains("fruits de mer") || n.contains("truite") ||
               n.contains("saint jacques") || n.contains("calmar") || n.contains("seiche")
    }
    
    private static func isVegetableLike(_ item: FoodItem) -> Bool {
        if isFruitLike(item) || isYogurtLike(item) { return false }
        if item.category == .vegetables { return true }
        let n = item.name.lowercased()
        return n.contains("courgette") || n.contains("carotte") || n.contains("tomate") ||
               n.contains("brocoli") || n.contains("haricot") || n.contains("pois") ||
               n.contains("poivron") || n.contains("champignon") || n.contains("épinard") ||
               n.contains("epinard") || n.contains("aubergine") || n.contains("chou") ||
               n.contains("oignon") || n.contains("poireau") || n.contains("pomme de terre") ||
               n.contains("patate") || n.contains("légume") || n.contains("legume")
    }
    
    private static func isBreadLike(_ item: FoodItem) -> Bool {
        let n = item.name.lowercased()
        return n.contains("pain") || n.contains("baguette") || n.contains("brioche") ||
               n.contains("toast") || n.contains("croissant") || n.contains("mie")
    }
    
    private static func isPastaOrRiceLike(_ item: FoodItem) -> Bool {
        let n = item.name.lowercased()
        return n.contains("riz") || n.contains("pate") || n.contains("pâte") ||
               n.contains("spaghetti") || n.contains("penne") || n.contains("coquillette") ||
               n.contains("tagliatelle") || n.contains("nouille") || n.contains("gnocchi")
    }
    
    private static func isDairyLike(_ item: FoodItem) -> Bool {
        if item.category == .dairy { return true }
        return isYogurtLike(item) || isCheeseLike(item)
    }
}

// MARK: - Vue Principale du Générateur de Recettes Anti-Gaspi

struct MealGeneratorView: View {
    @EnvironmentObject var inventory: InventoryManager
    @EnvironmentObject var license: LicenseManager
    
    enum RecipeTabSection: Int {
        case suggestions = 0
        case favorites = 1
    }
    
    enum RecipeSortOption: String, CaseIterable, Identifiable {
        case fewestItemsToBuy = "Moins d'achats 🛒"
        case urgency = "Dates courtes ⚡"
        case quickest = "Express ⏱️"
        
        var id: String { rawValue }
    }
    
    @State private var currentTabSection: RecipeTabSection = .suggestions
    @State private var sortOption: RecipeSortOption = .fewestItemsToBuy
    @State private var suggestedRecipes: [AntiWasteRecipe] = []
    @State private var favorites: [AntiWasteRecipe] = []
    
    @State private var maxTimeFilter: Int = 90
    @State private var isVeggieOnly = false
    @State private var searchQuery = ""
    @State private var isLoading = false
    
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
                        
                        Text("Générateur de Recettes Anti-Gaspi")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Transformez instantanément vos produits proches de la date limite en délicieux repas équilibrés avec étapes pas-à-pas, photos et déstockage automatique.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureBenefitRow(icon: "bolt.fill", title: "Priorité aux dates courtes", description: "Cible d'abord les aliments à consommer en urgence")
                            FeatureBenefitRow(icon: "photo.fill", title: "Photos & Étapes en Français", description: "Visuels détaillés, dosages précis et guide de préparation")
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
                    VStack(spacing: 8) {
                        // Barre de recherche
                        HStack(spacing: 8) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Rechercher une recette ou un ingrédient...", text: $searchQuery)
                                    .onSubmit {
                                        Task { await searchCustomRecipe() }
                                    }
                                if !searchQuery.isEmpty {
                                    Button {
                                        searchQuery = ""
                                        Task { await loadAutoFreezerRecipes() }
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
                                Task { await searchCustomRecipe() }
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
                            .disabled(isLoading)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Sélecteur d'onglets
                        Picker("Section", selection: $currentTabSection) {
                            Text("Idées du Stock (\(suggestedRecipes.count))").tag(RecipeTabSection.suggestions)
                            Text("Mes Favoris (\(favorites.count))").tag(RecipeTabSection.favorites)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Filtres et actions rapides
                        if currentTabSection == .suggestions {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // Menu de Tri (Moins d'achats prioritaire)
                                    Menu {
                                        ForEach(RecipeSortOption.allCases) { opt in
                                            Button {
                                                sortOption = opt
                                                applyFilters()
                                            } label: {
                                                HStack {
                                                    Text(opt.rawValue)
                                                    if sortOption == opt {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.arrow.down")
                                            Text(sortOption.rawValue)
                                        }
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.cyan.opacity(0.15))
                                        .foregroundColor(.cyan)
                                        .cornerRadius(8)
                                    }
                                    
                                    Menu {
                                        Button("Tous les temps") { maxTimeFilter = 90; applyFilters() }
                                        Button("Moins de 20 min (Express)") { maxTimeFilter = 20; applyFilters() }
                                        Button("Moins de 35 min") { maxTimeFilter = 35; applyFilters() }
                                        Button("Moins de 50 min") { maxTimeFilter = 50; applyFilters() }
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
                                        applyFilters()
                                    } label: {
                                        HStack {
                                            Image(systemName: isVeggieOnly ? "leaf.fill" : "leaf")
                                            Text("Végétarien")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isVeggieOnly ? Color.green : Color.secondary.opacity(0.12))
                                        .foregroundColor(isVeggieOnly ? .white : .primary)
                                        .cornerRadius(8)
                                    }
                                    
                                    Button {
                                        Task { await fetchSurpriseRecipe() }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "dice.fill")
                                            Text("Surprise 🎲")
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.15))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                    }
                                    
                                    Button {
                                        Task { await loadAutoFreezerRecipes() }
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
                    }
                    .padding(.bottom, 6)
                    
                    // Contenu principal
                    Group {
                        switch currentTabSection {
                        case .suggestions:
                            if isLoading && suggestedRecipes.isEmpty {
                                VStack(spacing: 16) {
                                    Spacer()
                                    ProgressView("Analyse de votre congélateur & génération...")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            } else if suggestedRecipes.isEmpty {
                                emptyStateView(
                                    icon: "sparkles",
                                    title: "Aucune recette trouvée",
                                    message: inventory.items.isEmpty ? "Ajoutez des aliments à votre congélateur pour obtenir des recettes adaptées." : "Modifiez vos filtres ou effectuez une autre recherche."
                                )
                            } else {
                                recipeListView(recipes: filteredRecipes(suggestedRecipes))
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
            .navigationTitle("Recettes Anti-Gaspi")
            .onAppear {
                loadFavorites()
                if suggestedRecipes.isEmpty {
                    Task { await loadAutoFreezerRecipes() }
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
    
    // MARK: - Filtres & Vues Réutilisables
    
    private func filteredRecipes(_ source: [AntiWasteRecipe]) -> [AntiWasteRecipe] {
        var list = source
        if maxTimeFilter < 90 {
            list = list.filter { ($0.prepTimeMinutes + $0.cookTimeMinutes) <= maxTimeFilter }
        }
        if isVeggieOnly {
            list = list.filter { recipe in
                let cat = recipe.category.lowercased()
                return cat.contains("végé") || cat.contains("accompagnement") || cat.contains("four") || cat.contains("dessert")
            }
        }
        
        switch sortOption {
        case .fewestItemsToBuy:
            list.sort {
                if $0.itemsToBuyCount != $1.itemsToBuyCount {
                    return $0.itemsToBuyCount < $1.itemsToBuyCount
                }
                return $0.matchedInventoryItemNames.count > $1.matchedInventoryItemNames.count
            }
        case .urgency:
            // Conserve l'ordre natif des dates courtes
            break
        case .quickest:
            list.sort { ($0.prepTimeMinutes + $0.cookTimeMinutes) < ($1.prepTimeMinutes + $1.cookTimeMinutes) }
        }
        
        return list
    }
    
    private func applyFilters() {
        // Déclenche le rafraîchissement de l'affichage via @State
    }
    
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
    
    // MARK: - Logique de Génération Automatique
    
    private func loadAutoFreezerRecipes() async {
        isLoading = true
        
        let stockNames = inventory.items.map { $0.name }
        var collectedRecipes: [AntiWasteRecipe] = []
        
        // 1. Interroger l'API pour les produits les plus urgents
        let sortedByExpiry = inventory.items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry }
        let topUrgentItems = Array(sortedByExpiry.prefix(4))
        
        for item in topUrgentItems {
            let onlineResults = await TheMealDBService.shared.searchMeals(query: item.name, matchedStockNames: stockNames)
            for r in onlineResults {
                if !collectedRecipes.contains(where: { $0.title == r.title }) {
                    collectedRecipes.append(r)
                }
            }
        }
        
        // 2. Si aucune recette en ligne n'est trouvée (ou hors-ligne), générer les recettes locales anti-gaspi
        let localBackup = LocalRecipeEngine.generateRecipes(from: inventory.items)
        for r in localBackup {
            if !collectedRecipes.contains(where: { $0.title == r.title }) {
                collectedRecipes.append(r)
            }
        }
        
        DispatchQueue.main.async {
            self.suggestedRecipes = collectedRecipes
            self.isLoading = false
        }
    }
    
    private func searchCustomRecipe() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        let stockNames = inventory.items.map { $0.name }
        let results = await TheMealDBService.shared.searchMeals(query: searchQuery, matchedStockNames: stockNames)
        
        DispatchQueue.main.async {
            if !results.isEmpty {
                self.suggestedRecipes = results
            } else {
                // Recherche dans les recettes locales
                let localFiltered = LocalRecipeEngine.generateRecipes(from: self.inventory.items)
                    .filter { $0.title.localizedCaseInsensitiveContains(self.searchQuery) ||
                              $0.matchedInventoryItemNames.contains(where: { $0.localizedCaseInsensitiveContains(self.searchQuery) }) }
                if !localFiltered.isEmpty {
                    self.suggestedRecipes = localFiltered
                } else {
                    self.triggerToast("Aucune recette trouvée pour '\(self.searchQuery)'")
                }
            }
            self.isLoading = false
        }
    }
    
    private func fetchSurpriseRecipe() async {
        isLoading = true
        let stockNames = inventory.items.map { $0.name }
        if let surprise = await TheMealDBService.shared.fetchRandomMeal(matchedStockNames: stockNames) {
            DispatchQueue.main.async {
                self.suggestedRecipes = [surprise] + self.suggestedRecipes.filter { $0.title != surprise.title }
                self.isLoading = false
                self.triggerToast("Nouvelle recette surprise découverte 🎲")
            }
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
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
            triggerToast("Cuisiné ! Déstocké : \(consumedNames.joined(separator: ", "))")
        }
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
        var text = "🍳 Recette Anti-Gaspi : \(recipe.title)\n"
        if let area = recipe.area {
            text += "🌍 Cuisine : \(area)\n"
        }
        text += "⏱️ Préparation : \(recipe.prepTimeMinutes) min • Cuisson : \(recipe.cookTimeMinutes) min • \(recipe.servings) pers.\n\n"
        
        if !recipe.matchedInventoryItemNames.isEmpty {
            text += "❄️ Du congélateur :\n"
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
            text += "\n📺 Vidéo tutoriel : \(yt)\n"
        }
        
        text += "\n💡 Astuce Anti-Gaspi : \(recipe.chefTip)"
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

// MARK: - Carte Visuelle d'une Recette Anti-Gaspi

struct RecipeCardView: View {
    let recipe: AntiWasteRecipe
    let isFav: Bool
    let onToggleFav: () -> Void
    let onCook: () -> Void
    let onShare: () -> Void
    
    @EnvironmentObject var grocery: GroceryListManager
    @State private var isExpanded = false
    @State private var addedToGroceryToast = false
    
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
                                .frame(width: 65, height: 65)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Text(recipe.emoji)
                                .font(.system(size: 34))
                                .frame(width: 65, height: 65)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            ProgressView()
                                .frame(width: 65, height: 65)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text(recipe.emoji)
                        .font(.system(size: 34))
                        .frame(width: 65, height: 65)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .bold()
                        .lineLimit(2)
                    
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
                    
                    // Badge Anti-Gaspi & Achats nécessaires
                    if recipe.itemsToBuyCount == 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("0 achat • 100% dans votre congélateur !")
                        }
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "cart.fill")
                            Text("\(recipe.itemsToBuyCount) ingrédient(s) à prévoir / placard")
                        }
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
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
                
                // Ingrédients du congélateur
                if !recipe.matchedInventoryItemNames.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("❄️ Ingrédients de votre congélateur :")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.cyan)
                        
                        ForEach(recipe.matchedInventoryItemNames, id: \.self) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                                Text(item)
                                    .font(.caption)
                                    .bold()
                            }
                        }
                    }
                }
                
                // Ingrédients du placard ou à acheter
                if !recipe.missingIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("🛒 Ingrédients à prévoir / acheter :")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Button {
                                _ = grocery.addMissingIngredients(from: recipe.title, missing: recipe.missingIngredients)
                                withAnimation { addedToGroceryToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation { addedToGroceryToast = false }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: addedToGroceryToast ? "checkmark.circle.fill" : "cart.badge.plus")
                                    Text(addedToGroceryToast ? "Ajouté !" : "Ajouter à l'épicerie")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(addedToGroceryToast ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundColor(addedToGroceryToast ? .green : .orange)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        ForEach(recipe.missingIngredients, id: \.self) { staple in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(staple)
                                    .font(.caption)
                            }
                        }
                    }
                } else if recipe.pantryStaples.count > recipe.matchedInventoryItemNames.count {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🧂 Assaisonnements & Placard :")
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
                
                // Vidéo ou astuce
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
