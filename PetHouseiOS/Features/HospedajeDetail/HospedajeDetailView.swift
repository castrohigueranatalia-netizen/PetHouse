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

                    if let anfitrion = hospedaje.anfitrionNombre {
                        anfitrionSeccion(nombre: anfitrion, verificado: hospedaje.anfitrionVerificado ?? false)
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
                NuevaReservaView(hospedaje: hospedaje)
            }
        }
    }

    private func galeria(_ hospedaje: Hospedaje) -> some View {
        let fotos = hospedaje.fotos ?? []
        return TabView {
            if fotos.isEmpty {
                Rectangle()
                    .fill(PHColor.surfaceStrong)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(PHColor.mutedSoft))
            } else {
                ForEach(fotos, id: \.self) { url in
                    PHCachedAsyncImage(urlString: MediaURL.resolver(url), ladoMaximoPt: 500) {
                        Rectangle().fill(PHColor.surfaceStrong)
                    }
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private func anfitrionSeccion(nombre: String, verificado: Bool) -> some View {
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
                Text(PHFormato.precio(hospedaje.precioNoche))
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Text("por noche")
                    .phText(PHFont.micro, color: PHColor.muted)
            }
            Spacer()
            PHPrimaryButton("Reservar", systemImage: "calendar.badge.plus") {
                mostrarReserva = true
            }
            .frame(maxWidth: 180)
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
