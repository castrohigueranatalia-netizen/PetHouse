//
//  PetHouseApp.swift
//  App
//
//  Punto de entrada. Crea el `ModelContainer` de SwiftData una sola vez, construye el
//  `SessionStore` y arranca la verificación de sesión guardada en Keychain antes de
//  mostrar la primera pantalla real (ver `RootView`).
//
//  Notificaciones push: se pide el permiso y se registra el dispositivo apenas arranca
//  (ver `AppDelegate.swift` y `SessionStore.solicitarPermisoPush()`/`registrarTokenPush(_:)`).
//  Sin la capacidad "Push Notifications" habilitada en Xcode (requiere cuenta de pago de
//  Apple Developer Program), el registro falla de forma esperada y silenciosa — el resto
//  de la app funciona igual.
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
                    await sessionStore.iniciar()
                    await sessionStore.solicitarPermisoPush()
                }
        }
    }
}
