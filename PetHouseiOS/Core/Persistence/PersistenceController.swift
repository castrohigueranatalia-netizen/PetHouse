//
//  PersistenceController.swift
//  Core/Persistence
//
//  Punto único de creación del `ModelContainer` de SwiftData. Se instancia una vez en
//  `PetHouseApp` y se inyecta como `.modelContainer(...)` — el resto de la app accede a
//  su `ModelContext` vía `@Environment(\.modelContext)`, como es idiomático en SwiftUI.
//

import Foundation
import SwiftData

public enum PersistenceController {
    /// Esquema con los dos modelos de caché offline del MVP (perfil y reservas).
    public static func makeContainer() -> ModelContainer {
        let schema = Schema([UsuarioCache.self, ReservaCache.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Si el store en disco está corrupto (ej. tras una migración fallida), se
            // arranca en memoria en vez de crashear: el usuario pierde la caché offline
            // pero la app sigue siendo usable con red.
            print("⚠️ No se pudo abrir el store de SwiftData en disco, se usa uno en memoria: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))!
        }
    }
}
