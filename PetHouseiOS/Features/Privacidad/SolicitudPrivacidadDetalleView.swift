//
//  SolicitudPrivacidadDetalleView.swift
//  Features/Privacidad
//
//  Solo lectura: a diferencia del ticket de soporte, una solicitud de privacidad no es una
//  conversación — el usuario la envía una vez y el admin responde una vez, desde el panel.
//

import SwiftUI

struct SolicitudPrivacidadDetalleView: View {
    let solicitud: SolicitudPrivacidad

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s16) {
                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Tu mensaje")
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    Text(solicitud.mensaje)
                        .phText(PHFont.bodyMD, color: PHColor.ink)
                }
                .padding(PHSpacing.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PHColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Enviada el \(PHDate.displayFromTimestamp(solicitud.creadoEn))")
                    Text("Fecha límite estimada: \(PHDate.displayFromTimestamp(solicitud.venceEn)) (\(solicitud.plazoDias) días hábiles)")
                }
                .phText(PHFont.captionSM, color: PHColor.muted)

                if let respuesta = solicitud.respuesta, !respuesta.isEmpty {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text("Respuesta de PetHouse")
                            .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                        Text(respuesta)
                            .phText(PHFont.bodyMD, color: .white)
                    }
                    .padding(PHSpacing.s12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PHColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                } else {
                    Text("Todavía no hay respuesta. Te avisamos apenas la tengamos.")
                        .phText(PHFont.bodySM, color: PHColor.muted)
                        .padding(PHSpacing.s12)
                }
            }
            .padding(PHSpacing.s16)
        }
        .background(PHColor.canvas)
        .navigationTitle(solicitud.categoria.etiqueta)
        .navigationBarTitleDisplayMode(.inline)
    }
}
