//
//  BuscarView.swift
//  Features/Search
//

import SwiftUI

/// Mide dónde termina `encabezado` respecto al `ScrollView` que lo contiene (ver
/// `BuscarView.body`) — cuando ese borde inferior sube más allá de `distanciaCompacta`,
/// el encabezado grande (saludo + tarjeta de búsqueda + chips) ya no se ve, así que se
/// cambia a la barra compacta fija arriba. `defaultValue` alto a propósito: antes de la
/// primera medición real (un instante, al aparecer la vista) no debe parpadear a "compacta".
private struct DesplazamientoEncabezadoKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BuscarView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = BuscarViewModel()
    @State private var favoritosViewModel = FavoritosViewModel()
    @State private var mostrarSelectorLocalidad = false
    @State private var mostrarSelectorFechas = false
    @State private var mostrarSelectorConvivencia = false
    @State private var mostrarFiltros = false
    @State private var mostrarMapa = false
    @State private var mostrarNotificaciones = false
    @State private var mostrarMisHospedajes = false
    @State private var hospedajeSeleccionado: Hospedaje?
    /// `true` en cuanto `encabezado` deja de verse por scroll — activa `barraCompacta` (ver
    /// `.onPreferenceChange` abajo). Empieza en `false`: recién entrando a la pantalla (o
    /// apenas se inicia sesión) siempre se ve el encabezado completo primero.
    @State private var mostrarBarraCompacta = false

    /// Distancia (desde arriba del `ScrollView`) a la que el encabezado se considera "ya no
    /// visible" — un pequeño margen en vez de 0 para que la barra compacta aparezca justo
    /// cuando el encabezado grande termina de salir, no un instante después.
    private let distanciaCompacta: CGFloat = PHSpacing.s24
    private let anclaEncabezado = "encabezado"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    encabezado
                        .id(anclaEncabezado)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: DesplazamientoEncabezadoKey.self,
                                    value: geo.frame(in: .named("buscarScroll")).maxY
                                )
                            }
                        )

                    contenido
                }
            }
            .coordinateSpace(name: "buscarScroll")
            .refreshable { await viewModel.buscar() }
            .onPreferenceChange(DesplazamientoEncabezadoKey.self) { maxY in
                let compacta = maxY < distanciaCompacta
                guard compacta != mostrarBarraCompacta else { return }
                withAnimation(.easeInOut(duration: 0.2)) { mostrarBarraCompacta = compacta }
            }
            // Barra compacta fija arriba, SOLO mientras el encabezado grande no se ve — al
            // tocarla, sube de nuevo hasta el encabezado (en vez de abrir un selector propio,
            // que sería una cuarta forma más de buscar además de las 3 filas de abajo).
            .safeAreaInset(edge: .top, spacing: 0) {
                if mostrarBarraCompacta {
                    barraCompacta {
                        withAnimation { proxy.scrollTo(anclaEncabezado, anchor: .top) }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .background(PHColor.canvas)
        // Sin texto: el saludo de `encabezado` ya cumple el rol de título de la pantalla
        // (ver mockup "idea 6" de la barra de búsqueda) — un "Buscar" repetido justo encima
        // sería redundante.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // El logo es el botón de "inicio": ya estando en Buscar, vuelve al listado
                // completo (cierra cualquier hospedaje abierto) — ver el `onChange` abajo.
                Button { session.volverABuscar = true } label: {
                    PHLogo(height: 28)
                }
                .accessibilityLabel("Ir al listado de hospedajes")
            }
            ToolbarItem(placement: .topBarTrailing) {
                PHIconButton(systemImage: "map", accessibilityLabel: "Ver en el mapa") {
                    mostrarMapa = true
                }
            }
            // Solo para cuentas con la capacidad de anfitrión activa (ver
            // db/06-verificacion-anfitrion.sql) — acceso rápido a "Mis hospedajes" desde el
            // inicio, sin tener que entrar a Perfil. NO es una pestaña propia a propósito
            // (ver el comentario largo en App/RootView.swift sobre el bug de la pestaña
            // "Más" de iOS con más de 4 pestañas).
            if session.usuario?.esAnfitrion == true {
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "house", accessibilityLabel: "Mis hospedajes") {
                        mostrarMisHospedajes = true
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                PHCampanaNotificaciones(noLeidas: session.notificacionesNoLeidas) {
                    mostrarNotificaciones = true
                }
            }
        }
        // `.fullScreenCover`, no `.sheet` — esta vista ya encadena varios `.sheet(isPresented:)`
        // distintos (localidad, fechas, convivencia, filtros, mapa); uno más ahí mismo cae en
        // el mismo riesgo de presentación poco confiable que ya se vio antes en Perfil.
        // `.fullScreenCover` es un mecanismo de presentación aparte, sin ese conflicto.
        .fullScreenCover(isPresented: $mostrarNotificaciones) {
            NotificacionesView()
        }
        // `.fullScreenCover`, no `.sheet` — mismo motivo que `mostrarNotificaciones` arriba.
        // `MisHospedajesView` no trae su propio `NavigationStack` (normalmente vive empujada
        // dentro del de Perfil, ver PerfilView) — acá se le da uno propio, igual que con
        // `MapaView`.
        .fullScreenCover(isPresented: $mostrarMisHospedajes) {
            NavigationStack {
                MisHospedajesView()
            }
        }
        // Cada fila de `barraBusqueda` abre su PROPIO selector — no un formulario combinado
        // con los 3 campos juntos — para llegar directo a elegir sin un paso intermedio.
        .sheet(isPresented: $mostrarSelectorLocalidad) {
            SelectorLocalidadSheet(viewModel: viewModel) {
                Task { await viewModel.buscar() }
            }
        }
        .sheet(isPresented: $mostrarSelectorFechas) {
            SelectorFechasBusquedaSheet(viewModel: viewModel) {
                Task { await viewModel.buscar() }
            }
        }
        .sheet(isPresented: $mostrarSelectorConvivencia) {
            SelectorConvivenciaSheet(viewModel: viewModel) {
                Task { await viewModel.buscar() }
            }
        }
        .sheet(isPresented: $mostrarFiltros) {
            FiltrosView(viewModel: viewModel) {
                Task { await viewModel.buscar() }
            }
        }
        .sheet(isPresented: $mostrarMapa) {
            NavigationStack {
                MapaView()
            }
        }
        .navigationDestination(item: $hospedajeSeleccionado) { hospedaje in
            HospedajeDetailView(hospedajeId: hospedaje.id)
        }
        .task {
            if viewModel.resultados.isEmpty { await viewModel.buscar() }
        }
        // Consume la señal del botón de inicio (ver AppState.swift): cierra el hospedaje
        // abierto y cualquier hoja modal, para que "volver" muestre de verdad el listado
        // completo y no lo que hubiera quedado abierto en este stack.
        .onChange(of: session.volverABuscar) { _, volver in
            guard volver else { return }
            hospedajeSeleccionado = nil
            mostrarSelectorLocalidad = false
            mostrarSelectorFechas = false
            mostrarSelectorConvivencia = false
            mostrarFiltros = false
            mostrarMapa = false
            // El logo dentro de `MisHospedajesView` (ver su propio toolbar) también dispara
            // esta misma señal — así tocarlo cierra este `fullScreenCover` de una vez, sin
            // necesitar un botón "Cerrar" aparte que compitiera por el mismo lugar del
            // toolbar con el logo que esa vista ya trae.
            mostrarMisHospedajes = false
            session.volverABuscar = false
        }
    }

    /// Zona de cabecera completa: saludo + huella, barra de búsqueda, chips rápidos de
    /// especie y contador de contexto, sobre un degradado sutil coral → blanco. Ver el
    /// mockup "idea 6" de la barra de búsqueda (versión final acordada). Vive DENTRO del
    /// `ScrollView` (no fija arriba) a propósito — así se puede medir cuándo deja de verse
    /// para mostrar `barraCompacta` en su lugar (ver `body`).
    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 0) {
            saludo
            barraBusqueda
            chipsEspecie
            contadorContexto
        }
        .background(
            LinearGradient(
                colors: [PHColor.primary.opacity(0.07), PHColor.primary.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    /// "¡Hola, [nombre]! ¿Quién va a cuidar tu mascota hoy?" con una huella decorativa en
    /// medallón — reemplaza el antiguo título plano "Buscar" por algo más cálido y propio
    /// de la marca.
    private var saludo: some View {
        HStack(alignment: .top, spacing: PHSpacing.s12) {
            ZStack {
                Circle().fill(PHColor.primaryContainer)
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(PHColor.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(saludoTexto)
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text("¿Quién va a cuidar tu mascota hoy?")
                    .phText(PHFont.bodySM, color: PHColor.muted)
            }
        }
        .padding(.horizontal, PHSpacing.s20)
        .padding(.top, PHSpacing.s16)
        .padding(.bottom, PHSpacing.s16)
    }

    private var saludoTexto: String {
        guard let primerNombre = session.usuario?.nombre.split(separator: " ").first else {
            return "¡Hola!"
        }
        return "¡Hola, \(primerNombre)!"
    }

    /// Barra principal: localidad + fechas + convivencia, como 3 filas SIEMPRE visibles
    /// dentro de una misma tarjeta — mismo espíritu que el buscador de Airbnb (Dónde/Fechas/
    /// Quién a la vista desde el principio). En escritorio Airbnb las pone una al lado de la
    /// otra porque tiene ancho de sobra; en un iPhone no entran así, así que acá van
    /// apiladas. Cada fila lleva DIRECTO a su propio selector (`SelectorLocalidadSheet`,
    /// `SelectorFechasBusquedaSheet`, `SelectorConvivenciaSheet`) — tocar "Dónde" muestra
    /// solo la lista de localidades, tocar "Fechas" abre el calendario de una, y tocar "Con
    /// quién más" muestra solo esas opciones, sin pasar por un formulario combinado. "Filtros"
    /// (tipo, orden, cerca de mí) queda aparte, como opciones secundarias, igual que antes.
    private var barraBusqueda: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            HStack {
                Spacer()
                // Solo aparece si hay algo elegido (localidad/fechas/convivencia) — quita esa
                // selección y vuelve a buscar en toda Bogotá sin tener que abrir nada.
                if viewModel.hayBusquedaActiva {
                    PHIconButton(systemImage: "xmark.circle.fill", accessibilityLabel: "Quitar selección de búsqueda") {
                        viewModel.limpiarFiltros()
                        Task { await viewModel.buscar() }
                    }
                }
                PHIconButton(systemImage: "line.3.horizontal.decrease.circle", accessibilityLabel: "Más filtros") {
                    mostrarFiltros = true
                }
            }

            VStack(spacing: 0) {
                filaBusqueda(
                    icono: "mappin.and.ellipse", etiqueta: "Dónde",
                    valor: viewModel.localidad?.etiqueta ?? "Toda Bogotá"
                ) {
                    mostrarSelectorLocalidad = true
                }
                Divider().padding(.leading, PHSpacing.s48)
                filaBusqueda(
                    icono: "calendar", etiqueta: "Fechas",
                    valor: viewModel.usarFechas
                        ? "\(PHDate.displayShort.string(from: viewModel.desde)) – \(PHDate.displayShort.string(from: viewModel.hasta))"
                        : "Cualquier fecha"
                ) {
                    mostrarSelectorFechas = true
                }
                Divider().padding(.leading, PHSpacing.s48)
                filaBusqueda(
                    icono: "pawprint", etiqueta: "Con quién más",
                    valor: (viewModel.convivencia ?? .cualquiera).etiqueta
                ) {
                    mostrarSelectorConvivencia = true
                }
            }
            .background(PHColor.canvas)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
            .phShadow(PHShadow.level2)
        }
        .padding(.horizontal, PHSpacing.s20)
    }

    /// Una fila de `barraBusqueda` — icono + etiqueta chica arriba, valor actual abajo.
    /// `accion` abre el selector específico de ese campo (ver `barraBusqueda`).
    private func filaBusqueda(icono: String, etiqueta: String, valor: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: PHSpacing.s12) {
                Image(systemName: icono)
                    .foregroundStyle(PHColor.primary)
                    .frame(width: PHSpacing.s20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(etiqueta)
                        .phText(PHFont.captionSM, color: PHColor.muted)
                    Text(valor)
                        .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, PHSpacing.s16)
            .padding(.vertical, PHSpacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(etiqueta): \(valor)")
    }

    /// Barra fija que reemplaza a `encabezado` mientras se hace scroll hacia abajo (ver
    /// `mostrarBarraCompacta`) — solo una lupa y el resumen de la búsqueda actual, para no
    /// perder toda esa altura mientras se mira la lista. Tocarla sube de nuevo hasta el
    /// encabezado completo en vez de abrir un selector — las 3 filas de ahí arriba siguen
    /// siendo la única forma de cambiar Dónde/Fechas/Con quién.
    private func barraCompacta(alTocar: @escaping () -> Void) -> some View {
        Button(action: alTocar) {
            HStack(spacing: PHSpacing.s8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PHColor.primary)
                Text(viewModel.resumenBusqueda)
                    .phText(PHFont.bodySM.weight(.semibold), color: PHColor.ink)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, PHSpacing.s20)
            .padding(.vertical, PHSpacing.s12)
            .background(PHColor.canvas)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityLabel("Buscar hospedaje: \(viewModel.resumenBusqueda)")
        .accessibilityHint("Sube hasta el buscador completo")
    }

    /// Chips rápidos de especie — filtro real (ver `BuscarViewModel.alternarEspecie`), no
    /// decorativo: tocar uno vuelve a buscar contra el servidor filtrando por lo que el
    /// anfitrión declaró cuidar. Se muestran los dos (a diferencia del mockup, que por ser
    /// una imagen estática solo mostraba la opción ya elegida) para poder tocar el que no
    /// está seleccionado y cambiar de especie.
    private var chipsEspecie: some View {
        HStack(spacing: PHSpacing.s8) {
            ForEach(EspecieCuidado.allCases) { especie in
                PHChip(especie.etiqueta, isSelected: viewModel.especie == especie) {
                    viewModel.alternarEspecie(especie)
                }
            }
        }
        .padding(.horizontal, PHSpacing.s20)
        .padding(.top, PHSpacing.s12)
    }

    /// "27 hospedajes en Bogotá" — contexto inmediato del tamaño del resultado, junto a la
    /// barra de búsqueda en vez de solo al final del listado.
    @ViewBuilder
    private var contadorContexto: some View {
        if !viewModel.isLoading {
            Text(contadorTexto)
                .phText(PHFont.captionSM, color: PHColor.muted)
                .padding(.horizontal, PHSpacing.s20)
                .padding(.top, PHSpacing.s12)
                .padding(.bottom, PHSpacing.s8)
        }
    }

    private var contadorTexto: String {
        let cantidad = viewModel.totalCargados
        let lugar = viewModel.localidad?.etiqueta ?? "Bogotá"
        return "\(cantidad) hospedaje\(cantidad == 1 ? "" : "s") en \(lugar)"
    }

    /// Ya NO trae su propio `ScrollView` — vive dentro del `ScrollView` único de `body`,
    /// justo debajo de `encabezado`, para que ambos compartan el mismo scroll (necesario
    /// para medir cuándo `encabezado` deja de verse, ver `DesplazamientoEncabezadoKey`).
    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading && viewModel.resultados.isEmpty {
            PHLoadingStateView(mensaje: "Buscando hospedajes…")
        } else if let error = viewModel.error {
            PHErrorStateView(error: error) {
                Task { await viewModel.buscar() }
            }
        } else if viewModel.resultados.isEmpty {
            PHEmptyStateView(
                systemImage: "magnifyingglass",
                titulo: "Sin resultados",
                mensaje: "Prueba con otra localidad, tipo de hospedaje o quita algunos filtros.",
                accionTitulo: "Limpiar filtros"
            ) {
                viewModel.limpiarFiltros()
                Task { await viewModel.buscar() }
            }
        } else {
            LazyVStack(spacing: PHSpacing.s16) {
                ForEach(viewModel.resultados) { hospedaje in
                    Button {
                        hospedajeSeleccionado = hospedaje
                    } label: {
                        PHHospedajeCard(
                            hospedaje,
                            esFavorito: favoritosViewModel.esFavorito(hospedaje.id),
                            mostrarPrecioDia: viewModel.busquedaMismoDia,
                            onToggleFavorito: {
                                Task { await favoritosViewModel.alternar(hospedaje) }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear { viewModel.cargarMasSiHaceFalta(elementoActual: hospedaje) }
                }

                if viewModel.cargandoMas {
                    ProgressView()
                        .padding(.vertical, PHSpacing.s16)
                }
            }
            .padding(PHSpacing.s16)
        }
    }
}
