//
//  BloquearFechasSheet.swift
//  Features/Anfitrion
//
//  Formulario para que el anfitrión bloquee un rango de fechas de un hospedaje propio, sin
//  necesidad de una reserva real (viaje, mantenimiento, etc.). Se abre desde dos lugares —
//  HospedajeDetailView (opción visible apenas se entra al hospedaje) y CalendarioHospedajeView
//  (ícono en el toolbar) — por eso solo depende de `Hospedaje` y de `HospedajesServicing`, no
//  de ningún ViewModel de pantalla en particular. Reusa PHSelectorRangoFechas, el mismo
//  componente del flujo de reservar, para que elegir el rango se sienta igual en los dos
//  lugares; `diaOcupado` sale de GET /disponibilidad, que ya une reservas reales y bloqueos
//  existentes (ver db/34-fechas-bloqueadas.sql).
//

import SwiftUI

struct BloquearFechasSheet: View {
    let hospedaje: Hospedaje
    /// Se llama tras bloquear con éxito — quien presenta este sheet lo usa para refrescar su
    /// propia lista/calendario sin esperar a que se recargue solo.
    var alBloquear: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var service: HospedajesServicing = HospedajesService()

    @State private var cargandoDisponibilidad = true
    @State private var diasOcupados: Set<String> = []
    @State private var desde = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var hasta = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
    @State private var motivo = ""
    @State private var enviando = false
    @State private var error: AppError?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s16) {
                    Text("Estas fechas dejan de estar disponibles para reservar — no hace falta pausar todo el hospedaje.")
                        .phText(PHFont.captionSM, color: PHColor.muted)

                    if cargandoDisponibilidad {
                        PHLoadingStateView(mensaje: "Cargando calendario…")
                    } else {
                        PHSelectorRangoFechas(
                            desde: $desde, hasta: $hasta,
                            diaOcupado: { diasOcupados.contains(PHDate.toAPIDateOnly($0)) }
                        )

                        PHTextField(
                            label: "Motivo (opcional)",
                            placeholder: "Ej. viaje, mantenimiento…",
                            text: $motivo
                        )

                        if let error {
                            Text(error.localizedDescription)
                                .phText(PHFont.bodySM, color: PHColor.error)
                        }

                        PHPrimaryButton("Bloquear estas fechas", isLoading: enviando) {
                            Task { await bloquear() }
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
            .task { await cargarDisponibilidad() }
        }
    }

    private func cargarDisponibilidad() async {
        cargandoDisponibilidad = true
        defer { cargandoDisponibilidad = false }
        guard let rangos = try? await service.disponibilidad(hospedajeId: hospedaje.id) else { return }
        diasOcupados = rangos.diasOcupados()
    }

    private func bloquear() async {
        enviando = true
        defer { enviando = false }
        do {
            _ = try await service.bloquearFechas(
                hospedajeId: hospedaje.id,
                desde: PHDate.toAPIDateOnly(desde),
                hasta: PHDate.toAPIDateOnly(hasta),
                motivo: motivo.isEmpty ? nil : motivo
            )
            alBloquear?()
            dismiss()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
