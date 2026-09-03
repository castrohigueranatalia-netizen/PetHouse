//
//  HospedajeDetailView.swift
//  Features/HospedajeDetail
//

import SwiftUI

struct HospedajeDetailView: View {
    let hospedajeId: String
    /// `true` cuando quien presenta esta vista YA sabe que el hospedaje es propio (ver
    /// MisHospedajesView, que solo lista los propios) — así el lápiz de editar aparece de
    /// una en el toolbar en vez de esperar a que responda el servidor con el detalle
    /// completo (~2 segundos), que es lo único que hace falta cargar para ver el resto de
    /// la pantalla (fotos, descripción, reseñas).
    var esPropio: Bool = false
    /// Se llama tras editar un hospedaje propio (ver `mostrarEditar`) — quien presenta esta
    /// vista desde una lista propia (ver MisHospedajesView) la usa para refrescar esa lista
    /// sin esperar a que la recargue sola.
    var alEditar: ((Hospedaje) -> Void)? = nil

    @State private var viewModel: HospedajeDetailViewModel?
    @State private var favoritosViewModel = FavoritosViewModel()
    @State private var mostrarReserva = false
    /// Página actual de la galería de arriba — tocar una foto abre el visor de pantalla
    /// completa (ver `PHVisorFotos`) empezando en esta misma página.
    @State private var indiceGaleria = 0
    @State private var fotoVisor: FotoVisorItem?
    @State private var mostrarReportarAnfitrion = false
    @State private var resenaAReportar: Resena?
    @State private var resenaAResponder: Resena?
    @State private var mostrarEditar = false
    @State private var mostrarBloquearFechas = false
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
        .toolbar {
            if esPropio || (viewModel?.hospedaje).map(esMiHospedaje) == true {
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "pencil", accessibilityLabel: "Editar hospedaje") {
                        mostrarEditar = true
                    }
                    .disabled(viewModel?.hospedaje == nil)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HospedajeDetailViewModel(hospedajeId: hospedajeId)
            }
            await viewModel?.cargar()
        }
        .sheet(isPresented: $mostrarEditar) {
            if let hospedaje = viewModel?.hospedaje {
                PublicarHospedajeView(hospedajeExistente: hospedaje) { guardado in
                    viewModel?.actualizarLocal(guardado)
                    alEditar?(guardado)
                }
            }
        }
        .sheet(isPresented: $mostrarBloquearFechas) {
            if let hospedaje = viewModel?.hospedaje {
                BloquearFechasSheet(hospedaje: hospedaje)
            }
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
                                    resenaFila(resena, hospedaje: hospedaje)
                                }
                            }
                        }
                    }

                    if esPropio || esMiHospedaje(hospedaje) {
                        botonBloquearFechas
                    }
                }
                .padding(PHSpacing.s16)
                .padding(.bottom, 100)
            }
            .safeAreaInset(edge: .bottom) {
                if esMiHospedaje(hospedaje) {
                    barraAnfitrion(hospedaje, viewModel: viewModel)
                } else {
                    barraReserva(hospedaje)
                }
            }
            .sheet(isPresented: $mostrarReserva) {
                NuevaReservaView(hospedaje: hospedaje, mascotasDisponibles: session.mascotas)
            }
            .fullScreenCover(item: $fotoVisor) { item in
                PHVisorFotos(urls: item.urls, indiceInicial: item.indiceInicial)
            }
            .sheet(item: $resenaAResponder) { resena in
                if let resenaId = resena.id {
                    ResponderResenaSheet(
                        hospedajeId: hospedaje.id,
                        resenaId: resenaId,
                        respuestaExistente: resena.respuestaAnfitrion
                    ) { actualizada in
                        viewModel.actualizarResenaLocal(actualizada)
                    }
                }
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
        // Mismo tratamiento que PHHospedajeCard: pausado se ve en gris, no solo tenue.
        .grayscale(hospedaje.activo == false ? 1 : 0)
        .opacity(hospedaje.activo == false ? 0.7 : 1)
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

    /// Opción visible apenas se entra a un hospedaje propio, después de Reseñas — a
    /// diferencia del ícono chico del toolbar de CalendarioHospedajeView, esta es la forma
    /// más fácil de encontrarla sin tener que entrar primero a "Ver calendario".
    private var botonBloquearFechas: some View {
        Button {
            mostrarBloquearFechas = true
        } label: {
            HStack(spacing: PHSpacing.s12) {
                Image(systemName: "calendar.badge.minus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PHColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bloquear fechas")
                        .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                    Text("Congela fechas puntuales sin pausar todo el hospedaje")
                        .phText(PHFont.captionSM, color: PHColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(PHColor.mutedSoft).font(.caption)
            }
            .padding(PHSpacing.s12)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func seccion<Content: View>(titulo: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(titulo).phText(PHFont.titleMD, color: PHColor.ink)
            content()
        }
    }

    /// `true` cuando el hospedaje que se está viendo es propio (el anfitrión mirando su
    /// propia publicación) — cambia la barra de abajo (ver `barraAnfitrion`) y habilita
    /// responder reseñas.
    private func esMiHospedaje(_ hospedaje: Hospedaje) -> Bool {
        hospedaje.anfitrionId != nil && hospedaje.anfitrionId == session.usuario?.id
    }

    private func resenaFila(_ resena: Resena, hospedaje: Hospedaje) -> some View {
        let esMiHospedaje = esMiHospedaje(hospedaje)
        return VStack(alignment: .leading, spacing: 4) {
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

            if let respuesta = resena.respuestaAnfitrion, !respuesta.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Respuesta del anfitrión")
                        .phText(PHFont.micro.weight(.semibold), color: PHColor.muted)
                    Text(respuesta)
                        .phText(PHFont.bodySM, color: PHColor.body)
                }
                .padding(PHSpacing.s8)
                .background(PHColor.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
                .padding(.top, PHSpacing.s4)

                if esMiHospedaje {
                    PHTextButton("Editar respuesta") { resenaAResponder = resena }
                }
            } else if esMiHospedaje && resena.id != nil {
                PHTextButton("Responder") { resenaAResponder = resena }
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

    /// Reemplaza la barra de "Reservar" cuando el anfitrión entra a su propio hospedaje
    /// desde Mis hospedajes — no tiene sentido que se reserve a sí mismo, así que acá mismo
    /// tiene las tres acciones de manejo que antes vivían como enlaces sueltos en la lista.
    private func barraAnfitrion(_ hospedaje: Hospedaje, viewModel: HospedajeDetailViewModel) -> some View {
        HStack(spacing: PHSpacing.s8) {
            NavigationLink {
                ReservasRecibidasView(hospedaje: hospedaje)
            } label: {
                accionAnfitrion("Reservas recibidas", systemImage: "calendar")
            }
            NavigationLink {
                CalendarioHospedajeView(hospedaje: hospedaje)
            } label: {
                accionAnfitrion("Calendario", systemImage: "calendar.badge.clock")
            }
            botonPausarAnfitrion(hospedaje, viewModel: viewModel)
        }
        .padding(PHSpacing.s16)
        .background(.ultraThinMaterial)
    }

    private func accionAnfitrion(_ titulo: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 18))
            Text(titulo).phText(PHFont.micro.weight(.semibold))
        }
        .foregroundStyle(PHColor.primary)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func botonPausarAnfitrion(_ hospedaje: Hospedaje, viewModel: HospedajeDetailViewModel) -> some View {
        let activo = hospedaje.activo ?? true
        return Button {
            Task { await viewModel.alternarActivo() }
        } label: {
            VStack(spacing: 4) {
                if viewModel.alternandoActivo {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: activo ? "pause.circle" : "play.circle").font(.system(size: 18))
                }
                Text(activo ? "Pausar" : "Reactivar").phText(PHFont.micro.weight(.semibold))
            }
            .foregroundStyle(activo ? PHColor.muted : PHColor.success)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.alternandoActivo)
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
