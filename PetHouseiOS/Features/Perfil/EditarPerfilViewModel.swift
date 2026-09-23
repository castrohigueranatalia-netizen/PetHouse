//
//  EditarPerfilViewModel.swift
//  Features/Perfil
//
//  `PATCH /api/auth/me` y `POST /api/subidas` (ver `PerfilService`/`ImagenesService`) ya
//  existen en el backend. Se conserva el manejo de `AppError.rutaNoImplementada` como
//  respaldo defensivo (por si se apunta a un backend más viejo sin estas rutas): `guardado`
//  queda en `.pendienteBackend` y la vista muestra el estado informativo correspondiente en
//  vez de un mensaje de error rojo, en lugar de fingir un éxito que no ocurrió.
//

import Foundation
import PhotosUI
import SwiftUI

@MainActor
@Observable
public final class EditarPerfilViewModel {
    public enum ResultadoGuardado: Equatable {
        case ninguno
        case exito
        case pendienteBackend
        case error(String)
    }

    public var nombre: String
    public var telefono: String
    // `@ObservationIgnored`: sin esto, el macro de `@Observable` puede perder de vista el
    // `import PhotosUI` al expandirse sobre una propiedad de un tipo externo con `didSet`
    // ("Cannot find type 'PhotosPickerItem' in scope" aunque el import esté ahí arriba —
    // visto en la práctica en VerificarIdentidadViewModel, mismo patrón). La UI no necesita
    // observar este valor en sí, reacciona a `fotoPreview`, que sí está bajo observación.
    @ObservationIgnored
    public var fotoSeleccionada: PhotosPickerItem? {
        didSet { Task { await procesarFotoSeleccionada() } }
    }
    public private(set) var fotoPreview: Data?

    public private(set) var isLoading = false
    public private(set) var resultado: ResultadoGuardado = .ninguno
    public private(set) var errorNombre: String?

    private let perfilService: PerfilServicing
    private let imagenesService: ImagenesServicing
    private let session: SessionStore

    public init(
        session: SessionStore, perfilService: PerfilServicing = PerfilService(),
        imagenesService: ImagenesServicing = ImagenesService()
    ) {
        self.session = session
        self.nombre = session.usuario?.nombre ?? ""
        self.telefono = session.usuario?.telefono ?? ""
        self.perfilService = perfilService
        self.imagenesService = imagenesService
    }

    public func guardar() async {
        errorNombre = PHValidacion.nombre(nombre)
        guard errorNombre == nil else { return }

        isLoading = true
        resultado = .ninguno
        defer { isLoading = false }

        // La foto se sube primero (si el usuario eligió una): PATCH /auth/me guarda la URL
        // que devuelve POST /api/subidas, no los bytes de la imagen.
        var fotoUrl: String?
        if let datos = fotoPreview {
            do {
                fotoUrl = try await imagenesService.subir(datos: datos, nombreArchivo: "perfil.jpg", mimeType: "image/jpeg")
            } catch let appError as AppError where appError.esFuncionPendiente {
                resultado = .pendienteBackend
                return
            } catch {
                resultado = .error((error as? AppError)?.localizedDescription ?? error.localizedDescription)
                return
            }
        }

        do {
            _ = try await perfilService.editarPerfil(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                telefono: telefono.isEmpty ? nil : telefono,
                fotoUrl: fotoUrl
            )
            resultado = .exito
            await session.refrescarPerfilCompleto()
        } catch let appError as AppError where appError.esFuncionPendiente {
            resultado = .pendienteBackend
        } catch let appError as AppError {
            resultado = .error(appError.localizedDescription)
        } catch {
            resultado = .error(error.localizedDescription)
        }
    }

    private func procesarFotoSeleccionada() async {
        guard let item = fotoSeleccionada, let datos = try? await item.loadTransferable(type: Data.self) else { return }
        // Comprimida desde ya: es lo mismo que se sube Y lo que se muestra en el preview
        // (ver `guardar()`) — evita cargar en memoria/subir una foto de cámara sin editar.
        fotoPreview = ImagenComprimida.comprimir(datos)
    }
}
