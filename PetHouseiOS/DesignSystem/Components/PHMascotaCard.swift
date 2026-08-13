//
//  PHMascotaCard.swift
//  DesignSystem/Components
//

import SwiftUI

public struct PHMascotaCard: View {
    let mascota: Mascota
    let onEditar: (() -> Void)?
    let onEliminar: (() -> Void)?

    public init(_ mascota: Mascota, onEditar: (() -> Void)? = nil, onEliminar: (() -> Void)? = nil) {
        self.mascota = mascota
        self.onEditar = onEditar
        self.onEliminar = onEliminar
    }

    public var body: some View {
        HStack(spacing: PHSpacing.s12) {
            Group {
                if let primeraFoto = mascota.fotos.first {
                    PHCachedAsyncImage(urlString: MediaURL.resolver(primeraFoto)) {
                        Circle().fill(PHColor.primaryContainer)
                    }
                    .clipShape(Circle())
                } else {
                    ZStack {
                        Circle().fill(PHColor.primaryContainer)
                        Image(systemName: iconoPara(mascota.especie))
                            .foregroundStyle(PHColor.onPrimaryContainer)
                    }
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(mascota.nombre)
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Text(subtitulo)
                    .phText(PHFont.captionSM, color: PHColor.muted)
                HStack(spacing: PHSpacing.s4) {
                    if mascota.vacunasDia {
                        PHBadge("Vacunas al día", style: .success)
                    }
                    if mascota.necesitaMedicamentos {
                        PHBadge("Necesita medicamentos", style: .warning)
                    }
                }
            }

            Spacer()

            if let onEditar {
                PHIconButton(systemImage: "pencil", accessibilityLabel: "Editar \(mascota.nombre)", action: onEditar)
            }
            if let onEliminar {
                PHIconButton(systemImage: "trash", accessibilityLabel: "Eliminar \(mascota.nombre)", action: onEliminar)
            }
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private var subtitulo: String {
        var partes = [mascota.especie.capitalized]
        if let raza = mascota.raza, !raza.isEmpty { partes.append(raza) }
        if let edad = mascota.edad { partes.append("\(edad) año\(edad == 1 ? "" : "s")") }
        if let tamanoLegible = mascota.tamanoLegible { partes.append(tamanoLegible) }
        if let peso = mascota.pesoKg { partes.append(String(format: "%.1f kg", peso)) }
        return partes.joined(separator: " · ")
    }

    private func iconoPara(_ especie: String) -> String {
        switch especie.lowercased() {
        case "perro": "pawprint.fill"
        case "gato": "cat.fill"
        default: "pawprint"
        }
    }
}
