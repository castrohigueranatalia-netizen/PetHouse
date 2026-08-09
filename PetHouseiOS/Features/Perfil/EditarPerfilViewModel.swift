//
//  EditarPerfilViewModel.swift
//  Features/Perfil
//
//  🔴 `PATCH /api/auth/me` no existe hoy (ver `PerfilService`). Este ViewModel funciona
//  contra el contrato propuesto; al recibir `AppError.rutaNoImplementada` no lo trata como
//  un error genérico: `guardado` queda en `.pendienteBackend`, y la vista muestra el
//  estado informativo correspondiente en vez de un mensaje de error rojo.
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

        // La foto se sube primero (si el usuario eligió una) — también pendiente hoy.
        if fotoPreview != nil {
            do {
                _ = try await imagenesService.subir(datos: fotoPreview!, nombreArchivo: "perfil.jpg", mimeType: "image/jpeg")
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
                fotoUrl: nil
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
        guard let item = fotoSeleccionada else { return }
        fotoPreview = try? await item.loadTransferable(type: Data.self)
    }
}
