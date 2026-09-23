//
//  SelectorConvivenciaSheet.swift
//  Features/Search
//
//  Entrada directa desde la fila "¿Comparte con otras mascotas?" de BuscarView — SOLO
//  las opciones de convivencia (ver Core/Models/Hospedaje.swift → Convivencia), sin
//  pasar por un formulario con más campos. Elegir una busca de una vez y cierra.
//
//  "Cualquiera" se guarda como `nil` (no como `Convivencia.cualquiera`) para que
//  `BuscarViewModel.hayBusquedaActiva` siga significando "hay un filtro real elegido" —
//  mismo criterio que ya usaba el formulario anterior.
//

import SwiftUI

struct SelectorConvivenciaSheet: View {
    @Bindable var viewModel: BuscarViewModel
    let alConfirmar: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                fila(etiqueta: "Cualquiera", seleccionado: viewModel.convivencia == nil) {
                    viewModel.convivencia = nil
                }
                ForEach(Convivencia.allCases.filter { $0 != .cualquiera }) { opcion in
                    fila(etiqueta: opcion.etiqueta, seleccionado: viewModel.convivencia == opcion) {
                        viewModel.convivencia = opcion
                    }
                }
            }
            .navigationTitle("¿Comparte con otras mascotas?")
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
