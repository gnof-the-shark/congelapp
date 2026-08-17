# Documentation Technique et Commerciale — Projet Congelo

## 1. Vue d'ensemble du projet

Congelo est un écosystème de gestion domestique qui combine :

- une application mobile iOS native (Swift/SwiftUI), compatible à partir d’iOS 16 ;
- un module matériel optionnel basé sur ESP32-CAM pour automatiser le suivi des stocks alimentaires.

L’objectif est de simplifier la gestion des aliments dans le congélateur, le réfrigérateur et le cellier, tout en réduisant le gaspillage.

## 2. Architecture de l’application iOS (logiciel)

### 2.1 Stack technique

- **Plateforme** : iOS 16+
- **Langage** : Swift
- **UI** : SwiftUI
- **IDE** : Xcode (environnement macOS, code hébergé via GitHub)

### 2.2 Modèle économique logiciel (achat unique à vie)

| Version | Prix | Fonctionnalités |
|---|---:|---|
| Gratuite | 0,00 $ | Inventaire limité (15–20 articles), 1 lieu de stockage, publicités légères |
| Pro | 4,99 $ | Inventaire illimité, 2 lieux (Maison + Chalet), 2 appareils max, localisateur visuel IA, zéro publicité |
| Famille | 9,99 $ | Inventaire illimité, lieux illimités, partage familial iCloud illimité, générateur de repas anti-gaspi complet, zéro publicité |

### 2.3 Fonctions à adopter

#### a) Scanner bulk (scan multiple)

- Permet de scanner plusieurs produits en une seule session.
- Récupère automatiquement les données produits depuis **OpenFoodFacts** (nom, marque, format, code-barres, etc.).
- Alimente l’inventaire sans saisie manuelle exhaustive.

#### b) Trouveur d’objet dans le frigo/congélo

- Utilise la caméra de l’iPhone pour observer le contenu réel.
- Compare la scène capturée avec les références visuelles disponibles (dont images OpenFoodFacts).
- Localise l’article recherché, l’encadre visuellement à l’écran et déclenche une vibration de confirmation.

## 3. Module matériel facultatif (Station ESP32-CAM)

### 3.1 Positionnement

Accessoire optionnel destiné aux utilisateurs qui veulent une automatisation avancée de la détection des mouvements et emplacements d’objets.

### 3.2 Composition du kit

- **Unité de traitement** : ESP32-CAM avec objectif ultra grand-angle (fisheye)
- **Circuiterie** : PCB sur mesure (alimentation régulée + connectique)
- **Boîtier** : coque ergonomique imprimée en 3D, fixation sur cadre de porte du congélateur

## 4. Modèle économique du kit matériel

### 4.1 Coût de revient unitaire estimé

| Composant / Étape | Coût estimé |
|---|---:|
| Module ESP32-CAM + caméra | ~ 6,00 $ |
| Fabrication PCB sur mesure | ~ 3,00 $ |
| Impression 3D du boîtier | ~ 4,00 $ |
| Frais de port / assemblage | ~ 2,00 $ |
| **Coût total** | **15,00 $** |

### 4.2 Prix de vente et marge

- **Marge cible** : +10,00 $
- **Prix public du kit** : 25,00 $

## 5. Plan de développement et déploiement

### Étape 1 — Environnement de travail

- Configuration de l’environnement de développement macOS / Xcode / GitHub.
- Développement de l’application en Swift/SwiftUI.

### Étape 2 — Prototypage et tests

- Tests de l’application sur différents appareils, y compris iOS 16 (compatibilité iPhone 8).
- Validation du design du boîtier 3D.
- Validation du routage et de la fabrication du PCB.

### Étape 3 — Lancement (objectif Noël)

- Souscription Apple Developer Program (99 $).
- Publication de l’application sur l’App Store.
- Mise en ligne de la boutique du kit matériel optionnel.

### Étape 4 — Exploitation

- Amortissement des coûts de développement via les ventes de licences logicielles.
- Maintien d’une marge nette fixe de 10 $ par kit matériel expédié.

## 6. Résultat attendu

Le projet Congelo vise un modèle hybride logiciel + matériel :

- un logiciel premium simple, rentable et sans abonnement ;
- un kit physique optionnel à marge maîtrisée ;
- des fonctions IA différenciantes (scan bulk + localisation visuelle d’objets) pour augmenter la valeur perçue.
