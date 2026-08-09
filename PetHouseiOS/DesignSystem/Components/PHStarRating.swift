//
//  PHStarRating.swift
//  DesignSystem/Components
//

import SwiftUI

/// Rating de solo lectura (ej. rating promedio de un hospedaje en su card).
public struct PHStarRatingDisplay: View {
    let rating: Double
    let numResenas: Int?

    public init(rating: Double, numResenas: Int? = nil) {
        self.rating = rating
        self.numResenas = numResenas
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(PHColor.primary)
                .font(.caption)
            Text(String(format: "%.1f", rating))
                .phText(PHFont.captionSM.weight(.semibold), color: PHColor.ink)
            if let numResenas {
                Text("(\(numResenas))")
                    .phText(PHFont.micro, color: PHColor.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accesibilidadTexto)
    }

    private var accesibilidadTexto: String {
        let base = String(format: "%.1f de 5 estrellas", rating)
        if let numResenas {
            return "\(base), \(numResenas) reseñas"
        }
        return base
    }
}

/// Selector de estrellas interactivo (1-5) — usado en el formulario de reseñas.
public struct PHStarRatingInput: View {
    @Binding var rating: Int
    let maximo: Int

    public init(rating: Binding<Int>, maximo: Int = 5) {
        self._rating = rating
        self.maximo = maximo
    }

    public var body: some View {
        HStack(spacing: PHSpacing.s8) {
            ForEach(1...maximo, id: \.self) { valor in
                Button {
                    rating = valor
                } label: {
                    Image(systemName: valor <= rating ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(valor <= rating ? PHColor.primary : PHColor.hairline)
                }
                .accessibilityLabel("\(valor) \(valor == 1 ? "estrella" : "estrellas")")
                .accessibilityAddTraits(valor == rating ? [.isSelected] : [])
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack(spacing: 20) {
        PHStarRatingDisplay(rating: 4.8, numResenas: 132)
        PHStarRatingInput(rating: .constant(3))
    }
    .padding()
}
