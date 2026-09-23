//
//  BuscarView.swift
//  Features/Search
//

import SwiftUI

/// Mide cuánto se ha bajado en el `ScrollView` que contiene `encabezado` (ver
/// `BuscarView.body`) — un marcador de altura cero justo antes del encabezado, y se lee
/// su posición vertical relativa al scroll. En reposo vale 0; baja a números negativos a
/// medida que se hace scroll (mismo valor absoluto que lo que se ha bajado en puntos).
private struct DesplazamientoScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
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
    /// `true` apenas se ha bajado lo suficiente — activa `barraCompacta` (ver
    /// `.onPreferenceChange` abajo). Empieza en `false`: recién entrando a la pantalla (o
    /// apenas se inicia sesión) siempre se ve el encabezado completo primero, sin nada
    /// superpuesto.
    @State private var mostrarBarraCompacta = false
    /// Referencia al scroll para poder subir hasta arriba al tocar la barra compacta (ver
    /// `barraCompacta`) — se guarda apenas `ScrollViewReader` la entrega, no se puede leer
    /// directo desde otra parte del árbol de vistas.
    @State private var scrollProxy: ScrollViewProxy?

    /// Cuánto hay que bajar (en puntos) antes de que aparezca la barra compacta — un valor
    /// chico a propósito: la idea es que se sienta como que la búsqueda "se encoge" apenas
    /// empiezas a bajar, no que primero desaparezca todo y recién después, al final, salga
    /// la lupa. No depende de la altura real del encabezado.
    private let umbralCompacta: CGFloat = PHSpacing.s64
    private let anclaEncabezado = "encabezado"

    var body: some View {
        // `ZStack`, no `.safeAreaInset` — `barraCompacta` va SUPERPUESTA arriba del scroll
        // (no reserva su propio espacio fijo empujando el contenido hacia abajo). Con
        // `.safeAreaInset` cada vez que aparecía/desaparecía cambiaba el alto disponible del
        // `ScrollView` y el scroll daba un salto brusco justo al mismo tiempo que se intentaba
        // mostrar algo — se sentía como que "todo desaparecía" en vez de encogerse. Superpuesta,
        // el listado de hospedajes sigue subiendo por detrás/debajo de ella sin ningún salto.
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DesplazamientoScrollKey.self,
                                        value: geo.frame(in: .named("buscarScroll")).minY
                                    )
                                }
                            )

                        encabezado
                            .id(anclaEncabezado)

                        contenido
                    }
                }
                .coordinateSpace(name: "buscarScroll")
                .refreshable { await viewModel.buscar() }
                .onAppear { scrollProxy = proxy }
            }

            if mostrarBarraCompacta {
                // Tocarla sube de nuevo hasta el encabezado (en vez de abrir un selector
                // propio, que sería una cuarta forma más de buscar además de las 3 filas del
                // encabezado).
                barraCompacta {
                    withAnimation { scrollProxy?.scrollTo(anclaEncabezado, anchor: .top) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onPreferenceChange(DesplazamientoScrollKey.self) { minY in
            let compacta = minY < -umbralCompacta
            guard compacta != mostrarBarraCompacta else { return }
            withAnimation(.easeInOut(duration: 0.2)) { mostrarBarraCompacta = compacta }
        }
        // El degradado coral vive ACÁ, como fondo de TODA la pantalla ignorando el área
        // segura, no como `.background` de `encabezado`. Puesto en el encabezado (que vive
        // adentro del `ScrollView`) no alcanzaba a subir por detrás de la barra de
        // navegación: quedaba blanco arriba del logo/campana y rosado justo debajo, con una
        // línea marcando el corte. Desde acá el color arranca en el borde de arriba de la
        // pantalla y baja de forma continua, sin corte — la barra de navegación, con su
        // fondo oculto (ver `.toolbarBackground` abajo), lo deja ver por detrás.
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                PHColor.canvas
                LinearGradient(
                    colors: [PHColor.primary.opacity(0.07), PHColor.primary.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 320)
            }
            .ignoresSafeArea()
        }
        // Sin texto: el saludo de `encabezado` ya cumple el rol de título de la pantalla
        // (ver mockup "idea 6" de la barra de búsqueda) — un "Buscar" repetido justo encima
        // sería redundante.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Sin esto, la barra de navegación (donde están el logo y la campana) pinta su
        // propio fondo blanco/opaco, tapando el degradado de arriba y volviendo a marcar el
        // corte de color que este arreglo justamente elimina.
        .toolbarBackground(.hidden, for: .navigationBar)
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
                // Emoji "📍" a color tal cual, no el ícono monocromo de siempre — mismo
                // tamaño/círculo que `PHIconButton`, pero ese componente solo admite un
                // SF Symbol (que sale siempre en `PHColor.ink`), así que este botón va
                // aparte en vez de forzarlo a aceptar algo que no es.
                Button {
                    mostrarMapa = true
                } label: {
                    Text("📍")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                        .background(PHColor.surfaceSoft)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Ver en el mapa")
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
    /// especie y contador de contexto. Ver el mockup "idea 6" de la barra de búsqueda
    /// (versión final acordada). Vive DENTRO del `ScrollView` (no fija arriba) a propósito —
    /// así se puede medir cuándo deja de verse para mostrar `barraCompacta` en su lugar (ver
    /// `body`). SIN fondo propio: el degradado coral lo pinta el fondo de toda la pantalla
    /// (ver el `.background` de `body`), para que arranque arriba del todo y no se vea un
    /// corte de color justo debajo de la barra de navegación.
    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 0) {
            saludo
            barraBusqueda
            chipsEspecie
            contadorContexto
        }
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
                    icono: "pawprint", etiqueta: "¿Comparte con otras mascotas?",
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
    /// para medir cuánto se ha bajado, ver `DesplazamientoScrollKey`).
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
