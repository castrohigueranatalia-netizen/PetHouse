//
//  VerificacionAnfitrionViewModel.swift
//  Features/Anfitrion
//
//  Paso 1 de "convertirse en anfitrión": datos de seguridad obligatorios (nombre legal,
//  cédula, certificado de antecedentes, fotos de la persona y de la vivienda; referencias
//  opcionales). Al enviarse con éxito, el servidor activa `Usuario.esAnfitrion` — no hay
//  otro camino para lograrlo (ver pethouse-api/src/routes/anfitrion.js). Sigue el paso 2
//  (`PreferenciasAnfitrionViewModel`).
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

    public var puedeEnviar: Bool {
        !nombreLegal.trimmingCharacters(in: .whitespaces).isEmpty
            && !cedula.trimmingCharacters(in: .whitespaces).isEmpty
            && !certificadoPolicialUrl.isEmpty
            && !fotosPersonaUrls.isEmpty
            && !fotosViviendaUrls.isEmpty
            && !isLoading
    }

    /// Pasado a cada `PHAdjuntarFotos` — sube el archivo y devuelve la URL, o `nil` si falla
    /// (la vista ya muestra su propio mensaje de error en ese caso).
    public func subirFoto(_ datos: Data) async -> String? {
        try? await imagenesService.subir(datos: datos, nombreArchivo: "adjunto.jpg", mimeType: "image/jpeg")
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
            // El servidor ya activó es_anfitrion=true — refresca la sesión para que
            // Usuario.esAnfitrion se actualice localmente (habilita la pestaña Anfitrión).
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
