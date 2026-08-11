//
//  BuscadorSheet.swift
//  Features/Search
//
//  Los 3 campos prominentes de la búsqueda (ver BuscarView): ciudad, fechas y
//  convivencia. Separado del "Filtros" avanzado (FiltrosView: tipo, orden, cerca de mí)
//  a propósito — mismo patrón que Airbnb: la barra principal es Dónde/Cuándo/Con quién,
//  todo lo demás es secundario.
//

import SwiftUI

struct BuscadorSheet: View {
    @Bindable var viewModel: BuscarViewModel
    let alBuscar: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Ciudad") {
                    TextField("¿A dónde va tu mascota?", text: $viewModel.ciudad)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Toggle("Elegir fechas", isOn: $viewModel.usarFechas.animation())
                    if viewModel.usarFechas {
                        DatePicker("Llegada", selection: $viewModel.desde, in: Date.now..., displayedComponents: .date)
                        DatePicker("Salida", selection: $viewModel.hasta, in: viewModel.desde..., displayedComponents: .date)
                    }
                } header: {
                    Text("Fechas")
                } footer: {
                    Text("Sin elegir fechas, se muestran todos los hospedajes disponibles ahora mismo.")
                }

                Section("¿Tu mascota puede compartir espacio?") {
                    Picker("Convivencia", selection: $viewModel.convivencia) {
                        Text("Cualquiera").tag(Convivencia?.none)
                        ForEach(Convivencia.allCases) { opcion in
                            Text(opcion.etiqueta).tag(Convivencia?.some(opcion))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Buscar hospedaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
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
