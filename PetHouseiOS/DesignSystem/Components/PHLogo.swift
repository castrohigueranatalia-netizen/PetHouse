//
//  PHLogo.swift
//  DesignSystem/Components
//
//  Logo de marca (Resources/Assets.xcassets/Logo.imageset, copiado de _src/logo.bin —
//  la misma imagen que usa index.html). Fuente de un solo tamaño (300×167 px): en
//  pantallas de alta densidad se escala visualmente en vez de usar renditions @2x/@3x
//  reales, que no se pudieron generar sin herramientas de edición de imagen en este
//  entorno — suficiente para el MVP, vale la pena reemplazarlo por assets de verdad más
//  adelante si la nitidez importa a tamaños grandes.
//

import SwiftUI

public struct PHLogo: View {
    let height: CGFloat

    public init(height: CGFloat = 40) {
        self.height = height
    }

    public var body: some View {
        Image("Logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .accessibilityLabel("PetHouse")
    }
}

#Preview {
    VStack(spacing: 24) {
        PHLogo(height: 40)
        PHLogo(height: 72)
    }
    .padding()
}
