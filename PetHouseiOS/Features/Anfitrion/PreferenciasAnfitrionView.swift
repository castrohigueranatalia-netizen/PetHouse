//
//  PreferenciasAnfitrionView.swift
//  Features/Anfitrion
//
//  Paso 2 (último) de "Conviértete en anfitrión". Al enviar con éxito, en vez de cerrar el
//  flujo en silencio, muestra una confirmación (chulo + "solicitud enviada") — el usuario
//  toca "Listo" para volver al Perfil. La solicitud queda pendiente de revisión; el aviso
//  de si fue aprobada o rechazada llega después, apenas se vuelva a abrir la app (ver
//  SessionStore.revisarResolucionVerificacion/MainTabView — sin push notifications, ADR-7).
//
//  `alTerminar` (en vez de `@Environment(\.dismiss)` acá): esta vista está empujada DENTRO
//  de VerificacionAnfitrionView (paso 1), así que su propio `dismiss()` solo la sacaría a
//  ELLA, dejando visible el formulario de verificación ya usado detrás. `alTerminar` deja
//  que sea VerificacionAnfitrionView quien se cierre a sí misma, lo que se lleva puesto
//  todo lo que empujó — vuelve de un solo golpe al Perfil. Mismo patrón que
//  `PublicarHospedajeView.alPublicar`/`AdminSolicitudDetailView.alResolver`.
//

import SwiftUI

struct PreferenciasAnfitrionView: View {
    let alTerminar: () -> Void

    @State private var viewModel = PreferenciasAnfitrionViewModel()
    @State private var insigniaVisible = false

    var body: some View {
        Group {
            if viewModel.enviado {
                confirmacion
            } else {
                formulario
            }
        }
        .background(PHColor.canvas)
        .navigationTitle("Preferencias")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    private var formulario: some View {
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
                    Task { await viewModel.enviar() }
                }
                .disabled(!viewModel.puedeEnviar)
            }
            .padding(PHSpacing.s24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var confirmacion: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PHColor.successContainer)
                    .frame(width: 96, height: 96)
                    .phShadow(PHShadow.level2)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PHColor.success)
            }
            .scaleEffect(insigniaVisible ? 1 : 0.6)
            .opacity(insigniaVisible ? 1 : 0)

            VStack(spacing: PHSpacing.s8) {
                Text("¡Solicitud enviada!")
                    .phText(PHFont.displayMD, color: PHColor.ink)
                Text("Un administrador va a revisar tus datos. Te avisaremos en la app apenas quede aprobada o rechazada.")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(.top, PHSpacing.s24)

            Spacer()
            Spacer()

            PHPrimaryButton("Listo") {
                alTerminar()
            }
            .padding(.horizontal, PHSpacing.s24)
        }
        .padding(.vertical, PHSpacing.s32)
        .padding(.horizontal, PHSpacing.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                insigniaVisible = true
            }
        }
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
