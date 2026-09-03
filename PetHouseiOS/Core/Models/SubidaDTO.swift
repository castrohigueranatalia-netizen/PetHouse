//
//  SubidaDTO.swift
//  Core/Models
//
//  🔴 No existe endpoint de subida de imágenes en el backend hoy (gap BLOQUEANTE #1 en
//  ARCHITECTURE_AUDIT.md §6). `POST /api/hospedajes` recibe `fotos` como array de strings
//  (URLs ya alojadas en otro storage), y no hay forma de subir foto de perfil ni de
//  mascota. Contrato propuesto (multipart/form-data, no JSON):
//
//   POST /api/subidas   (form field "archivo", requiere auth)
//        → 201 { url: "https://.../archivo.jpg" }
//
//  `PerfilService`/`MascotasService`/`AnfitrionService` llaman a esta ruta antes de
//  guardar; al recibir 404 de ruta inexistente, la UI muestra "función pendiente en el
//  servidor" en vez de simular una URL falsa como si la subida hubiera funcionado.
//

import Foundation

public struct SubidaImagenResponse: Codable {
    public let url: String
}
