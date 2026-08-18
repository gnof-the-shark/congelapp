# Congélo — Directives Agents & Documentation Technique

Ce projet est une application iOS native en **Swift / SwiftUI** conçue pour la gestion intelligente du congélateur, la détection par IA, l'anti-gaspillage alimentaire et la recommandation culinaire.

---

## 1. Moteur de Recettes Anti-Gaspi

Le module **Recettes Anti-Gaspi** propose automatiquement des repas équilibrés en utilisant les aliments actuellement présents dans le congélateur (priorisation des dates courtes).

### Fonctionnalités Clés :
- **Génération automatique d'idées** : Interroge la base culinaire en ligne via TheMealDB (`https://www.themealdb.com/api.php`) à partir des aliments réels du congélateur.
- **Moteur de traduction bidirectionnel (`FrenchCulinaryTranslator`)** :
  - Traduction transparente des aliments français vers l'anglais pour la recherche en ligne (ex: *poulet* -> *chicken*, *saumon* -> *salmon*, *haricots verts* -> *green beans*).
  - Traduction automatique en français de toutes les recettes : titres, catégories, origines culinaires, liste complète des ingrédients/mesures et étapes de préparation.
- **Affichage épuré Anti-Gaspi** : L'interface affiche uniquement l'intitulé « Recettes Anti-Gaspi », sans mentionner de nom de service tiers.
- **Déstockage en 1 clic** : Le bouton **« Cuisiner & Déstocker »** déduit automatiquement 1 quantité des ingrédients concernés dans l'inventaire du congélateur.
- **Fallback Hors-Ligne (`LocalRecipeEngine`)** : En cas d'absence de réseau, le moteur local génère des recettes anti-gaspi personnalisées basées sur le stock.

---

## 2. Trouveur d'Objet IA avec Verrouillage Visuel

- **Détection & Cadrage Complet du Produit** : L'algorithme (`expandToProductBoundingBox`) élargit la boîte englobante pour entourer **l'ensemble de l'emballage du produit**, et non seulement le bloc de texte isolé.
- **Verrouillage Persistant à l'Écran** : Dès la détection du produit cible, la vue capture l'image instantanée et **verrouille le rectangle vert sur le produit**, empêchant le cadre de bouger ou de disparaître même si l'utilisateur déplace la caméra. Un bouton « Rechercher à nouveau » permet de relancer la session.

---

## 3. Architecture Globale du Projet

- **`CongeoApp.swift`** : Point d'entrée de l'application, instanciation des `@StateObject` (`InventoryManager`, `LicenseManager`).
- **`ContentView.swift`** : 
  - `MainTabView` : Navigation à onglets principaux.
  - `InventoryView` : Gestion complète des aliments du congélateur, emplacements (Maison, Chalet, Bureau) et calcul de péremption.
  - `BulkScannerView` : Scan de codes-barres en rafale via `AVFoundation` et `OpenFoodFacts`.
  - `ObjectFinderView` : Détection, surlignage complet et verrouillage persistant sur flux caméra via Apple `Vision` (`VNRecognizeTextRequest`).
  - `HardwareView` : Connectivité réseau local avec la station caméra **ESP32-CAM Fisheye** (`http://[IP]:[PORT]/capture`).
  - `FamilySharingView` : Synchronisation multi-appareils et foyer via `NSUbiquitousKeyValueStore` (iCloud).
  - `SettingsView` : Gestion des licences d'achat unique (*Gratuite*, *Pro 4,99 $*, *Famille 9,99 $*).
- **`MealGeneratorView.swift`** :
  - `FrenchCulinaryTranslator` : Traduction automatique Français <-> Anglais.
  - `TheMealDBService` : Client réseau asynchrone TheMealDB.
  - `LocalRecipeEngine` : Moteur local de secours.
  - `MealGeneratorView` & `RecipeCardView` : Interface utilisateur SwiftUI réactive.
