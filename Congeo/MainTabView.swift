import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventaire", systemImage: "snowflake")
                }
            
            MealGeneratorView()
                .tabItem {
                    Label("Recettes", systemImage: "fork.knife")
                }
            
            HardwareView()
                .tabItem {
                    Label("Caméra ESP32", systemImage: "camera.viewfinder")
                }
            
            SettingsView()
                .tabItem {
                    Label("Licence & Réglages", systemImage: "gear")
                }
        }
    }
}
