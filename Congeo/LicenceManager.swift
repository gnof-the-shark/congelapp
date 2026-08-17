import Foundation

enum AppTier: String, CaseIterable, Identifiable {
    case free = "Gratuite (0 $)"
    case pro = "Pro (4,99 $)"
    case family = "Famille (9,99 $)"
    
    var id: String { self.rawValue }
    
    var maxItems: Int {
        switch self {
        case .free: return 20
        case .pro, .family: return Int.max
        }
    }
    
    var maxLocations: Int {
        switch self {
        case .free: return 1
        case .pro: return 2
        case .family: return Int.max
        }
    }
    
    var hasAILocator: Bool {
        switch self {
        case .free: return false
        case .pro, .family: return true
        }
    }
    
    var hasAntiWasteRecipeGenerator: Bool {
        switch self {
        case .free, .pro: return false
        case .family: return true
        }
    }
    
    var hasAds: Bool {
        switch self {
        case .free: return true
        case .pro, .family: return false
        }
    }
}

class LicenseManager: ObservableObject {
    @Published var currentTier: AppTier = .free
    
    func upgrade(to tier: AppTier) {
        currentTier = tier
    }
}
