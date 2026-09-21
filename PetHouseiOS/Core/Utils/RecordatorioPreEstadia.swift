//
//  RecordatorioPreEstadia.swift
//  Core/Utils
//
//  Recordatorio LOCAL (mismo mecanismo que RecordatoriosEstadia — sin push remoto, no
//  depende de APNs ni de un job en el servidor) que avisa al anfitrión LA TARDE ANTERIOR a
//  que empiece una estadía 'confirmada', para que revise que todo esté listo antes de que
//  llegue la mascota. Se sincroniza en los mismos momentos que RecordatoriosEstadia — ver
//  SessionStore.sincronizarRecordatoriosEstadia().
//

import Foundation
import UserNotifications

public enum RecordatorioPreEstadia {
    private static let prefijo = "ph-recordatorio-pre-estadia-"
    /// 6pm del día anterior — bastante tarde para que la mascota probablemente ya no llegue
    /// ese mismo día si `desde` es mañana, bastante temprano para todavía poder preparar algo.
    private static let horaAviso = (hora: 18, minuto: 0)

    private static func identificador(_ reservaId: String) -> String { "\(prefijo)\(reservaId)" }

    /// La fecha/hora exacta en que debería dispararse: las 6pm del día anterior a `desde`.
    /// `nil` si esa fecha ya pasó (no tiene sentido programar un recordatorio para el pasado)
    /// o si la reserva no aplica (no confirmada, o sin `desde`).
    private static func momentoAviso(_ reserva: Reserva) -> Date? {
        guard reserva.estado == .confirmada,
              let desdeTexto = reserva.desde,
              let desde = PHDate.apiDateOnly.date(from: desdeTexto) else { return nil }
        let calendario = Calendar.current
        guard let vispera = calendario.date(byAdding: .day, value: -1, to: desde) else { return nil }
        var componentes = calendario.dateComponents([.year, .month, .day], from: vispera)
        componentes.hour = horaAviso.hora
        componentes.minute = horaAviso.minuto
        guard let momento = calendario.date(from: componentes), momento > .now else { return nil }
        return momento
    }

    private static func programar(_ reserva: Reserva, en momento: Date) {
        let contenido = UNMutableNotificationContent()
        contenido.title = "Mañana te llega una mascota"
        let quien = reserva.usuarioNombre.map { "\($0) y su mascota llegan" } ?? "Una mascota llega"
        let lugar = reserva.hospedajeTitulo.map { " a \($0)" } ?? ""
        contenido.body = "\(quien) mañana\(lugar) — revisa que todo esté listo para recibirla."
        contenido.sound = .default
        // Clave DISTINTA a "reservaId" a propósito: `AppDelegate.didReceive` reacciona a esa
        // clave abriendo `ActualizacionesReservaView` (publicar foto/nota DURANTE la
        // estadía, ver RecordatoriosEstadia) — este aviso es de ANTES de que empiece, así
        // que tocarlo no debe abrir esa pantalla. Simplemente abre la app donde haya quedado.
        contenido.userInfo = ["reservaIdPreEstadia": reserva.id]

        let componentes = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: momento)
        let trigger = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
        let request = UNNotificationRequest(identifier: identificador(reserva.id), content: contenido, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Mismo patrón que `RecordatoriosEstadia.sincronizar`: programa los que faltan,
    /// cancela los que ya no aplican (se canceló/rechazó la reserva, o `desde` cambió). No
    /// reprograma los que ya estaban pendientes con el mismo momento — evita golpear la API
    /// de notificaciones en cada apertura de la app sin necesidad.
    public static func sincronizar(_ reservas: [Reserva]) async {
        let centro = UNUserNotificationCenter.current()
        let pendientes = await centro.pendingNotificationRequests()
        let idsPropiosPendientes = Set(pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) })

        var porProgramar: [(Reserva, Date)] = []
        var idsQueDeberianExistir: Set<String> = []
        for reserva in reservas {
            guard let momento = momentoAviso(reserva) else { continue }
            idsQueDeberianExistir.insert(identificador(reserva.id))
            if !idsPropiosPendientes.contains(identificador(reserva.id)) {
                porProgramar.append((reserva, momento))
            }
        }

        let aCancelar = idsPropiosPendientes.subtracting(idsQueDeberianExistir)
        if !aCancelar.isEmpty {
            centro.removePendingNotificationRequests(withIdentifiers: Array(aCancelar))
        }

        for (reserva, momento) in porProgramar {
            programar(reserva, en: momento)
        }
    }
}
