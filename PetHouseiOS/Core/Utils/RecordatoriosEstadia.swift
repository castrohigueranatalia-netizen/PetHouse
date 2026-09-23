//
//  RecordatoriosEstadia.swift
//  Core/Utils
//
//  Recordatorio LOCAL (no push remoto — funciona sin configurar APNs, ver
//  SessionStore.solicitarPermisoPush) que le pide al anfitrión, cada 2 horas MIENTRAS una
//  reserva está 'confirmada' y la estadía está en curso (hoy cae entre `desde` y `hasta`),
//  publicar una actualización de la mascota (ver ActualizacionesReservaView /
//  db/38-actualizaciones-reserva.sql). Se sincroniza en los mismos momentos que el resto de
//  los avisos del anfitrión — ver `SessionStore.sincronizarRecordatoriosEstadia()`.
//
//  Local y no remoto a propósito: un recordatorio periódico ("cada 2 horas") no depende de
//  que el servidor esté corriendo un job en segundo plano (esta API no tiene ninguno, ver
//  completarReservasVencidas() — se revisa al leer, no con un cron) ni de tener APNs
//  configurado — el propio sistema operativo del anfitrión dispara el aviso en el horario
//  programado, incluso con la app cerrada.
//

import Foundation
import UserNotifications

public enum RecordatoriosEstadia {
    private static let prefijo = "ph-recordatorio-estadia-"
    private static let dosHoras: TimeInterval = 2 * 60 * 60

    private static func identificador(_ reservaId: String) -> String { "\(prefijo)\(reservaId)" }

    /// `true` si HOY cae dentro de la estadía de una reserva 'confirmada' — el único momento
    /// en que tiene sentido pedirle al anfitrión una actualización: antes de `desde` la
    /// mascota ni ha llegado, y desde `hasta` en adelante ya se fue (o la reserva ya pasó a
    /// 'completada', ver completarReservasVencidas() en el servidor).
    private static func enCurso(_ reserva: Reserva) -> Bool {
        guard reserva.estado == .confirmada,
              let desdeTexto = reserva.desde, let hastaTexto = reserva.hasta,
              let desde = PHDate.apiDateOnly.date(from: desdeTexto),
              let hasta = PHDate.apiDateOnly.date(from: hastaTexto) else { return false }
        let hoy = Calendar.current.startOfDay(for: .now)
        return hoy >= Calendar.current.startOfDay(for: desde) && hoy < hasta
    }

    private static func programar(_ reserva: Reserva) {
        let contenido = UNMutableNotificationContent()
        contenido.title = "¿Cómo va la mascota?"
        let lugar = reserva.hospedajeTitulo.map { " en \($0)" } ?? ""
        contenido.body = "Publica una foto o nota de la estadía\(lugar) para que el huésped la vea."
        contenido.sound = .default
        contenido.userInfo = ["reservaId": reserva.id]

        // `repeats: true` con 2 horas — el mínimo que acepta iOS para un intervalo repetido
        // es 60 segundos, así que 2h entra sin problema. Un solo request programado dispara
        // indefinidamente cada 2 horas hasta que se cancela (ver `sincronizar`), no hace
        // falta reprogramarlo a mano cada vez.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: dosHoras, repeats: true)
        let request = UNNotificationRequest(identifier: identificador(reserva.id), content: contenido, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Revisa TODAS las reservas del anfitrión y sincroniza los recordatorios: programa los
    /// que faltan para las reservas en curso, y cancela los que ya no aplican (la estadía
    /// terminó, se canceló/rechazó, o su fecha todavía no llega). No reprograma los que YA
    /// estaban activos — sin eso, cada vez que el anfitrión abre la app se reiniciaría el
    /// conteo de 2 horas y el aviso nunca terminaría de dispararse si abre la app seguido.
    public static func sincronizar(_ reservas: [Reserva]) async {
        let centro = UNUserNotificationCenter.current()
        let pendientes = await centro.pendingNotificationRequests()
        let idsPropiosPendientes = Set(pendientes.map(\.identifier).filter { $0.hasPrefix(prefijo) })

        let idsQueDeberianExistir = Set(reservas.filter(enCurso).map { identificador($0.id) })

        let aCancelar = idsPropiosPendientes.subtracting(idsQueDeberianExistir)
        if !aCancelar.isEmpty {
            centro.removePendingNotificationRequests(withIdentifiers: Array(aCancelar))
        }

        for reserva in reservas where enCurso(reserva) {
            guard !idsPropiosPendientes.contains(identificador(reserva.id)) else { continue }
            programar(reserva)
        }
    }
}
