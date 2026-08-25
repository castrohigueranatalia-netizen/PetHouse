//
//  HospedajeDetailView.swift
//  Features/HospedajeDetail
//

import SwiftUI

struct HospedajeDetailView: View {
    let hospedajeId: String

    @State private var viewModel: HospedajeDetailViewModel?
    @State private var favoritosViewModel = FavoritosViewModel()
    @State private var mostrarReserva = false
    /// Página actual de la galería de arriba — tocar una foto abre el visor de pantalla
    /// completa (ver `PHVisorFotos`) empezando en esta misma página.
    @State private var indiceGaleria = 0
    @State private var fotoVisor: FotoVisorItem?
    @State private var mostrarReportarAnfitrion = false
    @State private var resenaAReportar: Resena?
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                PHLoadingStateView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = HospedajeDetailViewModel(hospedajeId: hospedajeId)
            }
            await viewModel?.cargar()
        }
        .sheet(item: $resenaAReportar) { resena in
            ReportarSheet(
                usuarioDenunciadoNombre: resena.autor ?? "esta reseña",
                tipo: .resena,
                resenaId: resena.id,
                textoCitado: resena.texto,
                hospedajeId: hospedajeId
            )
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HospedajeDetailViewModel) -> some View {
        if viewModel.isLoading && viewModel.hospedaje == nil {
            PHLoadingStateView(mensaje: "Cargando hospedaje…")
        } else if let error = viewModel.error, viewModel.hospedaje == nil {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if let hospedaje = viewModel.hospedaje {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    galeria(hospedaje)

                    VStack(alignment: .leading, spacing: PHSpacing.s8) {
                        HStack {
                            Text(hospedaje.titulo)
                                .phText(PHFont.displaySM, color: PHColor.ink)
                            Spacer()
                            ShareLink(item: textoCompartir(hospedaje)) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(PHColor.ink)
                                    .frame(width: 40, height: 40)
                                    .background(PHColor.surfaceSoft)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Compartir hospedaje")
                            PHIconButton(
                                systemImage: favoritosViewModel.esFavorito(hospedaje.id) ? "heart.fill" : "heart",
                                accessibilityLabel: "Alternar favorito"
                            ) {
                                Task { await favoritosViewModel.alternar(hospedaje) }
                            }
                        }
                        PHStarRatingDisplay(rating: hospedaje.rating, numResenas: hospedaje.numResenas)
                        // `localidad` en vez de `ciudad`: con la app restringida a Bogotá,
                        // `ciudad` es siempre "Bogotá" — no aporta nada que el usuario no sepa ya.
                        Text([hospedaje.barrio, hospedaje.localidad ?? hospedaje.ciudad].compactMap { $0 }.joined(separator: ", "))
                            .phText(PHFont.bodySM, color: PHColor.muted)
                        PHBadge(hospedaje.tipo.etiqueta, style: .primary)
                    }

                    if let anfitrion = hospedaje.anfitrionNombre, let anfitrionId = hospedaje.anfitrionId {
                        anfitrionSeccion(nombre: anfitrion, verificado: hospedaje.anfitrionVerificado ?? false) {
                            mostrarReportarAnfitrion = true
                        }
                        .sheet(isPresented: $mostrarReportarAnfitrion) {
                            ReportarSheet(
                                usuarioDenunciadoId: anfitrionId,
                                usuarioDenunciadoNombre: anfitrion,
                                tipo: .anfitrion,
                                hospedajeId: hospedaje.id
                            )
                        }
                    }

                    if let descripcion = hospedaje.descripcion, !descripcion.isEmpty {
                        seccion(titulo: "Acerca de este lugar") {
                            Text(descripcion).phText(PHFont.bodyMD, color: PHColor.body)
                        }
                    }

                    if let servicios = hospedaje.servicios, !servicios.isEmpty {
                        seccion(titulo: "Servicios") {
                            PHFlowChips(items: servicios)
                        }
                    }

                    if let reglas = hospedaje.reglas, !reglas.isEmpty {
                        seccion(titulo: "Reglas de la casa") {
                            VStack(alignment: .leading, spacing: PHSpacing.s4) {
                                ForEach(reglas, id: \.self) { regla in
                                    Label(regla, systemImage: "checkmark.circle")
                                        .phText(PHFont.bodySM, color: PHColor.body)
                                }
                            }
                        }
                    }

                    seccion(titulo: "Reseñas") {
                        if viewModel.resenas.isEmpty {
                            Text("Todavía no hay reseñas para este hospedaje.")
                                .phText(PHFont.bodySM, color: PHColor.muted)
                        } else {
                            VStack(alignment: .leading, spacing: PHSpacing.s12) {
                                ForEach(viewModel.resenas, id: \.identity) { resena in
                                    resenaFila(resena)
                                }
                            }
                        }
                    }
                }
                .padding(PHSpacing.s16)
                .padding(.bottom, 100)
            }
            .safeAreaInset(edge: .bottom) {
                barraReserva(hospedaje)
            }
            .sheet(isPresented: $mostrarReserva) {
                NuevaReservaView(hospedaje: hospedaje, mascotasDisponibles: session.mascotas)
            }
            .fullScreenCover(item: $fotoVisor) { item in
                PHVisorFotos(urls: item.urls, indiceInicial: item.indiceInicial)
            }
        }
    }

    private func galeria(_ hospedaje: Hospedaje) -> some View {
        let fotos = hospedaje.fotos ?? []
        return TabView(selection: $indiceGaleria) {
            if fotos.isEmpty {
                Rectangle()
                    .fill(PHColor.surfaceStrong)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(PHColor.mutedSoft))
                    .tag(0)
            } else {
                ForEach(Array(fotos.enumerated()), id: \.offset) { index, url in
                    Button {
                        fotoVisor = FotoVisorItem(urls: fotos, indiceInicial: index)
                    } label: {
                        PHCachedAsyncImage(urlString: MediaURL.resolver(url), ladoMaximoPt: 500) {
                            Rectangle().fill(PHColor.surfaceStrong)
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    /// Texto plano para `ShareLink` (Mensajes, WhatsApp, Facebook, lo que tenga instalado el
    /// usuario) — sin enlace, porque todavía no hay una URL que abra este hospedaje puntual
    /// (ni un sitio web público, ni universal links configurados en la app). Si más adelante
    /// se agrega alguno de los dos, esto es lo único que habría que tocar.
    private func textoCompartir(_ hospedaje: Hospedaje) -> String {
        let ubicacion = [hospedaje.barrio, hospedaje.localidad ?? hospedaje.ciudad].compactMap { $0 }.joined(separator: ", ")
        return "🐾 Mira este hospedaje en PetHouse: \(hospedaje.titulo)\n\(ubicacion) · \(hospedaje.tipo.etiqueta) · \(PHFormato.precio(hospedaje.precioNoche))/noche"
    }

    private func anfitrionSeccion(nombre: String, verificado: Bool, alReportar: @escaping () -> Void) -> some View {
        HStack(spacing: PHSpacing.s12) {
            PHAvatar(name: nombre, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hospedado por \(nombre)")
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                if verificado {
                    PHBadge("Anfitrión verificado", style: .success)
                }
            }
            Spacer()
            PHIconButton(systemImage: "flag", accessibilityLabel: "Reportar a \(nombre)", action: alReportar)
        }
    }

    private func seccion<Content: View>(titulo: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(titulo).phText(PHFont.titleMD, color: PHColor.ink)
            content()
        }
    }

    private func resenaFila(_ resena: Resena) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(resena.autor ?? "Usuario de PetHouse")
                    .phText(PHFont.bodySM.weight(.semibold), color: PHColor.ink)
                Spacer()
                PHStarRatingDisplay(rating: Double(resena.rating))
                if resena.id != nil {
                    Button {
                        resenaAReportar = resena
                    } label: {
                        Image(systemName: "flag")
                            .foregroundStyle(PHColor.muted)
                    }
                    .accessibilityLabel("Reportar esta reseña")
                }
            }
            if let titulo = resena.titulo, !titulo.isEmpty {
                Text(titulo).phText(PHFont.bodySM.weight(.semibold), color: PHColor.body)
            }
            if let texto = resena.texto, !texto.isEmpty {
                Text(texto).phText(PHFont.bodySM, color: PHColor.muted)
            }
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private func barraReserva(_ hospedaje: Hospedaje) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                if hospedaje.activo == false {
                    Text("No disponible por ahora")
                        .phText(PHFont.bodySM.weight(.semibold), color: PHColor.muted)
                } else {
                    Text(PHFormato.precio(hospedaje.precioNoche))
                        .phText(PHFont.titleMD, color: PHColor.ink)
                    Text("por noche")
                        .phText(PHFont.micro, color: PHColor.muted)
                }
            }
            Spacer()
            PHPrimaryButton("Reservar", systemImage: "calendar.badge.plus") {
                mostrarReserva = true
            }
            .frame(maxWidth: 180)
            .disabled(hospedaje.activo == false)
        }
        .padding(PHSpacing.s16)
        .background(.ultraThinMaterial)
    }
}

/// Chips en flujo horizontal envolvente — usados para "servicios" del hospedaje.
private struct PHFlowChips: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            ForEach(agrupar(items), id: \.self) { fila in
                HStack(spacing: PHSpacing.s8) {
                    ForEach(fila, id: \.self) { item in
                        PHBadge(item)
                    }
                }
            }
        }
    }

    private func agrupar(_ items: [String], porFila: Int = 3) -> [[String]] {
        stride(from: 0, to: items.count, by: porFila).map {
            Array(items[$0..<min($0 + porFila, items.count)])
        }
    }
}
