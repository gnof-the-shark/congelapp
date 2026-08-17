import SwiftUI

struct MealGeneratorView: View {
    @State private var generatedMeal: String = "Appuie sur le bouton pour générer une recette anti-gaspi !"
    @State private var isGenerating: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🍽️ Chef Congelo")
                    .font(.largeTitle)
                    .bold()
                
                Text("Génère une recette instantanée basée sur les ingrédients de ton stock pour éviter le gaspillage.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .shadow(radius: 2)
                    
                    if isGenerating {
                        ProgressView("Cuisinage en cours...")
                    } else {
                        Text(generatedMeal)
                            .padding()
                            .multilineTextAlignment(.center)
                            .font(.body)
                    }
                }
                .frame(height: 250)
                .padding(.horizontal)

                Spacer()

                Button(action: generateMeal) {
                    Label("Générer un repas", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }

    func generateMeal() {
        isGenerating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let recipes = [
                "Gratin de steaks hachés aux légumes du jardin avec une croûte de fromage fondu.",
                "Pains burger façon panini express toastés avec les restes du congélateur.",
                "Poêlée rapide de légumes et bouchées croustillantes."
            ]
            generatedMeal = recipes.randomElement() ?? "Recette surprise !"
            isGenerating = false
        }
    }
}

struct MealGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        MealGeneratorView()
    }
}
