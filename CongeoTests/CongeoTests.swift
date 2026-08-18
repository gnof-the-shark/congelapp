//
//  CongeoTests.swift
//  CongeoTests
//
//  Created by Christophe White on 2026-08-17.
//

import XCTest
@testable import Congeo

final class CongeoTests: XCTestCase {

    override func setUpWithError() throws {
        super.setUp()
    }

    override func tearDownWithError() throws {
        super.tearDown()
    }

    func testLicenseManagerTiers() throws {
        let license = LicenseManager()
        
        license.upgrade(to: .free)
        XCTAssertEqual(license.currentTier, .free)
        XCTAssertEqual(license.currentTier.maxItems, 20)
        XCTAssertEqual(license.currentTier.maxLocations, 1)
        XCTAssertFalse(license.currentTier.hasAILocator)
        XCTAssertFalse(license.currentTier.hasAntiWasteRecipeGenerator)
        
        license.upgrade(to: .pro)
        XCTAssertEqual(license.currentTier, .pro)
        XCTAssertEqual(license.currentTier.maxItems, Int.max)
        XCTAssertEqual(license.currentTier.maxLocations, 2)
        XCTAssertTrue(license.currentTier.hasAILocator)
        XCTAssertFalse(license.currentTier.hasAntiWasteRecipeGenerator)
        
        license.upgrade(to: .family)
        XCTAssertEqual(license.currentTier, .family)
        XCTAssertEqual(license.currentTier.maxItems, Int.max)
        XCTAssertEqual(license.currentTier.maxLocations, Int.max)
        XCTAssertTrue(license.currentTier.hasAILocator)
        XCTAssertTrue(license.currentTier.hasAntiWasteRecipeGenerator)
        XCTAssertTrue(license.currentTier.hasFamilySharing)
    }

    func testCategoryDetection() throws {
        XCTAssertEqual(FoodCategory.detect(from: "Steak haché 15%"), .meat)
        XCTAssertEqual(FoodCategory.detect(from: "Filet de saumon sauvage"), .fish)
        XCTAssertEqual(FoodCategory.detect(from: "Haricots verts extra-fins"), .vegetables)
        XCTAssertEqual(FoodCategory.detect(from: "Framboises surgelées"), .fruits)
        XCTAssertEqual(FoodCategory.detect(from: "Pizza 4 fromages"), .readyMeals)
        XCTAssertEqual(FoodCategory.detect(from: "Baguette tradition"), .bakery)
        XCTAssertEqual(FoodCategory.detect(from: "Glace vanille pécan"), .dairy)
    }

    func testInventoryItemManagement() throws {
        let inventory = InventoryManager()
        let license = LicenseManager()
        license.upgrade(to: .pro)
        
        let initialCount = inventory.items.count
        let success = inventory.addItem(
            name: "Test Poulet",
            quantity: 3,
            location: "Maison",
            expiryDate: Date().addingTimeInterval(86400 * 2),
            license: license
        )
        XCTAssertTrue(success)
        XCTAssertEqual(inventory.items.count, initialCount + 1)
        
        let added = inventory.items.first(where: { $0.name == "Test Poulet" })
        XCTAssertNotNil(added)
        XCTAssertEqual(added?.urgency, .critical)
        
        // Consommation
        if let id = added?.id {
            inventory.consumeItem(withId: id, count: 1)
            let updated = inventory.items.first(where: { $0.id == id })
            XCTAssertEqual(updated?.quantity, 2)
            
            inventory.deleteItem(withId: id)
            XCTAssertNil(inventory.items.first(where: { $0.id == id }))
        }
    }

    func testRecipeEngineGeneration() throws {
        let testItems = [
            FoodItem(name: "Filet de poulet", quantity: 2, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 2), category: .meat),
            FoodItem(name: "Brocolis", quantity: 1, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 3), category: .vegetables)
        ]
        
        let recipes = RecipeEngine.generateRecipes(from: testItems)
        XCTAssertFalse(recipes.isEmpty)
        
        let firstRecipe = recipes.first
        XCTAssertNotNil(firstRecipe)
        XCTAssertFalse(firstRecipe!.steps.isEmpty)
        XCTAssertFalse(firstRecipe!.pantryStaples.isEmpty)
        XCTAssertTrue(firstRecipe!.matchedInventoryItemNames.contains("Filet de poulet") || firstRecipe!.matchedInventoryItemNames.contains("Brocolis"))
    }
    
    func testFrenchCulinaryTranslator() throws {
        let translator = FrenchCulinaryTranslator.shared
        XCTAssertEqual(translator.translateSearchTermToEnglish("Poulet rôti"), "chicken")
        XCTAssertEqual(translator.translateSearchTermToEnglish("Pavé de saumon"), "salmon")
        XCTAssertEqual(translator.translateSearchTermToEnglish("Steak haché de boeuf"), "beef")
        XCTAssertEqual(translator.translateSearchTermToEnglish("Haricots verts"), "green beans")
        
        XCTAssertEqual(translator.translateCategory("chicken"), "Volaille & Poulet")
        XCTAssertEqual(translator.translateCategory("beef"), "Bœuf")
        XCTAssertEqual(translator.translateCategory("seafood"), "Poissons & Fruits de mer")
        
        let translatedTitle = translator.translateTitle("Chicken Soup")
        XCTAssertTrue(translatedTitle.contains("Poulet") || translatedTitle.contains("Soupe"))
        
        XCTAssertEqual(translator.translateSearchTermToEnglish("Yogourt à la vanille"), "yogurt")
        XCTAssertEqual(translator.translateSearchTermToEnglish("Yaourt nature"), "yogurt")
    }
    
    func testYogurtRecipeGenerationDoesNotPanFry() throws {
        let yogurtItems = [
            FoodItem(name: "Yogourt grec", quantity: 2, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 2), category: .dairy)
        ]
        
        let recipes = RecipeEngine.generateRecipes(from: yogurtItems)
        XCTAssertFalse(recipes.isEmpty)
        
        for recipe in recipes {
            for step in recipe.steps {
                XCTAssertFalse(step.lowercased().contains("revenir") && step.lowercased().contains("poêle"),
                               "Une recette de yaourt ne doit pas demander de le faire revenir à la poêle")
            }
        }
    }
    
    func testRecipeOptimizationFewestItemsToBuy() throws {
        let items = [
            FoodItem(name: "Yogourt", quantity: 1, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 2), category: .dairy),
            FoodItem(name: "Framboises", quantity: 1, location: "Maison", expiryDate: Date().addingTimeInterval(86400 * 5), category: .fruits)
        ]
        
        let recipes = RecipeEngine.generateRecipes(from: items)
        XCTAssertFalse(recipes.isEmpty)
        
        // Les recettes doivent être triées par nombre d'ingrédients à acheter croissant
        for i in 0..<(recipes.count - 1) {
            XCTAssertLessThanOrEqual(recipes[i].itemsToBuyCount, recipes[i + 1].itemsToBuyCount,
                                     "Les recettes doivent être ordonnées avec le moins d'ingrédients à acheter en priorité")
        }
    }
}
