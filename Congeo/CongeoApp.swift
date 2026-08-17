import SwiftUI

@main
struct CongeloApp: App {
    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var inventoryManager = InventoryManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(licenseManager)
                .environmentObject(inventoryManager)
        }
    }
}
