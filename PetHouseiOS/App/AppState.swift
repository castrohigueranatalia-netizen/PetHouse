//
//  AppState.swift
//  App
//
//  `SessionStore` es la única fuente de verdad de "quién está logueado" — vive en la raíz
//  de la app (`PetHouseApp`) y se inyecta vía `@Environment` a todo el árbol de vistas.
//  Usa `@Observable` (Swift Observation) en vez de `ObservableObject`/`@Published`, igual
//  que el resto de ViewModels del MVP (ver README → decisiones de arquitectura).
//
//  Responsabilidades:
//   - Verificar al arrancar si hay una sesión guardada en Keychain y validarla contra
//     `GET /api/auth/me`; si no hay red, cae a la caché SwiftData (`UsuarioCache`).
//   - Login/registro/logout, delegando la llamada HTTP a `AuthService`.
//   - Reaccionar cuando `APIClient` avisa que el refresh token falló (sesión expirada de
//     verdad, no solo "sin red") cerrando la sesión localmente.
//

import Foundation
import SwiftData

@MainActor
@Observable
public final class SessionStore {
    public enum Estado: Equatable {
        case verificando
        case autenticado
        case invitado
    }

    public private(set) var estado: Estado = .verificando
    public private(set) var usuario: Usuario?
    public private(set) var mascotas: [Mascota] = []
    /// `true` cuando el perfil mostrado viene de la caché offline, no de una respuesta
    /// fresca del servidor — las vistas pueden usarlo para mostrar un aviso sutil.
    public private(set) var perfilEsDeCache = false

    /// Señal para continuar directo a la verificación de anfitrión justo después de un
    /// registro con "También quiero ofrecer hospedaje" marcado. Necesaria porque en cuanto
    /// `estado` pasa a `.autenticado`, `RootView` reemplaza TODO el stack de navegación del
    /// login/registro por `MainTabView` — cualquier navegación programada desde dentro de
    /// `RegistroView` se perdería, así que se coordina acá en vez de ahí. `MainTabView`
    /// selecciona la pestaña Perfil al ver esto en `true`, y `PerfilView` la consume
    /// empujando `VerificacionAnfitrionView` (ver `.navigationDestination(isPresented:)` en
    /// ambas vistas).
    public var abrirVerificacionAlEntrar = false

    /// Señal de "volver al listado de hospedajes" — el logo en cada pestaña la activa (ver
    /// las vistas de cada pestaña) para funcionar como botón de inicio. `MainTabView` la usa
    /// para saltar a la pestaña Buscar; `BuscarView` la usa ADEMÁS para cerrar cualquier
    /// hospedaje que hubiera quedado abierto en su propio stack de navegación (cambiar de
    /// pestaña y volver no resetea eso solo — `NavigationStack` conserva su estado). Cada
    /// consumidor la apaga después de reaccionar, así que no importa el orden en que la vean.
    public var volverABuscar = false

    /// Cuántos mensajes sin leer tiene el usuario en total (suma de `no_leidos` de todas
    /// sus conversaciones) y, si es admin, cuántas solicitudes de anfitrión están
    /// pendientes. `MainTabView` los muestra como badge en las pestañas Mensajes/Admin. No
    /// hay push notifications (ADR-7 lo difiere a fase 2), así que esto se actualiza por
    /// polling puntual — ver `actualizarContadores()`.
    public private(set) var mensajesNoLeidos = 0
    public private(set) var solicitudesPendientes = 0

    /// `!= nil` cuando la solicitud de anfitrión acaba de resolverse (aprobada o
    /// rechazada) y el usuario todavía no lo vio. Se revisa al arrancar la sesión/loguearse/
    /// registrarse (ver `revisarResolucionVerificacion()`) — vive acá, no en un ViewModel de
    /// una pantalla puntual, para que `MainTabView` pueda mostrar el aviso apenas se entra a
    /// la app, sea cual sea la pestaña que se abra primero, en vez de solo si el usuario
    /// llega a visitar el Perfil. `marcarResolucionVista()` lo apaga.
    public private(set) var resolucionVerificacion: VerificacionAnfitrion?

    /// Solicitudes de reserva resueltas (aceptadas o rechazadas) que el huésped todavía no
    /// vio, en cola — puede haber más de una si el anfitrión resolvió varias entre una
    /// sesión y otra. `MainTabView` muestra un aviso por cada una, una a la vez (ver
    /// `revisarResolucionesReserva()`/`marcarResolucionReservaVista()`), mismo patrón que
    /// `resolucionVerificacion` arriba.
    public private(set) var resolucionesReserva: [Reserva] = []

