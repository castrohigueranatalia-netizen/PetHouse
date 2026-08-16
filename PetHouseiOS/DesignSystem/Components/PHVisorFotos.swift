//
//  PHVisorFotos.swift
//  DesignSystem/Components
//
//  Visor de fotos a pantalla completa, con zoom (pellizcar o doble toque) y deslizar entre
//  varias — reutilizado en cualquier lugar de la app que muestre fotos reales (galería de un
//  hospedaje, ficha de una mascota, documentos de verificación de anfitrión, foto de
//  perfil, etc.). Quien lo use se presenta con `.fullScreenCover(item:)` sobre un
//  `FotoVisorItem` — no un `Bool`, así cada toque en una foto distinta arma su propia lista
//  de URLs y su índice inicial sin pisar estado de una foto anterior.
//
//  Decodifica a 1600pt (ver PHCachedAsyncImage.ladoMaximoPt) — el mismo tamaño máximo al que
//  ImagenComprimida ya comprime cualquier foto antes de subirla, así que acá se ve la foto a
//  su resolución real guardada, no una miniatura ampliada y borrosa.
//

import SwiftUI
import Foundation

/// Envuelve la lista de fotos a mostrar + desde cuál empezar — `Identifiable` con un `id`
/// nuevo en cada toque, para que `.fullScreenCover(item:)` siempre presente una instancia
/// fresca (sin esto, tocar la MISMA foto una segunda vez después de cerrar el visor podría
/// no volver a abrirlo, porque el `item` "no cambió" desde el punto de vista de SwiftUI).
public struct FotoVisorItem: Identifiable {
    public let id = UUID()
    public let urls: [String]
    public let indiceInicial: Int

    public init(urls: [String], indiceInicial: Int = 0) {
        self.urls = urls
        self.indiceInicial = indiceInicial
    }
}

public struct PHVisorFotos: View {
    let urls: [String]
    @State private var indice: Int
    @Environment(\.dismiss) private var dismiss

    public init(urls: [String], indiceInicial: Int = 0) {
        self.urls = urls
        _indice = State(initialValue: indiceInicial)
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $indice) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    FotoZoomable(urlString: MediaURL.resolver(url))
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(PHSpacing.s12)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .accessibilityLabel("Cerrar")
                }
                .padding(PHSpacing.s16)

                Spacer()

                if urls.count > 1 {
                    Text("\(indice + 1) de \(urls.count)")
                        .phText(PHFont.captionSM.weight(.semibold), color: .white)
                        .padding(.horizontal, PHSpacing.s12)
                        .padding(.vertical, PHSpacing.s4)
                        .background(.black.opacity(0.4), in: Capsule())
                        .padding(.bottom, PHSpacing.s24)
                }
            }
        }
        .statusBarHidden()
    }
}

/// Una sola foto con zoom: pellizcar para acercar (hasta 4x), arrastrar para moverse una vez
/// acercada, doble toque para acercar/alejar de un salto. Al soltar el pellizco, si quedó en
/// el tamaño original o más chico, se recentra sola.
private struct FotoZoomable: View {
    let urlString: String?

    @State private var escala: CGFloat = 1
    @State private var ultimaEscala: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var ultimoOffset: CGSize = .zero

    private let escalaMin: CGFloat = 1
    private let escalaMax: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            PHCachedAsyncImage(urlString: urlString, ladoMaximoPt: 1600, modoContenido: .fit) {
                ProgressView().tint(.white)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(escala)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { valor in
                            escala = min(max(ultimaEscala * valor, escalaMin), escalaMax)
                        }
                        .onEnded { _ in
                            ultimaEscala = escala
                            if escala <= escalaMin { recentrar() }
                        },
                    DragGesture()
                        .onChanged { valor in
                            guard escala > escalaMin else { return }
                            offset = CGSize(
                                width: ultimoOffset.width + valor.translation.width,
                                height: ultimoOffset.height + valor.translation.height
                            )
                        }
                        .onEnded { _ in
                            ultimoOffset = offset
                        }
                )
            )
            .onTapGesture(count: 2) {
                if escala > escalaMin {
                    recentrar()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        escala = 2.5
                        ultimaEscala = 2.5
                    }
                }
            }
        }
    }

    private func recentrar() {
        withAnimation(.spring(response: 0.3)) {
            escala = escalaMin
            ultimaEscala = escalaMin
            offset = .zero
            ultimoOffset = .zero
        }
    }
}
