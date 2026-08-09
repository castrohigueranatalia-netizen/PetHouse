//
//  MascotaFormView.swift
//  Features/Perfil
//

import SwiftUI

struct MascotaFormView: View {
    let mascota: Mascota?
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MascotaFormViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    formulario(viewModel)
                }
            }
            .navigationTitle(mascota == nil ? "Nueva mascota" : "Editar mascota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                if viewModel == nil { viewModel = MascotaFormViewModel(mascota: mascota, session: session) }
            }
        }
    }

    @ViewBuilder
    private func formulario(_ viewModel: MascotaFormViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s16) {
                PHTextField(label: "Nombre", placeholder: "Ej. Firulais", text: Binding(get: { viewModel.nombre }, set: { viewModel.nombre = $0 }))

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Especie").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    Picker("Especie", selection: Binding(get: { viewModel.especie }, set: { viewModel.especie = $0 })) {
                        ForEach(Mascota.especiesSugeridas, id: \.self) { especie in
                            Text(especie.capitalized).tag(especie)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                PHTextField(label: "Raza (opcional)", placeholder: "Ej. Labrador", text: Binding(get: { viewModel.raza }, set: { viewModel.raza = $0 }))
                PHTextField(label: "Peso en kg (opcional)", placeholder: "Ej. 12.5", text: Binding(get: { viewModel.pesoKg }, set: { viewModel.pesoKg = $0 }), keyboardType: .decimalPad)

                Toggle("Vacunas al día", isOn: Binding(get: { viewModel.vacunasDia }, set: { viewModel.vacunasDia = $0 }))

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Notas (opcional)").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    TextEditor(text: Binding(get: { viewModel.notas }, set: { viewModel.notas = $0 }))
                        .frame(minHeight: 80)
                        .padding(PHSpacing.s8)
                        .background(PHColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                }

                switch viewModel.resultado {
                case .pendienteBackend:
                    PHEmptyStateView(
                        systemImage: "hourglass",
                        titulo: "Función pendiente",
                        mensaje: (mascota == nil ? "Agregar" : "Editar") + " mascotas todavía no está disponible en el servidor."
                    )
                case .error(let mensaje):
                    Text(mensaje).phText(PHFont.bodySM, color: PHColor.error)
                case .exito, .ninguno:
                    EmptyView()
                }

                PHPrimaryButton("Guardar", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.guardar()
                        if viewModel.resultado == .exito { dismiss() }
                    }
                }
                .disabled(!viewModel.puedeGuardar)
            }
            .padding(PHSpacing.s16)
        }
    }
}