    /// Solicitudes de reserva NUEVAS (huéspedes que acaban de pedir reservar) que el
    /// anfitrión todavía no vio, en cola — mismo patrón que `resolucionesReserva`, pero en
    /// la otra dirección (ver `revisarSolicitudesNuevasAnfitrion()`). Solo tiene contenido
    /// si `usuario?.esAnfitrion == true`; para un huésped que no es anfitrión, el servidor
    /// simplemente no tiene ningún hospedaje suyo con solicitudes que devolver.
    public private(set) var solicitudesNuevasAnfitrion: [Reserva] = []

    /// Reserva que `MainTabView` debe abrir en la pestaña Reservas al tocar "Ver reserva" en
    /// el aviso de solicitud nueva — ver `ReservasRecibidasView` y el comentario largo en
    /// `MisReservasView.swift`. Mismo mecanismo de "señal + consumo" que
    /// `abrirVerificacionAlEntrar`.
    public var reservaRecibidaParaAbrir: Reserva?

    private let authService: AuthServicing
    private let keychain: KeychainStoring
    private let chatService: ChatServicing
    private let adminService: AdminServicing
    private let anfitrionService: AnfitrionServicing
    private let reservasService: ReservasServicing
    private var modelContext: ModelContext?

    public init(
        authService: AuthServicing = AuthService(),
        keychain: KeychainStoring = KeychainStore.shared,
        chatService: ChatServicing = ChatService(),
        adminService: AdminServicing = AdminService(),
        anfitrionService: AnfitrionServicing = AnfitrionService(),
        reservasService: ReservasServicing = ReservasService()
    ) {
        self.authService = authService
        self.keychain = keychain
        self.chatService = chatService
        self.adminService = adminService
        self.anfitrionService = anfitrionService
        self.reservasService = reservasService
    }

