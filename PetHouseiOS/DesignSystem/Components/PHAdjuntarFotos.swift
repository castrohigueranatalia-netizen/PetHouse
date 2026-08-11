//
//  PHAdjuntarFotos.swift
//  DesignSystem/Components
//
//  Selector de una o varias fotos con miniaturas + botón de quitar. Reutilizado por el
//  formulario de verificación de anfitrión (certificado, referencias, fotos de la persona
//  y de la vivienda) — mismo patrón en los 4 campos.
//
//  No importa Networking (regla de capas: DesignSystem no depende de la capa de red): la
//  subida real la hace el closure `subir` que pasa el Feature que lo usa (ver
//  VerificacionAnfitrionViewModel), este componente solo maneja el picker, las miniaturas
//  y el estado de carga/error de la subida.
//

import SwiftUI
import PhotosUI

public struct PHAdjuntarFotos: View {
    let titulo: String
    let subtitulo: String?
    let maximo: Int?
    @Binding var urls: [String]
    let subir: (Data) async -> String?

    @State private var seleccion: [PhotosPickerItem] = []
    @State private var subiendo = false
    @State private var error: String?

    public init(
        titulo: String, subtitulo: String? = nil, maximo: Int? = nil,
        urls: Binding<[String]>, subir: @escaping (Data) async -> String?
    ) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.maximo = maximo
        self._urls = urls
        self.subir = subir
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(titulo)
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
            if let subtitulo {
                Text(subtitulo)
                    .phText(PHFont.captionSM, color: PHColor.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PHSpacing.s8) {
                    ForEach(urls, id: \.self) { url in
                        ZStack(alignment: .topTrailing) {
                            PHCachedAsyncImage(urlString: MediaURL.resolver(url)) {
                                Rectangle().fill(PHColor.surfaceStrong)
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))

                            Button {
                                urls.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, PHColor.error)
                            }
                            .padding(4)
                            .accessibilityLabel("Quitar foto")
                        }
                    }

                    if maximo == nil || urls.count < maximo! {
                        PhotosPicker(
                            selection: $seleccion,
                            maxSelectionCount: maximo.map { $0 - urls.count },
                            matching: .images
                        ) {
                            RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous)
                                .stroke(PHColor.hairline, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    subiendo
                                        ? AnyView(ProgressView())
                                        : AnyView(Image(systemName: "plus").foregroundStyle(PHColor.muted))
                                )
                        }
                        .disabled(subiendo)
                        .accessibilityLabel("Agregar foto a \(titulo)")
                    }
                }
            }

            if let error {
                Text(error).phText(PHFont.captionSM, color: PHColor.error)
            }
        }
        .onChange(of: seleccion) { _, nuevos in
            guard !nuevos.isEmpty else { return }
            Task { await subirSeleccion(nuevos) }
        }
    }

    @MainActor
    private func subirSeleccion(_ items: [PhotosPickerItem]) async {
        subiendo = true
        error = nil
        defer { subiendo = false; seleccion = [] }

        for item in items {
            guard let datos = try? await item.loadTransferable(type: Data.self) else { continue }
            if let url = await subir(datos) {
                urls.append(url)
            } else {
                error = "No se pudo subir una de las fotos. Intenta de nuevo."
            }
        }
    }
}
