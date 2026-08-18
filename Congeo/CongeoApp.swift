import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
#else
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        return true
    }
}
#endif

@main
struct CongeoApp: App {
    // Enregistrement de l'AppDelegate pour la configuration Firebase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var groceryManager = GroceryListManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(licenseManager)
                .environmentObject(inventoryManager)
                .environmentObject(groceryManager)
        }
    }
}
