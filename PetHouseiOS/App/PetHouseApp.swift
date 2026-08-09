//
//  PetHouseApp.swift
//  App
//
//  Punto de entrada. Crea el `ModelContainer` de SwiftData una sola vez, construye el
//  `SessionStore` y arranca la verificación de sesión guardada en Keychain antes de
//  mostrar la primera pantalla real (ver `RootView`).
//
//  TODO v1.1: registrar el device token para push (ver README — decisión de producto:
//  sin notificaciones push del servidor en v1, no se pide el permiso).
//

import SwiftUI
import SwiftData

@main
struct PetHouseApp: App {
    @State private var sessionStore = SessionStore()
    private let modelContainer = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .modelContainer(modelContainer)
                .task {
                    sessionStore.configurar(modelContext: modelContainer.mainContext)
                    let store = sessionStore
                    await APIClient.shared.setOnSessionExpired {
                        await store.sesionExpiroForzosamente()
                    }
                    await sessionStore.iniciar()
                }
        }
    }
}
