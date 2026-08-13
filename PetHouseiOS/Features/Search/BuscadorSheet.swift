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

                    Toggle("Elegir fechas", isOn: $viewModel.usarFechas.animation())
                    if viewModel.usarFechas {
                        DatePicker("Llegada", selection: $viewModel.desde, in: Date.now..., displayedComponents: .date)
                        DatePicker("Salida", selection: $viewModel.hasta, in: viewModel.desde..., displayedComponents: .date)
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
    }
}
