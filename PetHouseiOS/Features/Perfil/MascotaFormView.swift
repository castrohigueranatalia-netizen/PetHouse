//
//  MascotaFormView.swift
//  Features/Perfil
//
//  El ViewModel se crea de una vez en el `init` (recibiendo `session` como parámetro
//  explícito de quien presenta esta vista, ver PerfilView), no en `.onAppear` leyendo
//  `@Environment` — antes quedaba `nil` hasta el primer `.onAppear`, y en ese primer instante
//  el `Group { if let viewModel {...} }` no tenía nada que mostrar todavía: sin un estado de
//  carga de respaldo, esa ventana podía quedar viéndose en blanco (reportado en la práctica
//  al tocar "Agregar mascota"). Con el ViewModel ya armado desde el `init`, la primera
//  renderización siempre tiene contenido.
//

import SwiftUI

struct MascotaFormView: View {
    let mascota: Mascota?
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MascotaFormViewModel

    init(mascota: Mascota?, session: SessionStore) {
        self.mascota = mascota
        _viewModel = State(initialValue: MascotaFormViewModel(mascota: mascota, session: session))
    }

    var body: some View {
        NavigationStack {
            formulario(viewModel)
                .navigationTitle(mascota == nil ? "Nueva mascota" : "Editar mascota")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        PHTextButton("Cancelar") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private func formulario(_ viewModel: MascotaFormViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s16) {
                PHAdjuntarFotos(
                    titulo: "Fotos de tu mascota (opcional)",
                    subtitulo: "El anfitrión las ve en la ficha al recibir tu solicitud de reserva.",
                    maximo: 6,
                    urls: Binding(get: { viewModel.fotos }, set: { viewModel.fotos = $0 }),
                    subir: viewModel.subirFoto
                )

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

                HStack(spacing: PHSpacing.s12) {
                    PHTextField(label: "Edad en años (opcional)", placeholder: "Ej. 3", text: Binding(get: { viewModel.edad }, set: { viewModel.edad = $0 }), keyboardType: .numberPad)
                    PHTextField(label: "Peso en kg (opcional)", placeholder: "Ej. 12.5", text: Binding(get: { viewModel.pesoKg }, set: { viewModel.pesoKg = $0 }), keyboardType: .decimalPad)
                }

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Tamaño (opcional)").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    Picker("Tamaño", selection: Binding(
                        get: { viewModel.tamano ?? "" },
                        set: { viewModel.tamano = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Sin especificar").tag("")
                        ForEach(Mascota.tamanosSugeridos, id: \.self) { tamano in
                            Text(tamanoLegible(tamano)).tag(tamano)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Vacunas al día", isOn: Binding(get: { viewModel.vacunasDia }, set: { viewModel.vacunasDia = $0 }))
                Toggle("Necesita tomar medicamentos", isOn: Binding(get: { viewModel.necesitaMedicamentos }, set: { viewModel.necesitaMedicamentos = $0 }))

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text(viewModel.necesitaMedicamentos ? "¿Qué medicamento necesita y cuándo? (opcional)" : "Notas (opcional)")
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
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

    private func tamanoLegible(_ tamano: String) -> String {
        switch tamano {
        case "pequeno": "Pequeño"
        case "mediano": "Mediano"
        case "grande": "Grande"
        default: tamano.capitalized
        }
    }
}
