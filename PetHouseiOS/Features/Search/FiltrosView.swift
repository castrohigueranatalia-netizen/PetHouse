//
//  FiltrosView.swift
//  Features/Search
//
//  Filtros SECUNDARIOS: palabra clave, tipo de hospedaje, orden y "cerca de mí" (lat/lng
//  vía `LocationProvider`). Localidad, fechas y convivencia son los 3 campos PRIMARIOS y
//  viven en `BuscadorSheet` (la barra de búsqueda principal, ver BuscarView) — a propósito
//  no se repiten aquí, para no tener el mismo dato editable en dos lugares distintos.
//

import SwiftUI

struct FiltrosView: View {
    @Bindable var viewModel: BuscarViewModel
    let alAplicar: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Palabra clave") {
                    TextField("Ej. piscina, patio, guardería…", text: $viewModel.textoLibre)
                        .textInputAutocapitalization(.never)
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
