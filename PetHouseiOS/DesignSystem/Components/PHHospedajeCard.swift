//
//  PHHospedajeCard.swift
//  DesignSystem/Components
//
//  Card de hospedaje para listados (búsqueda, favoritos, mis hospedajes). Tolera los
//  campos que pueden venir en `nil` según el endpoint de origen (ver Hospedaje.swift):
//  si viene de `/cerca`, no hay foto ni servicios, así que la card degrada con calma.
//

import SwiftUI

public struct PHHospedajeCard: View {
    let hospedaje: Hospedaje
    let esFavorito: Bool
    let onToggleFavorito: (() -> Void)?

    public init(_ hospedaje: Hospedaje, esFavorito: Bool = false, onToggleFavorito: (() -> Void)? = nil) {
        self.hospedaje = hospedaje
        self.esFavorito = esFavorito
        self.onToggleFavorito = onToggleFavorito
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            ZStack(alignment: .topTrailing) {
                PHCachedAsyncImage(urlString: MediaURL.resolver(hospedaje.fotos?.first), ladoMaximoPt: 400) {
                    Rectangle()
                        .fill(PHColor.surfaceStrong)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(PHColor.mutedSoft)
                        )
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

                if let onToggleFavorito {
                    PHIconButton(
                        systemImage: esFavorito ? "heart.fill" : "heart",
                        accessibilityLabel: esFavorito ? "Quitar de favoritos" : "Agregar a favoritos",
                        action: onToggleFavorito
                    )
                    .padding(PHSpacing.s8)
                }
            }

            HStack {
                Text(hospedaje.titulo)
                    .phText(PHFont.titleMD, color: PHColor.ink)
                    .lineLimit(1)
                Spacer()
                PHStarRatingDisplay(rating: hospedaje.rating, numResenas: hospedaje.numResenas)
            }

            Text(lugarTexto)
                .phText(PHFont.bodySM, color: PHColor.muted)
                .lineLimit(1)

            HStack {
                Text(PHFormato.precio(hospedaje.precioNoche))
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text("/ noche")
                    .phText(PHFont.captionSM, color: PHColor.muted)
                Spacer()
                PHBadge(hospedaje.tipo.etiqueta)
            }
        }
        .padding(PHSpacing.s12)
        .background(PHColor.canvas)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
        .phShadow(PHShadow.level1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hospedaje.titulo), \(hospedaje.tipo.etiqueta), \(lugarTexto), \(PHFormato.precio(hospedaje.precioNoche)) por noche")
    }

    // Prefiere `localidad` sobre `ciudad`: con la app restringida a Bogotá, `ciudad` es
    // siempre "Bogotá" — no dice nada útil sobre dónde queda el hospedaje. `localidad` cae
    // a `ciudad` solo para hospedajes viejos del seed que quedaron sin localidad asignada.
    private var lugarTexto: String {
        if let distancia = hospedaje.distanciaM {
            let km = distancia / 1000
            return String(format: "%@ · a %.1f km", hospedaje.localidad ?? hospedaje.ciudad, km)
        }
        if let barrio = hospedaje.barrio, !barrio.isEmpty, let localidad = hospedaje.localidad {
            return "\(barrio), \(localidad)"
        }
        return hospedaje.localidad ?? hospedaje.ciudad
    }
}
