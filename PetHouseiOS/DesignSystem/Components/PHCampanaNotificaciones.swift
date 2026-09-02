//
//  PHCampanaNotificaciones.swift
//  DesignSystem/Components
//
//  Botón de campana con contador de no leídas — el mismo ícono se repite en las 4 pestañas
//  principales (ver MainTabView/RootView.swift), así que vive acá en vez de repetirse.
//

import SwiftUI

public struct PHCampanaNotificaciones: View {
    let noLeidas: Int
    let action: () -> Void

    public init(noLeidas: Int, action: @escaping () -> Void) {
        self.noLeidas = noLeidas
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "bell")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PHColor.ink)
                .frame(width: 40, height: 40)
                .background(PHColor.surfaceSoft)
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if noLeidas > 0 {
                        Text(noLeidas > 9 ? "9+" : "\(noLeidas)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(PHColor.error, in: Capsule())
                            // Este botón vive en un `ToolbarItem` (ver MisReservasView,
                            // BuscarView, etc.) — la barra de navegación recorta cualquier
                            // contenido que se salga de su propio marco, así que un `y`
                            // negativo (como el `-4` que había antes, pensado para que el
                            // contador "se asome" por encima del círculo) quedaba con la
                            // mitad de arriba cortada por ese recorte. Con un desplazamiento
                            // hacia ADENTRO (positivo) el contador queda completo dentro del
                            // marco de 40x40 del botón, sin que la barra le corte nada.
                            .offset(x: -2, y: 2)
                    }
                }
        }
        .accessibilityLabel(noLeidas > 0 ? "Notificaciones, \(noLeidas) sin leer" : "Notificaciones")
    }
}
