# Congélo — Directives Agents & Documentation Technique

Ce projet est une application iOS native en **Swift / SwiftUI** conçue pour la gestion intelligente du congélateur, la détection par IA, l'anti-gaspillage alimentaire et la recommandation culinaire.

---

## 1. Intégration Culinaire TheMealDB (`https://www.themealdb.com`)

L'application intègre l'API publique **TheMealDB** (`https://www.themealdb.com/api.php`) pour enrichir le générateur de repas avec des milliers de recettes réelles du monde entier.

### Endpoints Utilisés :
- **Recherche par ingrédient / nom** : `https://www.themealdb.com/api/json/v1/1/search.php?s={query}`
- **Filtre par ingrédient** : `https://www.themealdb.com/api/json/v1/1/filter.php?i={ingredient}`
- **Détails complets** : `https://www.themealdb.com/api/json/v1/1/lookup.php?i={idMeal}`
- **Recette aléatoire** : `https://www.themealdb.com/api/json/v1/1/random.php`

### Fonctionnalités Clés du Module :
- **Traduction automatique** des termes d'ingrédients français vers les mots-clés TheMealDB (ex: *poulet* -> *chicken*, *saumon* -> *salmon*, etc.).
- **Détection des ingrédients du congélateur** présents dans la recette TheMealDB pour un déstockage automatique lors du clic sur **« Cuisiner & Déstocker »**.
- **Affichage des visuels haute qualité** avec `AsyncImage`, du pays d'origine (Zone géographique), des mesures précises et du lien vers les tutoriels vidéo YouTube.
- **Support des Favoris & Partage** avec génération d'une fiche recette complète pour Messages, Mail ou réseaux sociaux.

---

## 2. Architecture Globale du Projet

- **`CongeoApp.swift`** : Point d'entrée de l'application, instanciation des `@StateObject` (`InventoryManager`, `LicenseManager`).
- **`ContentView.swift`** : 
  - `MainTabView` : Navigation à onglets principaux.
  - `InventoryView` : Gestion complète des aliments du congélateur, emplacements (Maison, Chalet, Bureau) et calcul de péremption.
  - `BulkScannerView` : Scan de codes-barres en rafale via `AVFoundation` et `OpenFoodFacts`.
  - `ObjectFinderView` : Détection et reconnaissance visuelle sur flux caméra temps réel avec Apple `Vision` (`VNRecognizeTextRequest`).
  - `HardwareView` : Connectivité réseau local avec la station caméra **ESP32-CAM Fisheye** (`http://[IP]:[PORT]/capture`).
  - `FamilySharingView` : Synchronisation multi-appareils et foyer via `NSUbiquitousKeyValueStore` (iCloud).
  - `SettingsView` : Gestion des licences d'achat unique (*Gratuite*, *Pro 4,99 $*, *Famille 9,99 $*).
- **`MealGeneratorView.swift`** :
  - `TheMealDBService` : Client réseau asynchrone TheMealDB.
  - `RecipeEngine` : Moteur heuristique local anti-gaspillage priorisant les aliments proches de la date limite.
  - `MealGeneratorView` & `RecipeCardView` : Interface utilisateur SwiftUI réactive.

---

## 3. Directives de Développement & Bonnes Pratiques

1. **Caméra & Réseau Local** : Les autorisations `NSCameraUsageDescription` et `NSLocalNetworkUsageDescription` sont configurées dans `Congelo.xcodeproj/project.pbxproj`. Toujours vérifier les autorisations via `AVCaptureDevice.authorizationStatus` avant d'allouer les sessions de capture pour prévenir les crashes.
2. **Gestion Hors-Ligne & Robustesse** : Le moteur local `RecipeEngine` garantit que l'utilisateur a toujours accès à des recettes adaptées même en l'absence de réseau Internet.
3. **Persistance des Données** : Les données locales sont stockées dans `UserDefaults` et synchronisées avec `NSUbiquitousKeyValueStore` pour les membres de la licence Famille.
