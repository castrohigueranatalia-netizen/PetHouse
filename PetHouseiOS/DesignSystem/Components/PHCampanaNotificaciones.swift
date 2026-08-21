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
                            // Este botón siempre es el más a la derecha de la pantalla (las 4
                            // pantallas donde aparece lo usan como último ítem del toolbar) —
                            // con `x: 4` el contador sobresalía justo en el borde y se veía
                            // cortado por el borde de la pantalla. Sin desplazamiento horizontal,
                            // queda pegado a la esquina del círculo sin salirse de su marco.
                            .offset(x: 0, y: -4)
                    }
                }
        }
        .accessibilityLabel(noLeidas > 0 ? "Notificaciones, \(noLeidas) sin leer" : "Notificaciones")
    }
}
