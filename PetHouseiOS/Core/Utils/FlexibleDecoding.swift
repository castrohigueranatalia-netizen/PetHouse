//
//  FlexibleDecoding.swift
//  Core/Utils
//
//  Por qué existe este archivo (léelo antes de tocar los modelos de Core/Models):
//  el driver de Postgres que usa la API (`node-postgres`/`pg`) devuelve por defecto las
//  columnas `NUMERIC`/`DECIMAL` como STRINGS en el JSON, no como números — es un
//  comportamiento conocido de esa librería para no perder precisión decimal, y
//  `pethouse-api/src/config.js` no sobreescribe ese parser. Eso afecta a `precio_noche`,
//  `rating`, `total`, `limpieza`, `servicio`, `monto`, `peso_kg` y `distancia_m` (esta
//  última via `ROUND()`, que en Postgres también produce `numeric`).
//
//  No hay forma de confirmarlo 100% sin correr la API real contra una base de datos
//  (no disponible en este entorno de desarrollo), así que en vez de asumir un tipo fijo
//  y arriesgar un crash de decodificación en producción, estos modelos decodifican esos
//  campos de forma DEFENSIVA: aceptan tanto `"123.45"` (string) como `123.45` (number).
//  Ver ARCHITECTURE_AUDIT.md — no está documentado ahí porque es un detalle de
//  serialización del driver, no de la API en sí; se deja registrado aquí como el punto
//  único de verdad de esta decisión.
//

import Foundation

public extension KeyedDecodingContainer {

    /// Decodifica un campo numérico que puede llegar como `String` o como `Double`/`Int`.
    /// Lanza si la clave existe pero no se puede interpretar como número.
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        let raw = try decode(String.self, forKey: key)
        guard let value = Double(raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "No se pudo interpretar '\(raw)' como número."
            )
        }
        return value
    }

    /// Variante opcional: `nil` si la clave no existe o su valor es `null`.
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeFlexibleDouble(forKey: key)
    }

    /// Igual que `decodeFlexibleDouble`, pero para enteros — necesario para columnas
    /// `COUNT(*)` (tipo `BIGINT`/OID 20 en Postgres), que `node-postgres` también
    /// devuelve como `String` por defecto (mismo motivo que `NUMERIC`, ver el comentario
    /// de arriba). Hoy el único campo así en la API es `no_leidos` en
    /// `GET /api/conversaciones` (ver `pethouse-api/src/routes/chat.js`).
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        let raw = try decode(String.self, forKey: key)
        guard let value = Int(raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "No se pudo interpretar '\(raw)' como entero."
            )
        }
        return value
    }
}
