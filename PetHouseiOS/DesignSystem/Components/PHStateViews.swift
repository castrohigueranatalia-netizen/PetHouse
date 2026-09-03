//
//  PHStateViews.swift
//  DesignSystem/Components
//
//  Estados reutilizables de carga / vacío / error, para no repetirlos ad-hoc en cada
//  pantalla (ver requerimiento de UX del MVP). `PHErrorStateView` distingue visualmente
//  "función pendiente en el servidor" (icono de reloj, tono neutro/warning) de un error
//  real de red o servidor (icono de alerta, tono de error) usando `AppError.esFuncionPendiente`.
//

import SwiftUI

public struct PHLoadingStateView: View {
    let mensaje: String

    public init(mensaje: String = "Cargando…") {
        self.mensaje = mensaje
    }

    public var body: some View {
        VStack(spacing: PHSpacing.s16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(PHColor.primary)
            Text(mensaje)
                .phText(PHFont.bodySM, color: PHColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mensaje)
    }
}

public struct PHEmptyStateView: View {
    let systemImage: String
    let titulo: String
    let mensaje: String?
    let accionTitulo: String?
    let accion: (() -> Void)?

    public init(
        systemImage: String = "tray",
        titulo: String,
        mensaje: String? = nil,
        accionTitulo: String? = nil,
        accion: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.titulo = titulo
        self.mensaje = mensaje
        self.accionTitulo = accionTitulo
        self.accion = accion
    }

    public var body: some View {
        VStack(spacing: PHSpacing.s12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(PHColor.mutedSoft)
            Text(titulo)
                .phText(PHFont.titleMD, color: PHColor.ink)
                .multilineTextAlignment(.center)
            if let mensaje {
                Text(mensaje)
                    .phText(PHFont.bodySM, color: PHColor.muted)
                    .multilineTextAlignment(.center)
            }
            if let accionTitulo, let accion {
                PHSecondaryButton(accionTitulo, action: accion)
                    .padding(.top, PHSpacing.s8)
                    .frame(maxWidth: 240)
            }
        }
        .padding(PHSpacing.s32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct PHErrorStateView: View {
    let error: AppError
    let reintentar: (() -> Void)?

    public init(error: AppError, reintentar: (() -> Void)? = nil) {
        self.error = error
        self.reintentar = reintentar
    }

    public var body: some View {
        if error.esFuncionPendiente {
            PHEmptyStateView(
                systemImage: "hourglass",
                titulo: "Función pendiente",
                mensaje: error.localizedDescription
            )
        } else {
            VStack(spacing: PHSpacing.s12) {
                Image(systemName: iconoPara(error))
                    .font(.system(size: 40))
                    .foregroundStyle(PHColor.error)
                Text("Algo salió mal")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Text(error.localizedDescription)
                    .phText(PHFont.bodySM, color: PHColor.muted)
                    .multilineTextAlignment(.center)
                if let reintentar {
                    PHPrimaryButton("Reintentar", systemImage: "arrow.clockwise", action: reintentar)
                        .frame(maxWidth: 220)
                        .padding(.top, PHSpacing.s8)
                }
            }
            .padding(PHSpacing.s32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private func iconoPara(_ error: AppError) -> String {
        switch error {
        case .sinConexion: "wifi.slash"
        case .sesionExpirada: "lock.slash"
        default: "exclamationmark.triangle"
        }
    }
}

#Preview {
    VStack {
        PHLoadingStateView()
        Divider()
        PHEmptyStateView(systemImage: "heart", titulo: "Sin favoritos todavía", mensaje: "Los hospedajes que guardes aparecerán aquí.")
        Divider()
        PHErrorStateView(error: .sinConexion, reintentar: {})
        Divider()
        PHErrorStateView(error: .rutaNoImplementada)
    }
}
