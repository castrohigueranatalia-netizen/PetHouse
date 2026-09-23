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
    /// `true` cuando se está mostrando en una búsqueda "Por día" (ver
    /// `BuscarViewModel.busquedaMismoDia`) — muestra `precioDia` en vez de `precioNoche`,
    /// que es el que de verdad aplica ahí. Si por alguna razón `precioDia` viniera vacío
    /// (no debería pasar: el servidor ya filtra a hospedajes que sí lo tienen), cae al
    /// precio de noche en vez de mostrar un espacio vacío.
    let mostrarPrecioDia: Bool

    public init(
        _ hospedaje: Hospedaje, esFavorito: Bool = false, mostrarPrecioDia: Bool = false,
        onToggleFavorito: (() -> Void)? = nil
    ) {
        self.hospedaje = hospedaje
        self.esFavorito = esFavorito
        self.mostrarPrecioDia = mostrarPrecioDia
        self.onToggleFavorito = onToggleFavorito
    }

    private var precioMostrado: Double {
        mostrarPrecioDia ? (hospedaje.precioDia ?? hospedaje.precioNoche) : hospedaje.precioNoche
    }

    private var unidadMostrada: String {
        mostrarPrecioDia && hospedaje.precioDia != nil ? "/ día" : "/ noche"
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
                // Pausado: la foto se ve en gris, no solo más tenue — para que sea notorio
                // de un vistazo (no hay que leer el badge para darse cuenta).
                .grayscale(hospedaje.activo == false ? 1 : 0)
                .opacity(hospedaje.activo == false ? 0.7 : 1)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

                if hospedaje.activo == false {
                    PHBadge("Pausado", style: .warning)
                        .padding(PHSpacing.s8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

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
                Text(PHFormato.precio(precioMostrado))
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text(unidadMostrada)
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
        .accessibilityLabel("\(hospedaje.titulo), \(hospedaje.tipo.etiqueta), \(lugarTexto), \(PHFormato.precio(precioMostrado)) \(unidadMostrada)")
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