    /// Se llama una vez desde `PetHouseApp` cuando el `ModelContainer` ya está listo.
    public func configurar(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Arranque

    public func iniciar() async {
        guard keychain.leer(.accessToken) != nil else {
            estado = .invitado
            return
        }
        do {
            let respuesta = try await authService.me()
            aplicarPerfil(respuesta.usuario, mascotas: respuesta.mascotas, desdeCache: false)
            estado = .autenticado
            await actualizarContadores()
            await revisarResolucionVerificacion()
            await revisarResolucionesReserva()
            await revisarSolicitudesNuevasAnfitrion()
        } catch AppError.sesionExpirada {
            // El único caso que representa una sesión inválida de verdad: `APIClient` ya
            // intentó el refresh (ver APIClient.performWithRefresh) y también falló. Borrar
            // los tokens aquí es correcto porque ya no sirven.
            keychain.borrarTodo()
            estado = .invitado
        } catch {
            // Cualquier otro error (sin conexión, 5xx transitorio, respuesta inesperada del
            // servidor, etc.) NO significa que la sesión sea inválida — los tokens siguen
            // siendo válidos, solo no se pudo verificar el perfil ahora mismo. Cae a la
            // caché offline si existe, pero conserva los tokens para reintentar más tarde
            // en vez de forzar un logout por una falla momentánea del servidor.
            if let cache = leerCache() {
                aplicarPerfil(cache.comoUsuario, mascotas: cache.mascotas, desdeCache: true)
                estado = .autenticado
            } else {
                estado = .invitado
            }
        }
    }

    // MARK: - Auth

    public func login(email: String, password: String) async throws {
        let respuesta = try await authService.login(email: email, password: password)
        try guardarTokens(respuesta)
        // `guardarEnCache: false` — el guardado en SwiftData (disco) se difiere al Task de
        // abajo en vez de bloquear la transición a `.autenticado` justo después de tocar
        // "Iniciar sesión" (antes `aplicarPerfil` escribía en disco ANTES de esta línea,
        // lo cual se sentía como que la app se quedaba pensando un instante después de que
        // la respuesta del login ya había llegado). `refrescarPerfilCompleto()` guarda en
        // caché con datos más completos (mascotas reales) apenas unos milisegundos después,
        // así que no hace falta guardar dos veces.
        aplicarPerfil(respuesta.usuario, mascotas: [], desdeCache: false, guardarEnCache: false)
        estado = .autenticado
        Task {
            await refrescarPerfilCompleto()
            await actualizarContadores()
            await revisarResolucionVerificacion()
            await revisarResolucionesReserva()
            await revisarSolicitudesNuevasAnfitrion()
        }
    }

    public func registro(
        nombre: String, email: String, password: String, telefono: String?,
        rol: Usuario.Rol, mascotaNombre: String?
    ) async throws {
        let respuesta = try await authService.registro(
            nombre: nombre, email: email, password: password,
            telefono: telefono, rol: rol, mascotaNombre: mascotaNombre
        )
        try guardarTokens(respuesta)
        aplicarPerfil(respuesta.usuario, mascotas: [], desdeCache: false, guardarEnCache: false)
        estado = .autenticado
        Task {
            await refrescarPerfilCompleto()
            await actualizarContadores()
            await revisarResolucionVerificacion()
            await revisarResolucionesReserva()
            await revisarSolicitudesNuevasAnfitrion()
        }
    }

    public func cerrarSesion() async {
        if let refresh = keychain.leer(.refreshToken) {
            try? await authService.logout(refreshToken: refresh)
        }
        keychain.borrarTodo()
        usuario = nil
        mascotas = []
        perfilEsDeCache = false
        mensajesNoLeidos = 0
        solicitudesPendientes = 0
        resolucionVerificacion = nil
        resolucionesReserva = []
        solicitudesNuevasAnfitrion = []
        estado = .invitado
        borrarCache()
    }

    /// Llamado por `APIClient` cuando un refresh de token falla definitivamente.
    public func sesionExpiroForzosamente() async {
        keychain.borrarTodo()
        usuario = nil
        mascotas = []
        mensajesNoLeidos = 0
        solicitudesPendientes = 0
        resolucionVerificacion = nil
        resolucionesReserva = []
        solicitudesNuevasAnfitrion = []
        estado = .invitado
    }

    /// Refresca `usuario`/`mascotas` con datos frescos del servidor sin bloquear la UI de
    /// login (se llama en segundo plano después de autenticar).
    public func refrescarPerfilCompleto() async {
        guard let respuesta = try? await authService.me() else { return }
        aplicarPerfil(respuesta.usuario, mascotas: respuesta.mascotas, desdeCache: false)
    }

    /// Recalcula los contadores de los badges (mensajes sin leer, y solicitudes
    /// pendientes si es admin) pidiéndolos de nuevo al servidor. Solo para cuando de
    /// verdad no hay datos frescos a mano (arrancar la sesión, loguearse, registrarse) —
    /// las pantallas que YA tienen la lista de conversaciones o el nuevo conteo de
    /// solicitudes (porque acaban de pedirla para otra cosa) deben usar
    /// `actualizarMensajesNoLeidos`/`marcarConversacionLeida`/`actualizarSolicitudesPendientes`
    /// en su lugar — recalculan localmente, sin otra ida y vuelta de red.
    public func actualizarContadores() async {
        if let conversaciones = try? await chatService.conversaciones() {
            actualizarMensajesNoLeidos(desde: conversaciones)
        }
        guard usuario?.rol == .admin else { return }
        if let estadisticas = try? await adminService.estadisticas() {
            actualizarSolicitudesPendientes(estadisticas.solicitudesPendientes)
        }
    }

    /// Recalcula `mensajesNoLeidos` a partir de una lista de conversaciones que la pantalla
    /// que llama YA tiene fresca (ej. `ConversacionesView` justo después de cargarla) — sin
    /// pedirla de nuevo por red.
    public func actualizarMensajesNoLeidos(desde conversaciones: [Conversacion]) {
        mensajesNoLeidos = conversaciones.reduce(0) { $0 + ($1.noLeidos ?? 0) }
    }

    /// Descuenta del contador los mensajes que tenía sin leer `conversacion` — se llama
    /// justo después de marcarla como leída (ver `ChatDetailViewModel.iniciar()`), en vez
    /// de volver a pedir todas las conversaciones solo para recalcular una resta.
    public func marcarConversacionLeida(_ conversacion: Conversacion) {
        mensajesNoLeidos = max(0, mensajesNoLeidos - (conversacion.noLeidos ?? 0))
    }

    /// Fija `solicitudesPendientes` a un valor que la pantalla que llama YA calculó (ej.
    /// `AdminView` con la respuesta de `GET /admin/estadisticas` que acaba de pedir para
    /// mostrar las tarjetas, o `AdminSolicitudesView` restando uno tras resolver una).
    public func actualizarSolicitudesPendientes(_ n: Int) {
        solicitudesPendientes = n
    }

    /// Revisa si la solicitud de anfitrión del usuario se resolvió (aprobada o rechazada)
    /// sin que él se haya enterado todavía — se llama al arrancar la sesión/loguearse/
    /// registrarse (ver arriba), así `MainTabView` puede mostrar el aviso apenas se entra a
    /// la app. Silenciosa a propósito si falla (sin conexión, etc.): no vale la pena un
    /// error encima de la app recién abierta solo por esto.
    ///
    /// Si fue aprobada, además refresca el perfil (`usuario.esAnfitrion`) ANTES de mostrar
    /// el aviso — sin esto, la pestaña "Anfitrión" no aparecía en `MainTabView` hasta la
    /// próxima vez que algo más refrescara el perfil (ej. reabrir la app), aunque el aviso
    /// de "¡Solicitud aprobada!" ya estuviera en pantalla.
    public func revisarResolucionVerificacion() async {
        guard let verificacion = try? await anfitrionService.obtenerVerificacion() else { return }
        if verificacion.estado != .pendiente && !verificacion.notificado {
            resolucionVerificacion = verificacion
            if verificacion.estado == .aprobado {
                await refrescarPerfilCompleto()
            }
        }
    }

    /// Apaga el aviso y le avisa al servidor para que no vuelva a aparecer.
    public func marcarResolucionVista() async {
        resolucionVerificacion = nil
        try? await anfitrionService.marcarVerificacionNotificada()
    }

    /// Igual que `revisarResolucionVerificacion()`, pero para solicitudes de RESERVA que el
    /// anfitrión aceptó o rechazó — se llama en los mismos tres momentos (arrancar/loguearse/
    /// registrarse). A diferencia de la verificación (una por usuario), puede haber varias
    /// resueltas a la vez, así que se guardan en cola.
    public func revisarResolucionesReserva() async {
        guard let resueltas = try? await reservasService.resueltasSinNotificar(), !resueltas.isEmpty else { return }
        resolucionesReserva = resueltas
    }

    /// Apaga el aviso de la PRIMERA reserva en cola y le avisa al servidor — si quedan más,
    /// `MainTabView` vuelve a mostrar el aviso con la siguiente apenas esta se apaga.
    public func marcarResolucionReservaVista() async {
        guard let primera = resolucionesReserva.first else { return }
        resolucionesReserva.removeFirst()
        try? await reservasService.marcarNotificada(id: primera.id)
    }

    /// Revisa si le llegaron solicitudes de reserva NUEVAS que el anfitrión todavía no vio
    /// — dirección opuesta a `revisarResolucionesReserva()` (esa es "mi solicitud se
    /// resolvió"; esta es "me llegó una solicitud"). Solo tiene sentido pedirlo si la cuenta
    /// es anfitrión; para un huésped normal el servidor de todos modos no tendría nada que
    /// devolver, pero evitar la llamada de red innecesaria es gratis.
    public func revisarSolicitudesNuevasAnfitrion() async {
        guard usuario?.esAnfitrion == true else { return }
        guard let pendientes = try? await reservasService.pendientesSinNotificarAnfitrion(), !pendientes.isEmpty else { return }
        solicitudesNuevasAnfitrion = pendientes
    }

    /// Apaga el aviso de la PRIMERA solicitud nueva en cola y le avisa al servidor — mismo
    /// patrón que `marcarResolucionReservaVista()`.
    public func marcarSolicitudNuevaAnfitrionVista() async {
        guard let primera = solicitudesNuevasAnfitrion.first else { return }
        solicitudesNuevasAnfitrion.removeFirst()
        try? await reservasService.marcarNotificadaAnfitrion(id: primera.id)
    }

    // MARK: - Privado

    private func aplicarPerfil(_ usuario: Usuario, mascotas: [Mascota], desdeCache: Bool, guardarEnCache: Bool = true) {
        self.usuario = usuario
        self.mascotas = mascotas
        self.perfilEsDeCache = desdeCache
        if !desdeCache && guardarEnCache {
            guardarCache(usuario: usuario, mascotas: mascotas)
        }
    }

    private func guardarTokens(_ respuesta: AuthResponse) throws {
        try keychain.guardar(respuesta.accessToken, para: .accessToken)
        try keychain.guardar(respuesta.refreshToken, para: .refreshToken)
    }

    private func guardarCache(usuario: Usuario, mascotas: [Mascota]) {
        guard let modelContext else { return }
        // Un solo registro representa "el perfil actual": se limpia y se vuelve a insertar.
        (try? modelContext.fetch(FetchDescriptor<UsuarioCache>()))?.forEach(modelContext.delete)
        modelContext.insert(UsuarioCache(usuario: usuario, mascotas: mascotas))
        try? modelContext.save()
    }

    private func leerCache() -> UsuarioCache? {
        guard let modelContext else { return nil }
        return try? modelContext.fetch(FetchDescriptor<UsuarioCache>()).first
    }

    private func borrarCache() {
        guard let modelContext else { return }
        (try? modelContext.fetch(FetchDescriptor<UsuarioCache>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<ReservaCache>()))?.forEach(modelContext.delete)
        try? modelContext.save()
    }
}
