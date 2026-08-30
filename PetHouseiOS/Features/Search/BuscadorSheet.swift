//
//  BuscadorSheet.swift
//  Features/Search
//
//  Los 3 campos prominentes de la búsqueda (ver BuscarView): localidad, fechas y
//  convivencia. Separado del "Filtros" avanzado (FiltrosView: tipo, orden, cerca de mí)
//  a propósito — mismo patrón que Airbnb: la barra principal es Dónde/Cuándo/Con quién,
//  todo lo demás es secundario. "Dónde" es un Picker de localidad, no texto libre — la
//  app es solo de Bogotá, segmentada por sus 20 localidades (ver Localidad.swift).
//
//  Los 3 campos viven en UNA sola sección (no tres separadas) para que se sientan parte
//  de una misma selección — Localidad y Convivencia colapsan a una fila cada una
//  (`.navigationLink`, igual que FiltrosView) en vez de desplegar la lista completa ahí
//  mismo, así entran los 3 sin que la hoja se sienta como tres formularios distintos.
//

import SwiftUI

struct BuscadorSheet: View {
    @Bindable var viewModel: BuscarViewModel
    let alBuscar: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// Estado local, no del ViewModel — solo decide qué modo del selector mostrar mientras
    /// esta hoja está abierta. `.onAppear` lo inicializa según `desde`/`hasta` actuales, para
    /// que reabrir la hoja no "olvide" que se estaba buscando un solo día.
    @State private var mismoDia = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Localidad", selection: $viewModel.localidad) {
                        Text("Toda Bogotá").tag(Localidad?.none)
                        ForEach(Localidad.allCases) { localidad in
                            Text(localidad.etiqueta).tag(Localidad?.some(localidad))
                        }
                    }
                    .pickerStyle(.navigationLink)

                    // Fila "Fechas" con un "+" en vez de un switch — más liviano y directo:
                    // tocar el "+" abre el calendario de una, sin la animación del Toggle
                    // (`.animation()` sobre `isOn`) que hacía sentir la apertura lenta.
                    Button {
                        viewModel.usarFechas.toggle()
                    } label: {
                        HStack {
                            Text("Fechas").phText(PHFont.bodyMD, color: PHColor.ink)
                            Spacer()
                            Image(systemName: viewModel.usarFechas ? "xmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(viewModel.usarFechas ? PHColor.mutedSoft : PHColor.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    if viewModel.usarFechas {
                        Picker("Tipo de búsqueda", selection: $mismoDia) {
                            Text("Por noches").tag(false)
                            Text("Mismo día").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mismoDia) { _, nuevo in
                            if nuevo { viewModel.hasta = viewModel.desde }
                            else if viewModel.hasta <= viewModel.desde {
                                viewModel.hasta = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.desde) ?? viewModel.desde
                            }
                        }

                        // Un solo calendario para llegada y salida — tocar un día fija la
                        // llegada y pasa de una a pedir la salida, sin tener que abrir un
                        // segundo selector aparte (mismo componente que ya usa Reservar).
                        PHSelectorRangoFechas(
                            desde: $viewModel.desde, hasta: $viewModel.hasta,
                            soloUnDia: mismoDia, diaOcupado: { _ in false }
                        )

                        if mismoDia {
                            // Ver db/35-reserva-mismo-dia.sql — el servidor ya solo devuelve
                            // hospedajes que ofrezcan esa modalidad.
                            Text("Con \"Mismo día\", solo se muestran hospedajes que ofrecen reservas de un solo día.")
                                .phText(PHFont.captionSM, color: PHColor.muted)
                        }
                    }

                    Picker("¿Comparte espacio con otras mascotas?", selection: $viewModel.convivencia) {
                        Text("Cualquiera").tag(Convivencia?.none)
                        ForEach(Convivencia.allCases) { opcion in
                            Text(opcion.etiqueta).tag(Convivencia?.some(opcion))
                        }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("Sin elegir fechas, se muestran todos los hospedajes disponibles ahora mismo.")
                }
            }
            .navigationTitle("Buscar hospedaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // "Quitar selección": vuelve localidad/fechas/convivencia (y el resto de
                    // filtros) a como estaban antes de tocar nada, y re-busca de una vez —
                    // mismo botón que aparece junto a la barra de búsqueda en BuscarView
                    // cuando hay algo elegido, pero accesible también desde acá dentro.
                    PHTextButton("Limpiar", role: .destructive) {
                        viewModel.limpiarFiltros()
                        alBuscar()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PHPrimaryButton("Buscar", systemImage: "magnifyingglass") {
                    alBuscar()
                    dismiss()
                }
                .padding(PHSpacing.s16)
                .background(.bar)
            }
        }
        .onAppear {
            mismoDia = Calendar.current.isDate(viewModel.desde, inSameDayAs: viewModel.hasta)
        }
    }
}
