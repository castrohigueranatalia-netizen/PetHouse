//
//  NotificacionesView.swift
//  Features/Notificaciones
//
//  La campana: historial completo de notificaciones, nuevas y viejas — a diferencia del
//  `.alert` instantáneo de MainTabView (que se pierde al cerrarlo), esta pantalla siempre
//  se puede volver a abrir para repasar avisos ya vistos (ver Core/Models/Notificacion.swift
//  y pethouse-api/src/routes/notificaciones.js).
//
//  Al abrirse, marca TODO como leído de una — igual que la bandeja de cualquier app real.
//  Tocar una notificación de "solicitud nueva"/"reserva resuelta" navega al hospedaje/
//  reserva correspondiente, armando un objeto "placeholder" con solo el id (mismo patrón ya
//  usado en MisReservasView.hospedajePlaceholder) — la pantalla de destino pide el detalle
//  completo por su cuenta apenas aparece.
//

import SwiftUI

struct NotificacionesView: View {
    @State private var viewModel = NotificacionesViewModel()
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var reservaParaAbrir: Reserva?
    @State private var hospedajeParaAbrir: Hospedaje?

    var body: some View {
        NavigationStack {
            content
                .background(PHColor.canvas)
                .navigationTitle("Notificaciones")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        PHTextButton("Cerrar") { dismiss() }
                    }
                }
                .task {
                    await viewModel.cargar()
                    await viewModel.marcarTodasLeidas()
                    session.actualizarNotificacionesNoLeidas(0)
                }
                .refreshable { await viewModel.cargar() }
                .navigationDestination(item: $reservaParaAbrir) { reserva in
                    ReservaDetailView(reserva: reserva)
                }
                .navigationDestination(item: $hospedajeParaAbrir) { hospedaje in
                    ReservasRecibidasView(hospedaje: hospedaje)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.notificaciones.isEmpty {
            PHLoadingStateView(mensaje: "Cargando notificaciones…")
        } else if let error = viewModel.error, viewModel.notificaciones.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.notificaciones.isEmpty {
            PHEmptyStateView(
                systemImage: "bell",
                titulo: "Sin notificaciones",
                mensaje: "Acá vas a ver los avisos de tus reservas y solicitudes, nuevos y viejos."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s8) {
                    ForEach(viewModel.notificaciones) { notificacion in
                        Button {
                            abrir(notificacion)
                        } label: {
                            fila(notificacion)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    private func fila(_ notificacion: Notificacion) -> some View {
        HStack(alignment: .top, spacing: PHSpacing.s12) {
            ZStack {
                Circle().fill(notificacion.leida ? PHColor.surfaceSoft : PHColor.primaryContainer)
                Image(systemName: icono(notificacion.tipo))
                    .foregroundStyle(notificacion.leida ? PHColor.mutedSoft : PHColor.primary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(notificacion.titulo)
                    .phText(PHFont.bodyMD.weight(notificacion.leida ? .regular : .semibold), color: PHColor.ink)
                Text(notificacion.mensaje)
                    .phText(PHFont.bodySM, color: PHColor.muted)
                Text(PHDate.displayRelative(notificacion.creadoEn))
                    .phText(PHFont.micro, color: PHColor.mutedSoft)
            }

            Spacer()

            if !notificacion.leida {
                Circle().fill(PHColor.primary).frame(width: 8, height: 8)
            }
        }
        .padding(PHSpacing.s12)
        .background(PHColor.canvas)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
        .phShadow(PHShadow.level1)
    }

    private func icono(_ tipo: TipoNotificacion) -> String {
        switch tipo {
        case .verificacionResuelta: "checkmark.seal"
        case .reservaResuelta: "calendar"
        case .solicitudNueva: "bell.badge"
        }
    }

    private func abrir(_ notificacion: Notificacion) {
        Task { await viewModel.marcarLeida(notificacion.id) }
        switch notificacion.tipo {
        case .reservaResuelta:
            guard let reservaId = notificacion.reservaId else { return }
            reservaParaAbrir = Reserva(
                id: reservaId, codigo: "", estado: .confirmada, desde: nil, hasta: nil,
                noches: nil, mascotas: nil, total: nil, precioNoche: nil, limpieza: nil,
                servicio: nil, creadoEn: nil, usuarioId: nil, hospedajeId: notificacion.hospedajeId,
                anfitrionId: nil, hospedajeTitulo: nil,
                ciudad: nil, barrio: nil, tipo: nil, fotos: nil
            )
        case .solicitudNueva:
            guard let hospedajeId = notificacion.hospedajeId else { return }
            hospedajeParaAbrir = Hospedaje(
                id: hospedajeId, titulo: "Hospedaje", tipo: .guarderia, ciudad: "Bogotá", precioNoche: 0
            )
        case .verificacionResuelta:
            break
        }
    }
}
