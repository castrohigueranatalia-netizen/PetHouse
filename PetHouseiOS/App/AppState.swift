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

    private let authService: AuthServicing
    private let keychain: KeychainStoring
    private var modelContext: ModelContext?

    public init(authService: AuthServicing = AuthService(), keychain: KeychainStoring = KeychainStore.shared) {
        self.authService = authService
        self.keychain = keychain
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
        aplicarPerfil(respuesta.usuario, mascotas: [], desdeCache: false)
        estado = .autenticado
        Task { await refrescarPerfilCompleto() }
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
        aplicarPerfil(respuesta.usuario, mascotas: [], desdeCache: false)
        estado = .autenticado
        Task { await refrescarPerfilCompleto() }
    }

    public func cerrarSesion() async {
        if let refresh = keychain.leer(.refreshToken) {
            try? await authService.logout(refreshToken: refresh)
        }
        keychain.borrarTodo()
        usuario = nil
        mascotas = []
        perfilEsDeCache = false
        estado = .invitado
        borrarCache()
    }

    /// Llamado por `APIClient` cuando un refresh de token falla definitivamente.
    public func sesionExpiroForzosamente() async {
        keychain.borrarTodo()
        usuario = nil
        mascotas = []
        estado = .invitado
    }

    /// Refresca `usuario`/`mascotas` con datos frescos del servidor sin bloquear la UI de
    /// login (se llama en segundo plano después de autenticar).
    public func refrescarPerfilCompleto() async {
        guard let respuesta = try? await authService.me() else { return }
        aplicarPerfil(respuesta.usuario, mascotas: respuesta.mascotas, desdeCache: false)
    }

    // MARK: - Privado

    private func aplicarPerfil(_ usuario: Usuario, mascotas: [Mascota], desdeCache: Bool) {
        self.usuario = usuario
        self.mascotas = mascotas
        self.perfilEsDeCache = desdeCache
        if !desdeCache {
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
