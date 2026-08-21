//
//  VerificarIdentidadViewModel.swift
//  Features/Auth
//
//  Respaldo de "olvidé mi contraseña" cuando el código por correo no llega: sube una foto
//  de la cédula sin sesión. Un admin la revisa y, si corresponde, genera un PIN — el
//  usuario vuelve a la pantalla del código (ver OlvidePasswordView) y lo escribe ahí, no en
//  una pantalla aparte.
//

import Foundation
import PhotosUI

@MainActor
@Observable
public final class VerificarIdentidadViewModel {
    public let email: String

    // `@ObservationIgnored`: sin esto, el macro de `@Observable` a veces pierde de vista el
    // `import PhotosUI` al expandirse sobre una propiedad de un tipo externo con `didSet`,
    // y Xcode marca "Cannot find type 'PhotosPickerItem' in scope" aunque el import esté
    // ahí arriba (visto en la práctica). No hace falta que SwiftUI observe este valor en sí
    // — la UI reacciona a `fotoPreview`, que sí está bajo observación.
    @ObservationIgnored
    public var fotoSeleccionada: PhotosPickerItem? {
        didSet { Task { await cargarFoto() } }
    }
    public private(set) var fotoPreview: Data?

    public private(set) var isLoading = false
    public private(set) var enviado = false
    public private(set) var error: AppError?

    private let authService: AuthServicing

    public init(email: String, authService: AuthServicing = AuthService()) {
        self.email = email
        self.authService = authService
    }

    public var puedeEnviar: Bool { fotoPreview != nil && !isLoading }

    private func cargarFoto() async {
        guard let item = fotoSeleccionada, let datos = try? await item.loadTransferable(type: Data.self) else { return }
        fotoPreview = ImagenComprimida.comprimir(datos)
    }

    public func enviar() async {
        guard let datos = fotoPreview else { return }
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.subirIdentidadRecuperacion(
                email: email, datos: datos, nombreArchivo: "cedula.jpg", mimeType: "image/jpeg"
            )
            enviado = true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
