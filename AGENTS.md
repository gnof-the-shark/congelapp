# Congélo — Directives Agents & Documentation Technique

Ce projet est une application iOS native en **Swift / SwiftUI** conçue pour la gestion intelligente du congélateur, la détection par IA, l'anti-gaspillage alimentaire et la recommandation culinaire.

---

## 1. Moteur de Recettes Anti-Gaspi

Le module **Recettes Anti-Gaspi** propose automatiquement des repas équilibrés en utilisant les aliments actuellement présents dans le congélateur (priorisation des dates courtes).

### Fonctionnalités Clés :
- **Génération automatique d'idées** : Interroge la base culinaire en ligne via TheMealDB (`https://www.themealdb.com/api.php`) à partir des aliments réels du congélateur.
- **Moteur de traduction bidirectionnel (`FrenchCulinaryTranslator`)** :
  - Traduction transparente des aliments français vers l'anglais pour la recherche en ligne (ex: *poulet* -> *chicken*, *saumon* -> *salmon*, *haricots verts* -> *green beans*, *yogourt* -> *yogurt*).
  - Traduction automatique en français de toutes les recettes : titres, catégories, origines culinaires, liste complète des ingrédients/mesures et étapes de préparation.
- **Affichage épuré Anti-Gaspi** : L'interface affiche uniquement l'intitulé « Recettes Anti-Gaspi », sans mentionner de nom de service tiers.
- **Déstockage en 1 clic** : Le bouton **« Cuisiner & Déstocker »** déduit automatiquement 1 quantité des ingrédients concernés dans l'inventaire du congélateur.
- **Génération Culinaire Contextuelle Réaliste (`LocalRecipeEngine`)** : 
  - Analyse fine de la nature de chaque ingrédient (laitiers, yaourts, viandes, poissons, fruits, légumes, pain, féculents).
  - Génère des recettes parfaitement adaptées au profil culinaire : par exemple, le yogourt / skyr propose des gâteaux moelleux, coupes fraîches au miel ou tzatziki aux herbes (jamais de cuisson inadaptée à la poêle).

---

## 2. Trouveur d'Objet IA avec Suivi Visuel en Direct (Live Tracking)

- **Flux Caméra Continu & Suivi en Direct** : Après la détection du produit, la caméra reste active et le rectangle vert se déplace en temps réel pour suivre le produit dans le congélateur.
- **Détection & Cadrage Précis du Contour** : L'algorithme (`expandToProductBoundingBox`) regroupe les zones de texte connexes du paquet et applique un lissage exponentiel (EMA) pour un contouring stable et fluide de l'ensemble de l'emballage.
- **Persistance & Tolérance aux Mouvements** : Maintient le cadrage vert lors des légers mouvements et flous de bougé.

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
