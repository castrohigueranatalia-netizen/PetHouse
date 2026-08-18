//
//  AppDelegate.swift
//  App
//
//  Puente mínimo de UIKit para recibir el device token de Apple — SwiftUI no tiene un
//  equivalente propio de `didRegisterForRemoteNotificationsWithDeviceToken`, así que se
//  conecta vía `@UIApplicationDelegateAdaptor` en PetHouseApp.swift.
//
//  Sin la capacidad "Push Notifications" habilitada en Xcode (Signing & Capabilities) —
//  algo que requiere una cuenta de pago de Apple Developer Program — el registro
//  simplemente falla con un error esperado (ver `didFailToRegisterForRemoteNotifications`
//  abajo): no rompe nada, no crashea. Apenas se habilite esa capacidad, el flujo completo
//  empieza a funcionar sin tocar más código.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// `PetHouseApp` fija este closure para reenviar el token a `SessionStore`, que a su
    /// vez lo manda al servidor (ver `SessionStore.registrarTokenPush(_:)`).
    static var onTokenRecibido: ((String) -> Void)?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Self.onTokenRecibido?(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Esperado mientras no haya cuenta de pago de Apple Developer / capacidad Push
        // Notifications habilitada — no es un error real de la app.
        print("No se pudo registrar para notificaciones push (esperado sin la capacidad habilitada): \(error.localizedDescription)")
    }
}
