//
//  AppDelegate.swift
//  App
//
//  Puente mínimo de UIKit para recibir el device token de Apple — SwiftUI no tiene un
//  equivalente propio de `didRegisterForRemoteNotificationsWithDeviceToken`, así que se
//  conecta vía `@UIApplicationDelegateAdaptor` en PetHouseApp.swift. También hace de
//  `UNUserNotificationCenterDelegate` para saber cuándo el anfitrión TOCA un recordatorio
//  local de "publica una actualización" (ver Core/Utils/RecordatoriosEstadia.swift) — sin
//  fijar este delegate, tocar una notificación local solo trae la app al frente, sin avisarle
//  al código qué se tocó.
//
//  Sin la capacidad "Push Notifications" habilitada en Xcode (Signing & Capabilities) —
//  algo que requiere una cuenta de pago de Apple Developer Program — el registro
//  simplemente falla con un error esperado (ver `didFailToRegisterForRemoteNotifications`
//  abajo): no rompe nada, no crashea. Apenas se habilite esa capacidad, el flujo completo
//  empieza a funcionar sin tocar más código. Esto NO afecta las notificaciones LOCALES
//  (recordatorios de estadía): esas no necesitan ninguna capacidad especial ni certificado.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// `PetHouseApp` fija este closure para reenviar el token a `SessionStore`, que a su
    /// vez lo manda al servidor (ver `SessionStore.registrarTokenPush(_:)`).
    static var onTokenRecibido: ((String) -> Void)?

    /// `PetHouseApp` fija este closure para abrir directo la pantalla de publicar una
    /// actualización (ver `SessionStore.reservaIdParaPublicarActualizacion` y `MainTabView`
    /// en RootView.swift) cuando el anfitrión toca el recordatorio de las 2 horas.
    static var onRecordatorioTocado: ((String) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

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

    /// Se llama al tocar CUALQUIER notificación mientras la app está en primer plano o
    /// segundo plano — local (recordatorio de estadía) o remota. Solo actúa sobre las que
    /// traen `reservaId` en su `userInfo` (ver `RecordatoriosEstadia.programar`); cualquier
    /// otra (hoy no hay remotas de verdad, ver ADR-7) simplemente no hace nada acá.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let reservaId = response.notification.request.content.userInfo["reservaId"] as? String {
            Self.onRecordatorioTocado?(reservaId)
        }
        completionHandler()
    }

    /// Sin esto, una notificación local que dispara mientras la app YA está abierta en
    /// primer plano no se muestra (comportamiento por defecto de iOS) — el anfitrión nunca
    /// vería el recordatorio si tenía la app abierta justo en ese momento.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
