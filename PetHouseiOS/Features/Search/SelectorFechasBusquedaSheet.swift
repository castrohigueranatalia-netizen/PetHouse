//
//  SelectorFechasBusquedaSheet.swift
//  Features/Search
//
//  Entrada directa desde la fila "Fechas" de BuscarView — tocarla abre este calendario de
//  una, sin pasar por un formulario combinado con los otros campos. Extraído de lo que
//  antes era un sheet interno de BuscadorSheet.swift (ese archivo ya no existe — cada
//  campo de la barra de búsqueda tiene ahora su propio selector directo).
//
//  Mismo componente de calendario (PHSelectorRangoFechas) que ya usan Reservar y el resto
//  de selectores de fecha de la app.
//

import SwiftUI

struct SelectorFechasBusquedaSheet: View {
    @Bindable var viewModel: BuscarViewModel
    let alConfirmar: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mismoDia = false
    /// Solo importa en modo "Por noches": el primer toque en el calendario deja una salida
    /// TENTATIVA (al día siguiente de la llegada) para que se vea el rango mientras se
    /// elige — pero eso no es lo mismo que haya tocado de verdad cuándo se va. `false` hasta
    /// que confirma la salida con un segundo toque (ver `PHSelectorRangoFechas.onCambio`);
    /// en "Mismo día" un solo toque ya es suficiente.
    @State private var faltaSalida = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s16) {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text("¿Cómo quieres buscar?")
                            .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)

                        Picker("Tipo de búsqueda", selection: $mismoDia) {
                            Text("Por noches").tag(false)
                            Text("Por día").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mismoDia) { _, nuevo in
                            if nuevo { viewModel.hasta = viewModel.desde }
                            else if viewModel.hasta <= viewModel.desde {
                                viewModel.hasta = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.desde) ?? viewModel.desde
                            }
                            faltaSalida = false
                        }

                        // Solo la aclaración de la opción elegida — cada una explica tanto
                        // el concepto como cómo se elige la fecha en el calendario de abajo.
                        Text(
                            mismoDia
                                ? "Por día: eliges una sola fecha — la dejas y la recoges ese mismo día, sin pasar la noche."
                                : "Por noches: eliges llegada y salida — tu mascota se queda a dormir esas noches."
                        )
                        .phText(PHFont.captionSM, color: PHColor.muted)
                    }

                    // Un solo calendario para llegada y salida — tocar un día fija la
                    // llegada y pasa de una a pedir la salida, sin abrir un segundo
                    // selector aparte (mismo componente que ya usa Reservar).
                    PHSelectorRangoFechas(
                        desde: $viewModel.desde, hasta: $viewModel.hasta,
                        soloUnDia: mismoDia, onCambio: { completo in faltaSalida = !completo },
                        diaOcupado: { _ in false }
                    )

                    if !mismoDia && faltaSalida {
                        Text("Falta elegir la fecha de salida — toca otro día para confirmarla.")
                            .phText(PHFont.captionSM, color: PHColor.error)
                    }

                    if mismoDia {
                        // Ver db/35-reserva-mismo-dia.sql — el servidor ya solo devuelve
                        // hospedajes que ofrezcan esa modalidad.
                        Text("Con \"Por día\", solo se muestran hospedajes que ofrecen reservas de un solo día.")
                            .phText(PHFont.captionSM, color: PHColor.muted)
                    }
                }
                .padding(PHSpacing.s16)
            }
            .navigationTitle("Elegir fechas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Solo si ya había fechas elegidas — vuelve a "cualquier fecha" sin tener
                // que elegir un rango primero para poder quitarlo.
                if viewModel.usarFechas {
                    ToolbarItem(placement: .topBarLeading) {
                        PHTextButton("Quitar fechas", role: .destructive) {
                            viewModel.usarFechas = false
                            alConfirmar()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHTextButton("Listo") {
                        viewModel.usarFechas = true
                        alConfirmar()
                        dismiss()
                    }
                    .disabled(!mismoDia && faltaSalida)
                }
            }
        }
        .onAppear {
            mismoDia = Calendar.current.isDate(viewModel.desde, inSameDayAs: viewModel.hasta)
        }
    }
}
