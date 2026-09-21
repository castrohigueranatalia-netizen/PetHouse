//
//  SelectorLocalidadSheet.swift
//  Features/Search
//
//  Entrada directa desde la fila "Dónde" de BuscarView — SOLO la lista de las 20
//  localidades de Bogotá (ver Core/Models/Localidad.swift) más "Toda Bogotá", sin pasar
//  por un formulario con más campos. Elegir una busca de una vez y cierra.
//

import SwiftUI

struct SelectorLocalidadSheet: View {
    @Bindable var viewModel: BuscarViewModel
    let alConfirmar: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                fila(etiqueta: "Toda Bogotá", seleccionado: viewModel.localidad == nil) {
                    viewModel.localidad = nil
                }
                ForEach(Localidad.allCases) { localidad in
                    fila(etiqueta: localidad.etiqueta, seleccionado: viewModel.localidad == localidad) {
                        viewModel.localidad = localidad
                    }
                }
            }
            .navigationTitle("Dónde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func fila(etiqueta: String, seleccionado: Bool, elegir: @escaping () -> Void) -> some View {
        Button {
            elegir()
            alConfirmar()
            dismiss()
        } label: {
            HStack {
                Text(etiqueta).phText(PHFont.bodyMD, color: PHColor.ink)
                Spacer()
                if seleccionado {
                    Image(systemName: "checkmark")
                        .foregroundStyle(PHColor.primary)
                }
            }
        }
    }
}
