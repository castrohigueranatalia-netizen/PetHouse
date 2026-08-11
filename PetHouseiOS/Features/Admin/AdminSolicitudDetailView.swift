//
//  AdminSolicitudDetailView.swift
//  Features/Admin
//
//  Detalle de una solicitud de anfitrión: toda la información que la persona ya llenó
//  (ver VerificacionAnfitrionView) más los botones de decisión. `alAvanzar` refresca la
//  lista en AdminSolicitudesView cuando se resuelve.
//

import SwiftUI

struct AdminSolicitudDetailView: View {
    let solicitud: SolicitudAnfitrion
    let alResolver: () -> Void

    @State private var viewModel: AdminSolicitudDetailViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let viewModel {
                detalle(viewModel)
            } else {
                PHLoadingStateView()
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = AdminSolicitudDetailViewModel(solicitud: solicitud) }
        }
    }

    @ViewBuilder
    private func detalle(_ viewModel: AdminSolicitudDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                encabezado(viewModel)

                seccion("Nombre legal") { Text(viewModel.solicitud.nombreLegal).phText(PHFont.bodyMD, color: PHColor.ink) }
                seccion("Cédula") { Text(viewModel.solicitud.cedula).phText(PHFont.bodyMD, color: PHColor.ink) }
                seccion("Contacto") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.solicitud.usuarioEmail).phText(PHFont.bodyMD, color: PHColor.ink)
                        if let telefono = viewModel.solicitud.usuarioTelefono, !telefono.isEmpty {
                            Text(telefono).phText(PHFont.bodySM, color: PHColor.muted)
                        }
                    }
                }

                galeria("Certificado de antecedentes policiales", urls: [viewModel.solicitud.certificadoPolicialUrl])
                galeria("Fotos de la persona", urls: viewModel.solicitud.fotosPersona)
                galeria("Fotos de la vivienda", urls: viewModel.solicitud.fotosVivienda)
                if !viewModel.solicitud.referencias.isEmpty {
                    galeria("Referencias", urls: viewModel.solicitud.referencias)
                }

                if let error = viewModel.error {
                    Text(error.localizedDescription).phText(PHFont.bodySM, color: PHColor.error)
                }

                if viewModel.solicitud.estado == .pendiente {
                    HStack(spacing: PHSpacing.s12) {
                        PHSecondaryButton("Rechazar") {
                            Task { await viewModel.rechazar() }
                        }
                        PHPrimaryButton("Aprobar", isLoading: viewModel.isLoading) {
                            Task { await viewModel.aprobar() }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(PHSpacing.s24)
        }
        .background(PHColor.canvas)
        .navigationTitle("Solicitud")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.resuelto) { _, resuelto in
            if resuelto {
                alResolver()
                dismiss()
            }
        }
    }

    private func encabezado(_ viewModel: AdminSolicitudDetailViewModel) -> some View {
        HStack(spacing: PHSpacing.s12) {
            PHAvatar(name: viewModel.solicitud.usuarioNombre, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.solicitud.usuarioNombre)
                    .phText(PHFont.displaySM, color: PHColor.ink)
                switch viewModel.solicitud.estado {
                case .pendiente: PHBadge("En revisión", style: .warning)
                case .aprobado: PHBadge("Verificado", style: .success)
                case .rechazado: PHBadge("Rechazada", style: .error)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func seccion(_ titulo: String, @ViewBuilder contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s4) {
            Text(titulo).phText(PHFont.captionSM, color: PHColor.muted)
            contenido()
        }
    }

    private func galeria(_ titulo: String, urls: [String]) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(titulo).phText(PHFont.captionSM, color: PHColor.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PHSpacing.s8) {
                    ForEach(urls, id: \.self) { url in
                        PHCachedAsyncImage(urlString: MediaURL.resolver(url)) {
                            Rectangle().fill(PHColor.surfaceStrong)
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
                    }
                }
            }
        }
    }
}
