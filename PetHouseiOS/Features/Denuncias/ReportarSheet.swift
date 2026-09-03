//
//  ReportarSheet.swift
//  Features/Denuncias
//
//  Formulario para reportar un anfitrión, cualquier usuario, un mensaje del chat o una
//  reseña — el mismo para los 4 casos (ver ReportarViewModel). Se abre desde
//  HospedajeDetailView (anfitrión o una reseña del hospedaje), ReservasRecibidasView
//  (huésped de una solicitud), ChatDetailView (la persona o un mensaje puntual) y
//  EvaluacionHuespedView (una reseña del huésped).
//

import SwiftUI

struct ReportarSheet: View {
    @State private var viewModel: ReportarViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        usuarioDenunciadoId: String? = nil, usuarioDenunciadoNombre: String, tipo: TipoDenuncia,
        mensajeId: String? = nil, resenaId: String? = nil, textoCitado: String? = nil, hospedajeId: String? = nil
    ) {
        _viewModel = State(initialValue: ReportarViewModel(
            usuarioDenunciadoId: usuarioDenunciadoId,
            usuarioDenunciadoNombre: usuarioDenunciadoNombre,
            tipo: tipo,
            mensajeId: mensajeId,
            resenaId: resenaId,
            textoCitado: textoCitado,
            hospedajeId: hospedajeId
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.enviado {
                    enviadoView
                } else {
                    formulario
                }
            }
            .navigationTitle("Reportar a \(viewModel.usuarioDenunciadoNombre)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                if let textoCitado = viewModel.textoCitado {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text(viewModel.tipo == .resena ? "Reseña reportada" : "Mensaje reportado")
                            .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                        Text(textoCitado)
                            .phText(PHFont.bodySM, color: PHColor.body)
                            .padding(PHSpacing.s12)
                            .background(PHColor.surfaceSoft)
                            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: PHSpacing.s8) {
                    Text("¿Cuál es el motivo?")
                        .phText(PHFont.bodyMD, color: PHColor.body)
                    Picker("Motivo", selection: $viewModel.motivo) {
                        Text("Selecciona un motivo").tag(MotivoDenuncia?.none)
                        ForEach(MotivoDenuncia.allCases) { motivo in
                            Text(motivo.etiqueta).tag(MotivoDenuncia?.some(motivo))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Cuéntanos más (opcional)")
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    TextEditor(text: $viewModel.comentario)
                        .frame(minHeight: 100)
                        .padding(PHSpacing.s8)
                        .background(PHColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                }

                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton("Enviar reporte", isLoading: viewModel.isLoading) {
                    Task { await viewModel.enviar() }
                }
                .disabled(!viewModel.puedeEnviar)
            }
            .padding(PHSpacing.s16)
        }
    }

    private var enviadoView: some View {
        VStack(spacing: PHSpacing.s16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(PHColor.success)
            Text("Gracias por avisarnos")
                .phText(PHFont.displaySM, color: PHColor.ink)
            Text("Nuestro equipo va a revisar tu reporte.")
                .phText(PHFont.bodySM, color: PHColor.muted)
                .multilineTextAlignment(.center)
            PHPrimaryButton("Listo") { dismiss() }
                .padding(.horizontal, PHSpacing.s32)
        }
        .padding(.top, PHSpacing.s32)
        .frame(maxWidth: .infinity)
    }
}
