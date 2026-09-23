//
//  VerificacionAnfitrionViewModel.swift
//  Features/Anfitrion
//
//  Paso 1 de "convertirse en anfitrión": datos de seguridad obligatorios (nombre legal,
//  cédula, certificado de antecedentes, fotos de la persona y de la vivienda; referencias
//  opcionales). Al enviarse, queda 'pendiente' — activar `Usuario.esAnfitrion` requiere que
//  un administrador la apruebe (ver pethouse-api/src/routes/anfitrion.js). Sigue el paso 2
//  (`PreferenciasAnfitrionViewModel`).
//
//  Antes de mostrar el formulario, `cargarEstadoActual()` revisa si YA existe una solicitud
//  'pendiente' o 'aprobado' — el servidor rechaza reenviar en esos casos (409), así que acá
//  se evita dejar que alguien llene todo el formulario para toparse con ese error al final.
//  Solo 'rechazado' (o ninguna solicitud todavía) deja ver el formulario.
//

import Foundation

@MainActor
@Observable
public final class VerificacionAnfitrionViewModel {
    public var nombreLegal = ""
    public var cedula = ""
    public var certificadoPolicialUrl: [String] = []   // máx. 1 (ver `maximo` en la vista)
    public var referenciasUrls: [String] = []
    public var fotosPersonaUrls: [String] = []
    public var fotosViviendaUrls: [String] = []

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorNombre: String?
    public private(set) var errorCedula: String?
    public private(set) var enviado = false

    /// `nil` mientras se revisa; después, la solicitud existente si hay una — ver
    /// `cargarEstadoActual()`. `VerificacionAnfitrionView` usa `bloqueadaPorSolicitudActiva`
    /// para decidir si mostrar el formulario o un aviso.
    public private(set) var cargandoEstado = true
    public private(set) var verificacionExistente: VerificacionAnfitrion?

    public var bloqueadaPorSolicitudActiva: Bool {
        verificacionExistente?.estado == .pendiente || verificacionExistente?.estado == .aprobado
    }

    private let anfitrionService: AnfitrionServicing
    private let imagenesService: ImagenesServicing
    private let session: SessionStore

    public init(
        session: SessionStore,
        anfitrionService: AnfitrionServicing = AnfitrionService(),
        imagenesService: ImagenesServicing = ImagenesService()
    ) {
        self.session = session
        self.anfitrionService = anfitrionService
        self.imagenesService = imagenesService
        self.nombreLegal = session.usuario?.nombre ?? ""
    }

    /// Se llama al abrir la pantalla, antes de mostrar el formulario — silencioso a
    /// propósito si falla (sin conexión, etc.): si no se puede confirmar el estado, se deja
    /// ver el formulario igual (el servidor es la verdad final y de todos modos valida esto
    /// otra vez al enviar).
    public func cargarEstadoActual() async {
        cargandoEstado = true
        defer { cargandoEstado = false }
        verificacionExistente = try? await anfitrionService.obtenerVerificacion()
    }

    public var puedeEnviar: Bool {
        !nombreLegal.trimmingCharacters(in: .whitespaces).isEmpty
            && !cedula.trimmingCharacters(in: .whitespaces).isEmpty
            && !certificadoPolicialUrl.isEmpty
            && !fotosPersonaUrls.isEmpty
            && !fotosViviendaUrls.isEmpty
            && !isLoading
    }

    /// Pasado a cada `PHAdjuntarFotos` — sube el archivo y devuelve la URL, o `nil` si falla
    /// (la vista ya muestra su propio mensaje de error en ese caso). `privado: true`: esta
    /// es la única pantalla que sube cédula/antecedentes/fotos de verificación — el
    /// servidor las guarda separadas de las fotos públicas (ver ImagenesService.swift).
    public func subirFoto(_ datos: Data) async -> String? {
        try? await imagenesService.subir(datos: datos, nombreArchivo: "adjunto.jpg", mimeType: "image/jpeg", privado: true)
    }

    public func enviar() async {
        errorGeneral = nil
        guard validar() else { return }

        isLoading = true
        defer { isLoading = false }

        let payload = EnviarVerificacionRequest(
            nombreLegal: nombreLegal.trimmingCharacters(in: .whitespaces),
            cedula: cedula.trimmingCharacters(in: .whitespaces),
            certificadoPolicialUrl: certificadoPolicialUrl[0],
            referencias: referenciasUrls,
            fotosPersona: fotosPersonaUrls,
            fotosVivienda: fotosViviendaUrls
        )

        do {
            _ = try await anfitrionService.enviarVerificacion(payload)
            // La solicitud queda 'pendiente' — esto NO activa Usuario.esAnfitrion todavía
            // (eso solo pasa cuando un admin la aprueba, ver AppState.
            // revisarResolucionVerificacion). Igual se refresca la sesión acá para mantener
            // el resto del perfil en caché al día.
            await session.refrescarPerfilCompleto()
            enviado = true
        } catch let appError as AppError {
            errorGeneral = appError.localizedDescription
        } catch {
            errorGeneral = error.localizedDescription
        }
    }

    private func validar() -> Bool {
        errorNombre = nombreLegal.trimmingCharacters(in: .whitespaces).count >= 3
            ? nil : "Ingresa tu nombre legal completo."
        errorCedula = cedula.trimmingCharacters(in: .whitespaces).count >= 5
            ? nil : "Ingresa un número de cédula válido."
        if certificadoPolicialUrl.isEmpty { errorGeneral = "Adjunta tu certificado de antecedentes policiales." }
        else if fotosPersonaUrls.isEmpty { errorGeneral = "Adjunta al menos una foto tuya." }
        else if fotosViviendaUrls.isEmpty { errorGeneral = "Adjunta al menos una foto del lugar donde vives." }
        return errorNombre == nil && errorCedula == nil && errorGeneral == nil
    }
}
