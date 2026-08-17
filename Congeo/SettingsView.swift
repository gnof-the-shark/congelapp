import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var license: LicenseManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Licence Actuelle")) {
                    Text("Formule : \(license.currentTier.rawValue)")
                        .bold()
                }
                
                Section(header: Text("Modifier la Licence (Achat Unique)")) {
                    Button("Passer à la Version Gratuite (0 $)") {
                        license.upgrade(to: .free)
                    }
                    Button("Acheter la Version Pro (4,99 $)") {
                        license.upgrade(to: .pro)
                    }
                    Button("Acheter la Version Famille (9,99 $)") {
                        license.upgrade(to: .family)
                    }
                }
                
                Section(header: Text("À propos")) {
                    Text("Congelo - Écosystème de gestion domestique intelligent.")
                    Text("Compatible iOS 16 et supérieur.")
                }
            }
            .navigationTitle("Réglages & Licences")
        }
    }
}
