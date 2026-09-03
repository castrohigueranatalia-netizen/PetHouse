//
//  AppError.swift
//  Core/Utils
//
//  Error unificado de la app. El backend siempre responde `{ "error": "mensaje en
//  español" }` en fallos (ver ARCHITECTURA_AUDIT.md §5) — ese mensaje ya es apto para
//  mostrar directo en UI, así que `AppError.servidor` lo transporta tal cual.
//

import Foundation

public enum AppError: Error, Equatable, LocalizedError, Sendable {
    /// El servidor respondió con un error de negocio/validación: `{ "error": "..." }`.
    /// `status` es el código HTTP recibido, útil para decidir el tratamiento (401, 409...).
    case servidor(status: Int, mensaje: String)

    /// La ruta no existe en el backend actual (404 de una ruta, no de un recurso).
    /// Se usa para distinguir "esta función aún no existe en el servidor" de un 404
    /// legítimo de recurso no encontrado — ver `APIClient` y los Services "pendiente backend".
    case rutaNoImplementada

    /// No se pudo decodificar la respuesta esperada (contrato inesperado del backend).
    case decodificacion

    /// Sin conexión / timeout / DNS / servidor inalcanzable.
    case sinConexion

    /// La sesión expiró y el refresh también falló: hay que volver a iniciar sesión.
    case sesionExpirada

    /// Error genérico no clasificado (con la causa original para depurar en consola).
    case desconocido(String)

    public var errorDescription: String? {
        switch self {
        case .servidor(_, let mensaje):
            return mensaje
        case .rutaNoImplementada:
            return "Esta función estará disponible pronto."
        case .decodificacion:
            return "No pudimos leer la respuesta del servidor. Intenta de nuevo."
        case .sinConexion:
            return "No hay conexión a internet. Revisa tu red e intenta de nuevo."
        case .sesionExpirada:
            return "Tu sesión expiró. Inicia sesión de nuevo."
        case .desconocido(let detalle):
            return detalle
        }
    }

    /// `true` cuando el error representa una funcionalidad que el backend actual no
    /// soporta todavía (ver MVP_SCOPE.md §3.C) — las vistas deben mostrar un estado
    /// informativo, nunca fingir éxito ni mostrar un error genérico feo.
    public var esFuncionPendiente: Bool {
        self == .rutaNoImplementada
    }
}
