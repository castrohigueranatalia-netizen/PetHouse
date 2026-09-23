//
//  ActualizacionesReservaView.swift
//  Features/Anfitrion
//
//  Se abre desde ReservasRecibidasView, solo para reservas 'confirmada' — el anfitrión ve lo
//  que ya publicó y puede agregar una nota y/o fotos nuevas de cómo va la mascota. Presentada
//  con `.sheet(item:)`, por eso trae su propio `NavigationStack` (mismo patrón que
//  PublicarHospedajeView).
//

import SwiftUI

struct ActualizacionesReservaView: View {
    @State private var viewModel: ActualizacionesReservaViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var fotoVisor: FotoVisorItem?

    init(reserva: Reserva) {
        _viewModel = State(initialValue: ActualizacionesReservaViewModel(reserva: reserva))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    if viewModel.isLoading && viewModel.actualizaciones.isEmpty {
                        PHLoadingStateView(mensaje: "Cargando actualizaciones…")
                    } else if !viewModel.actualizaciones.isEmpty {
                        seccionHistorial
                    }

                    composer
                }
                .padding(PHSpacing.s16)
            }
            .navigationTitle("Actualizaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
            .task { await viewModel.cargar() }
            .fullScreenCover(item: $fotoVisor) { item in
                PHVisorFotos(urls: item.urls, indiceInicial: item.indiceInicial)
            }
        }
    }

    private var seccionHistorial: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Ya publicado")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: PHSpacing.s12) {
                ForEach(viewModel.actualizaciones.reversed()) { actualizacion in
                    filaActualizacion(actualizacion)
                }
            }
        }
    }

    private func filaActualizacion(_ actualizacion: ActualizacionReserva) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(PHDate.displayRelative(actualizacion.creadoEn))
                .phText(PHFont.captionSM, color: PHColor.muted)
            if let notas = actualizacion.notas, !notas.isEmpty {
                Text(notas)
                    .phText(PHFont.bodySM, color: PHColor.ink)
            }
            if !actualizacion.fotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PHSpacing.s8) {
                        ForEach(Array(actualizacion.fotos.enumerated()), id: \.offset) { indice, foto in
                            Button {
                                fotoVisor = FotoVisorItem(urls: actualizacion.fotos, indiceInicial: indice)
                            } label: {
                                PHCachedAsyncImage(urlString: MediaURL.resolver(foto), ladoMaximoPt: 400) {
                                    Rectangle().fill(PHColor.surfaceStrong)
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Nueva actualización")
                .phText(PHFont.titleMD, color: PHColor.ink)

            VStack(alignment: .leading, spacing: PHSpacing.s4) {
                Text("Nota (opcional si agregas fotos)")
                    .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                TextEditor(text: $viewModel.notas)
                    .frame(minHeight: 80)
                    .padding(PHSpacing.s8)
                    .background(PHColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
            }

            PHAdjuntarFotos(
                titulo: "Fotos (opcional si escribes una nota)",
                maximo: 6,
                urls: $viewModel.fotos,
                subir: viewModel.subirFoto
            )

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .phText(PHFont.bodySM, color: PHColor.error)
            }

            PHPrimaryButton("Publicar", isLoading: viewModel.publicando) {
                Task { await viewModel.publicar() }
            }
            .disabled(!viewModel.puedePublicar)
        }
    }
}
