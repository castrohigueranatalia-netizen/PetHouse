//
//  PHCachedAsyncImage.swift
//  DesignSystem/Components
//
//  Cache de imágenes propio y minimalista (NSCache en memoria) envolviendo `AsyncImage`.
//  Decisión de arquitectura (ver README): para un MVP no se agrega una dependencia de
//  terceros como Kingfisher/SDWebImage vía SPM — reduce fricción de setup sin red/Xcode
//  disponible en desarrollo, y NSCache ya resuelve el caso de uso real (listas que se
//  desplazan hacia atrás y hacia adelante repitiendo las mismas fotos de hospedajes).
//  No persiste a disco: al reiniciar la app se vuelve a descargar. Suficiente para MVP.
//
//  Decodifica en tamaño reducido (ImageIO thumbnail, no `UIImage(data:)` a full res) —
//  antes de esto, una foto de cámara de varios MB se decodificaba entera en memoria solo
//  para mostrarse en un círculo de 44pt o una miniatura de 72-120pt, lo cual es carísimo en
//  CPU/memoria y una causa real de lentitud al hacer scroll en pantallas con varias fotos
//  (listados de hospedajes, galerías de verificación de anfitrión). Ver WWDC "Image and
//  Graphics Best Practices" — es el patrón recomendado por Apple para este caso.
//

import SwiftUI
import UIKit
import ImageIO

/// Cache en memoria compartido de imágenes ya descargadas, indexado por URL.
final class PHImageCache {
    static let shared = PHImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200 // suficiente para varias pantallas de listados con fotos
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }

    /// Descarga y decodifica una imagen por adelantado, dejándola lista en cache — para
    /// "precalentar" fotos que se van a mostrar pronto (ver `AppState.aplicarPerfil`, que
    /// precarga el avatar y las fotos de las mascotas apenas se conoce el perfil, en vez de
    /// esperar a que el usuario entre a Perfil y recién ahí empiece la descarga). Usa el
    /// mismo `ladoMaximoPt` por defecto que `PHCachedAsyncImage`/`PHAvatar` para que quede
    /// cacheada en el tamaño correcto y no haga falta volver a bajarla al mostrarla.
    static func precargar(urlString: String?, ladoMaximoPt: CGFloat = 240) {
        guard let urlString, let url = URL(string: urlString), shared.image(for: url) == nil else { return }
        let maxPixels = ladoMaximoPt * UIScreen.main.scale
        Task.detached(priority: .utility) {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            guard let image = downsampledImage(data: data, maxDimensionPixels: maxPixels) else { return }
            shared.insert(image, for: url)
        }
    }

    /// Decodifica directo a un tamaño reducido vía ImageIO en vez de `UIImage(data:)` (que
    /// decodifica a la resolución original completa) — el patrón recomendado por Apple para
    /// listas/galerías con fotos, mucho más liviano en CPU y memoria. Compartido por
    /// `PHCachedAsyncImage.load()` y `precargar(urlString:ladoMaximoPt:)`.
    fileprivate static func downsampledImage(data: Data, maxDimensionPixels: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxDimensionPixels))
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data) // respaldo si ImageIO no puede (formato raro): mejor mostrar algo que nada
        }
        return UIImage(cgImage: cgImage)
    }
}

/// `AsyncImage` con cache de memoria propio y un `placeholder` genérico para estado
/// de carga/error/URL inválida o ausente.
public struct PHCachedAsyncImage<Placeholder: View>: View {
    let urlString: String?
    /// Lado más largo, en puntos, al que se decodifica la imagen (se multiplica por la
    /// escala de pantalla para el tamaño real en píxeles). 240pt cubre con margen los usos
    /// actuales (avatares, miniaturas, cards de hospedaje) sin decodificar a resolución de
    /// cámara — para la galería de detalle a pantalla completa, sube este valor.
    let ladoMaximoPt: CGFloat
    /// `.fill` (recorta para llenar el marco) por defecto — el comportamiento de siempre,
    /// correcto para miniaturas/cards/avatares. `PHVisorFotos` pasa `.fit` (se ve la foto
    /// completa, sin recortar) porque ahí el punto es poder examinar la foto entera.
    let modoContenido: ContentMode
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var isLoading = false

    public init(
        urlString: String?, ladoMaximoPt: CGFloat = 240, modoContenido: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.ladoMaximoPt = ladoMaximoPt
        self.modoContenido = modoContenido
        self.placeholder = placeholder
    }

    public var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: modoContenido)
            } else {
                placeholder()
            }
        }
        .task(id: urlString) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let urlString, let url = URL(string: urlString) else {
            uiImage = nil
            return
        }
        if let cached = PHImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let maxPixels = ladoMaximoPt * UIScreen.main.scale
            // El decode/downsample de ImageIO es trabajo de CPU pesado — antes corría acá
            // mismo, en @MainActor junto con el resto de `load()`, así que cada imagen que
            // terminaba de descargarse trababa el hilo principal un instante; con varias
            // fotos cargando a la vez en una lista (el caso normal al hacer scroll), esos
            // instantes se notaban como lentitud general. `Task.detached` lo saca a un hilo
            // de fondo; solo la asignación a `uiImage` (que sí necesita @MainActor) vuelve.
            let image = await Task.detached(priority: .userInitiated) {
                PHImageCache.downsampledImage(data: data, maxDimensionPixels: maxPixels)
            }.value
            if let image {
                PHImageCache.shared.insert(image, for: url)
                uiImage = image
            }
        } catch {
            // Sin red o URL inválida: se queda en el placeholder, sin crashear.
            uiImage = nil
        }
    }
}
