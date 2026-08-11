//
//  PreferenciasAnfitrionView.swift
//  Features/Anfitrion
//
//  Paso 2 (último) de "Conviértete en anfitrión". Al enviar, cierra todo el flujo y vuelve
//  al Perfil — la pestaña Anfitrión ya está disponible desde el paso 1.
//

import SwiftUI

struct PreferenciasAnfitrionView: View {
    @State private var viewModel = PreferenciasAnfitrionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s24) {
                VStack(alignment: .leading, spacing: PHSpacing.s8) {
                    Text("¿Qué prefieres cuidar?")
                        .phText(PHFont.displayMD, color: PHColor.ink)
                    Text("Puedes elegir más de una opción en cada pregunta — se puede ajustar después.")
                        .phText(PHFont.bodySM, color: PHColor.muted)
                }

                pregunta("¿Perros, gatos, o ambos?") {
                    ForEach(EspecieCuidado.allCases) { especie in
                        PHChip(especie.etiqueta, isSelected: viewModel.especies.contains(especie)) {
                            viewModel.alternar(especie)
                        }
                    }
                }

                pregunta("¿Por días, por horas, o ambos?") {
                    ForEach(ModalidadCuidado.allCases) { modalidad in
                        PHChip(modalidad.etiqueta, isSelected: viewModel.modalidades.contains(modalidad)) {
                            viewModel.alternar(modalidad)
                        }
                    }
                }

                pregunta("¿Qué tamaño de mascota?") {
                    ForEach(TamanoMascota.allCases) { tamano in
                        PHChip(tamano.etiqueta, isSelected: viewModel.tamanos.contains(tamano)) {
                            viewModel.alternar(tamano)
                        }
                    }
                }

                if let errorGeneral = viewModel.errorGeneral {
                    Text(errorGeneral)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton("Terminar", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.enviar()
                        if viewModel.enviado { dismiss() }
                    }
                }
                .disabled(!viewModel.puedeEnviar)
            }
            .padding(PHSpacing.s24)
        }
        .background(PHColor.canvas)
        .navigationTitle("Preferencias")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func pregunta(_ titulo: String, @ViewBuilder chips: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(titulo)
                .phText(PHFont.titleMD, color: PHColor.ink)
            // Máximo 3 chips por pregunta, con texto corto: caben en una fila en cualquier
            // ancho de iPhone sin necesitar un layout de "flow" con salto de línea.
            HStack(spacing: PHSpacing.s8) {
                chips()
            }
        }
    }
}
