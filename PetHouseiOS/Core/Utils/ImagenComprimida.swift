//
//  ImagenComprimida.swift
//  Core/Utils
//
//  Comprime una foto (de PhotosPicker, típicamente varios MB sin editar) antes de subirla
//  o de mostrarla en un preview local — decodifica directo a un tamaño reducido vía
//  ImageIO (no decodifica la imagen original completa para luego achicarla) y reexporta en
//  JPEG. Compartido por PHAdjuntarFotos (DesignSystem) y EditarPerfilViewModel (Features)
//  para no duplicar la misma lógica — vive en Core porque ambas capas ya dependen de Core.
//

import Foundation
import ImageIO
import UIKit

public enum ImagenComprimida {
    /// Si algo falla al decodificar (formato raro), devuelve los datos originales tal
    /// cual en vez de perder la foto — mejor subir/mostrar algo pesado que nada.
    public static func comprimir(_ datos: Data, maxDimensionPixels: CGFloat = 1600, calidad: CGFloat = 0.7) -> Data {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(datos as CFData, sourceOptions as CFDictionary) else { return datos }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimensionPixels)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return datos }

        return UIImage(cgImage: cgImage).jpegData(compressionQuality: calidad) ?? datos
    }
}
