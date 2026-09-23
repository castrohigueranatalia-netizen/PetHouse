//
//  PetHouseApp.swift
//  App
//
//  Punto de entrada. Crea el `ModelContainer` de SwiftData una sola vez, construye el
//  `SessionStore` y arranca la verificación de sesión guardada en Keychain antes de
//  mostrar la primera pantalla real (ver `RootView`).
//
//  Notificaciones push: el permiso se pide desde `MainTabView` (ver RootView.swift), NO
//  acá — pedirlo en este `.task`, antes de que la ventana esté completamente visible, hacía
//  que el diálogo del sistema no se mostrara bien y la app pareciera congelada en el
//  arranque (mismo principio que el resto de permisos del proyecto: se piden justo antes de
//  usarse, nunca al abrir la app). Acá solo se prepara el puente del device token — ver
//  `AppDelegate.swift` y `SessionStore.registrarTokenPush(_:)`.
//

import SwiftUI
import SwiftData

@main
struct PetHouseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var sessionStore = SessionStore()
    private let modelContainer = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .modelContainer(modelContainer)
                // La app se ve siempre en modo claro, sin importar el modo del sistema del
                // iPhone (Ajustes → Pantalla y brillo) — decisión de producto, no un olvido:
                // el diseño ya soporta modo oscuro (ver `Color.dynamic` en PHColor.swift),
                // así que revertirlo es solo quitar esta línea.
                .preferredColorScheme(.light)
                .task {
                    sessionStore.configurar(modelContext: modelContainer.mainContext)
                    let store = sessionStore
                    await APIClient.shared.setOnSessionExpired {
                        await store.sesionExpiroForzosamente()
                    }
                    AppDelegate.onTokenRecibido = { token in
                        Task { @MainActor in store.registrarTokenPush(token) }
                    }
                    AppDelegate.onRecordatorioTocado = { reservaId in
                        Task { @MainActor in store.reservaIdParaPublicarActualizacion = reservaId }
                    }
                    await sessionStore.iniciar()
                }
        }
    }
}
