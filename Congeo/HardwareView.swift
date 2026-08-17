import SwiftUI

struct HardwareView: View {
    @State private var isConnected = false
    @State private var streamURL = "http://192.168.1.50/stream"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Station ESP32-CAM (Matériel Optionnel)")) {
                    TextField("Adresse IP du module", text: $streamURL)
                    Toggle("Activer le flux vidéo", isOn: $isConnected)
                }
                
                Section(header: Text("Aperçu de la caméra (Fisheye)")) {
                    if isConnected {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 220)
                            .overlay(
                                Text("🔴 Flux direct ESP32-CAM actif\n(Porte du congélateur)")
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            )
                            .cornerRadius(8)
                    } else {
                        Text("Module déconnecté ou en veille.")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Informations du Kit")) {
                    Text("Coût de revient estimé : 15,00 $")
                    Text("Prix public conseillé : 25,00 $ (Marge fixe : 10 $)")
                }
            }
            .navigationTitle("Boîtier Matériel")
        }
    }
}
