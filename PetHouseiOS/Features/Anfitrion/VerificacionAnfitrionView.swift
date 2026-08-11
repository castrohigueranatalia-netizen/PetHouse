//
//  VerificacionAnfitrionView.swift
//  Features/Anfitrion
//
//  Paso 1 de "Conviértete en anfitrión" (ver PerfilView). Al enviar con éxito, pasa al
//  paso 2 (PreferenciasAnfitrionView) — todavía no vuelve al Perfil, la capacidad ya quedó
//  activa en el servidor, pero falta configurar qué prefiere cuidar.
//

import SwiftUI

struct VerificacionAnfitrionView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel: VerificacionAnfitrionViewModel?
    @State private var avanzarAPreferencias = false

    var body: some View {
        ScrollView {
            if let viewModel {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    VStack(alignment: .leading, spacing: PHSpacing.s8) {
                        Text("Verificación de seguridad")
                            .phText(PHFont.displayMD, color: PHColor.ink)
                        Text("Para proteger a las mascotas y sus dueños, todo anfitrión pasa por esta verificación antes de publicar un espacio.")
                            .phText(PHFont.bodySM, color: PHColor.muted)
                    }

                    PHTextField(
                        label: "Nombre legal completo",
                        placeholder: "Como aparece en tu cédula",
                        text: Binding(get: { viewModel.nombreLegal }, set: { viewModel.nombreLegal = $0 }),
                        errorMessage: viewModel.errorNombre,
                        textContentType: .name
                    )

                    PHTextField(
                        label: "Número de cédula",
                        placeholder: "1234567890",
                        text: Binding(get: { viewModel.cedula }, set: { viewModel.cedula = $0 }),
                        errorMessage: viewModel.errorCedula,
                        keyboardType: .numberPad
                    )

                    PHAdjuntarFotos(
                        titulo: "Certificado de antecedentes policiales",
                        subtitulo: "Foto o captura del documento vigente.",
                        maximo: 1,
                        urls: Binding(get: { viewModel.certificadoPolicialUrl }, set: { viewModel.certificadoPolicialUrl = $0 }),
                        subir: { await viewModel.subirFoto($0) }
                    )

                    PHAdjuntarFotos(
                        titulo: "Fotos tuyas",
                        subtitulo: "Al menos una, donde se te vea con claridad.",
                        urls: Binding(get: { viewModel.fotosPersonaUrls }, set: { viewModel.fotosPersonaUrls = $0 }),
                        subir: { await viewModel.subirFoto($0) }
                    )

                    PHAdjuntarFotos(
                        titulo: "Fotos del lugar donde vives",
                        subtitulo: "Al menos una — ayuda a los dueños a confiar en el espacio.",
                        urls: Binding(get: { viewModel.fotosViviendaUrls }, set: { viewModel.fotosViviendaUrls = $0 }),
                        subir: { await viewModel.subirFoto($0) }
                    )

                    PHAdjuntarFotos(
                        titulo: "Referencias (opcional)",
                        subtitulo: "Cartas o capturas de contacto de personas que te recomienden.",
                        urls: Binding(get: { viewModel.referenciasUrls }, set: { viewModel.referenciasUrls = $0 }),
                        subir: { await viewModel.subirFoto($0) }
                    )

                    if let errorGeneral = viewModel.errorGeneral {
                        Text(errorGeneral)
                            .phText(PHFont.bodySM, color: PHColor.error)
                    }

                    PHPrimaryButton("Continuar", isLoading: viewModel.isLoading) {
                        Task { await viewModel.enviar() }
                    }
                    .disabled(!viewModel.puedeEnviar)
                }
                .padding(PHSpacing.s24)
            } else {
                PHLoadingStateView()
            }
        }
        .background(PHColor.canvas)
        .navigationTitle("Verificación")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil { viewModel = VerificacionAnfitrionViewModel(session: session) }
        }
        .onChange(of: viewModel?.enviado) { _, enviado in
            if enviado == true { avanzarAPreferencias = true }
        }
        .navigationDestination(isPresented: $avanzarAPreferencias) {
            PreferenciasAnfitrionView()
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
