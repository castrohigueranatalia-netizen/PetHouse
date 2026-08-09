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

import SwiftUI
import UIKit

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
}

/// `AsyncImage` con cache de memoria propio y un `placeholder` genérico para estado
/// de carga/error/URL inválida o ausente.
public struct PHCachedAsyncImage<Placeholder: View>: View {
    let urlString: String?
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var isLoading = false

    public init(urlString: String?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.urlString = urlString
        self.placeholder = placeholder
    }

    public var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
            if let image = UIImage(data: data) {
                PHImageCache.shared.insert(image, for: url)
                uiImage = image
            }
        } catch {
            // Sin red o URL inválida: se queda en el placeholder, sin crashear.
            uiImage = nil
        }
    }
}
