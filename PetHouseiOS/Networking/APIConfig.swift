//
//  APIConfig.swift
//  Networking
//
//  URL base de la API. Se lee de Info.plist (clave `API_BASE_URL`, ver project.yml, que a
//  su vez la resuelve del build setting `API_BASE_URL`) para poder cambiarla por
//  configuración/xcconfig sin recompilar código Swift — por ejemplo apuntando a un backend
//  desplegado en vez de `http://localhost:3001`. Si la clave falta o no es una URL válida,
//  se usa el default de desarrollo.
//
//  Regla de capas: este archivo NO importa SwiftUI — Networking es independiente de UI.
//

import Foundation

public enum APIConfig {
    /// Default de desarrollo: `pethouse-api` corriendo localmente (`npm start`, puerto 3001
    /// por defecto según `pethouse-api/src/config.js`).
    private static let defaultBaseURL = "http://localhost:3001"

    public static var baseURL: URL {
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !fromPlist.isEmpty, !fromPlist.hasPrefix("$("), // valor sin resolver en algunos entornos de preview
           let url = URL(string: fromPlist) {
            return url
        }
        return URL(string: defaultBaseURL)!
    }

    /// Todas las rutas reales cuelgan de `/api` (ver `pethouse-api/src/app.js`).
    public static var apiBaseURL: URL {
        baseURL.appendingPathComponent("api")
    }
}
