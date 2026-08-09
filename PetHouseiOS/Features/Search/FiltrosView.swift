//
//  FiltrosView.swift
//  Features/Search
//
//  Hoja modal con los filtros que soporta `GET /api/hospedajes` hoy: ciudad, tipo,
//  convivencia, orden y "cerca de mí" (lat/lng vía `LocationProvider`). Fechas
//  (`desde`/`hasta`) también son soportadas por el backend pero se dejan fuera de este
//  filtro rápido — se usan directamente en el flujo de reserva, donde importan más.
//

import SwiftUI

struct FiltrosView: View {
    @Bindable var viewModel: BuscarViewModel
    let alAplicar: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Ciudad") {
                    TextField("Ej. Bogotá", text: $viewModel.ciudad)
                        .textInputAutocapitalization(.words)
                }

                Section("Tipo de hospedaje") {
                    Picker("Tipo", selection: $viewModel.tipo) {
                        Text("Cualquiera").tag(TipoHospedaje?.none)
                        ForEach(TipoHospedaje.allCases) { tipo in
                            Text(tipo.etiqueta).tag(TipoHospedaje?.some(tipo))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Convivencia") {
                    Picker("Convivencia", selection: $viewModel.convivencia) {
                        Text("Cualquiera").tag(Convivencia?.none)
                        ForEach(Convivencia.allCases) { opcion in
                            Text(opcion.etiqueta).tag(Convivencia?.some(opcion))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Orden") {
                    Picker("Orden", selection: $viewModel.orden) {
                        ForEach(BuscarViewModel.Orden.allCases) { orden in
                            Text(orden.etiqueta).tag(orden)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Toggle("Buscar cerca de mí", isOn: $viewModel.cercaDeMi)
                } footer: {
                    Text("Se te pedirá permiso de ubicación solo si activas esta opción.")
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Limpiar") { viewModel.limpiarFiltros() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHTextButton("Aplicar") {
                        alAplicar()
                        dismiss()
                    }
                }
            }
        }
    }
}
