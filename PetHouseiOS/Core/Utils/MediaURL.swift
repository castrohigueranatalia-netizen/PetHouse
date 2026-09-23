//
//  MediaURL.swift
//  Core/Utils
//
//  La API devuelve fotos de dos formas:
//   - Rutas relativas ("/semilla/g1.jpg"): las fotos de ejemplo en db/02-seed.sql, servidas
//     por pethouse-api en /semilla (ver src/app.js). Antes eran nombres sueltos sin sentido
//     como "guarderia-1" (resabio del prototipo HTML, que los resolvía con JS local) — no
//     apuntaban a ninguna imagen real desde un cliente nativo.
//   - URLs absolutas ("http://.../uploads/xxx.jpg"): fotos subidas de verdad vía
//     POST /api/subidas, que ya devuelve la URL completa (ver ImagenesService).
//  Este helper normaliza ambos casos antes de pasarle un string a PHCachedAsyncImage.
//
//  Vive en Core (no en Networking) porque DesignSystem necesita resolver estas URLs para
//  armar cards de hospedaje/avatares (ver PHHospedajeCard, PHAvatar) sin depender de la
//  capa de red — Core es la base sin dependencias que ambas capas comparten.
//

import Foundation

public enum MediaURL {
    /// Duplica intencionalmente la lectura de Info.plist de `Networking/APIConfig.baseURL`
    /// (mismo valor, capa distinta — ver el porqué arriba). Si cambia la clave de Info.plist
    /// (`API_BASE_URL`, ver project.yml), hay que actualizar ambos lugares.
    private static var baseURL: String {
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !fromPlist.isEmpty, !fromPlist.hasPrefix("$(") {
            return fromPlist
        }
        return "http://localhost:3001"
    }

    /// `nil`/vacío → `nil` (para que `PHCachedAsyncImage` muestre su placeholder).
    /// Ya absoluta (`http://`/`https://`) → se devuelve tal cual.
    /// Relativa → se antepone `baseURL` (la raíz del servidor, no `/api`).
    public static func resolver(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return raw }
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let path = raw.hasPrefix("/") ? raw : "/\(raw)"
        return base + path
    }
}
