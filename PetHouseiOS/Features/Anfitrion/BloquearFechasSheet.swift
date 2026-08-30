//
//  BloquearFechasSheet.swift
//  Features/Anfitrion
//
//  Formulario para que el anfitrión bloquee un rango de fechas de un hospedaje propio, sin
//  necesidad de una reserva real (viaje, mantenimiento, etc.) — se abre desde
//  CalendarioHospedajeView. Reusa PHSelectorRangoFechas, el mismo componente del flujo de
//  reservar, para que elegir el rango se sienta igual en los dos lugares. `viewModel` es el
//  mismo objeto (`@Observable`, tipo referencia) que ya tiene CalendarioHospedajeView, así
//  que bloquear acá se refleja solo en su calendario al cerrar este sheet.
//

import SwiftUI

struct BloquearFechasSheet: View {
    let viewModel: CalendarioHospedajeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var desde = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var hasta = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
    @State private var motivo = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s16) {
                    Text("Estas fechas dejan de estar disponibles para reservar — no hace falta pausar todo el hospedaje.")
                        .phText(PHFont.captionSM, color: PHColor.muted)

                    PHSelectorRangoFechas(desde: $desde, hasta: $hasta, diaOcupado: { viewModel.diaOcupado($0) })

                    PHTextField(
                        label: "Motivo (opcional)",
                        placeholder: "Ej. viaje, mantenimiento…",
                        text: $motivo
                    )

                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                            .phText(PHFont.bodySM, color: PHColor.error)
                    }

                    PHPrimaryButton("Bloquear estas fechas", isLoading: viewModel.bloqueando) {
                        Task {
                            let exito = await viewModel.bloquear(desde: desde, hasta: hasta, motivo: motivo)
                            if exito { dismiss() }
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
            .navigationTitle("Bloquear fechas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }
}
