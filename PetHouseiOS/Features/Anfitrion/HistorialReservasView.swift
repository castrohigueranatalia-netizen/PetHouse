//
//  HistorialReservasView.swift
//  Features/Anfitrion
//
//  Historial de TODAS las reservas de TODOS los hospedajes del anfitrión, cualquier estado
//  (ver GET /api/hospedajes/mios/reservas) — como una tabla: cuándo se hizo la reserva,
//  quién la hizo y cuántas noches. De solo lectura, sin acciones de aceptar/rechazar (eso
//  vive en ReservasRecibidasView, por hospedaje). Tocar una fila abre el detalle completo,
//  incluyendo cuánto se ganó con esa reserva.
//

import SwiftUI

struct HistorialReservasView: View {
    @State private var viewModel = HistorialReservasViewModel()
    @State private var reservaDetalle: Reserva?

    var body: some View {
        content
            .background(PHColor.canvas)
            .navigationTitle("Historial de reservas")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .sheet(item: $reservaDetalle) { reserva in
                DetalleHistorialReservaView(reserva: reserva)
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.reservas.isEmpty {
            PHLoadingStateView(mensaje: "Cargando historial…")
        } else if let error = viewModel.error, viewModel.reservas.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.reservas.isEmpty {
            PHEmptyStateView(
                systemImage: "clock.arrow.circlepath",
                titulo: "Sin reservas todavía",
                mensaje: "Las reservas que reciban tus hospedajes van a aparecer acá, con fecha y huésped."
            )
        } else {
            ScrollView {
                VStack(spacing: PHSpacing.s8) {
                    encabezadoTabla
                    VStack(spacing: PHSpacing.s4) {
                        ForEach(viewModel.reservas) { reserva in
                            fila(reserva)
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    private var encabezadoTabla: some View {
        HStack {
            Text("Fecha").frame(width: 68, alignment: .leading)
            Text("Huésped").frame(maxWidth: .infinity, alignment: .leading)
            Text("Noches").frame(width: 52, alignment: .trailing)
            Color.clear.frame(width: 14) // deja espacio para el chevron de las filas de abajo
        }
        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
        .padding(.horizontal, PHSpacing.s12)
    }

    private func fila(_ reserva: Reserva) -> some View {
        Button {
            reservaDetalle = reserva
        } label: {
            HStack {
                Text(reserva.creadoEn.map { PHDate.displayFromTimestamp($0) } ?? "—")
                    .frame(width: 68, alignment: .leading)
                    .phText(PHFont.captionSM, color: PHColor.body)

                Text(reserva.usuarioNombre ?? "Huésped")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                    .lineLimit(1)

                Text(reserva.noches.map { "\($0)" } ?? "—")
                    .frame(width: 52, alignment: .trailing)
                    .phText(PHFont.bodySM, color: PHColor.body)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(PHColor.mutedSoft)
                    .frame(width: 14)
            }
            .padding(PHSpacing.s12)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Detalle completo de una reserva del historial — incluye lo que la fila de la tabla no
/// muestra: hospedaje, fechas de la estadía, mascotas y el desglose de cuánto se ganó.
private struct DetalleHistorialReservaView: View {
    let reserva: Reserva
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        HStack {
                            Text(reserva.hospedajeTitulo ?? "Hospedaje")
                                .phText(PHFont.displaySM, color: PHColor.ink)
                            Spacer()
                            estadoBadge
                        }
                        Text("Solicitada por \(reserva.usuarioNombre ?? "un huésped")")
                            .phText(PHFont.bodySM, color: PHColor.muted)
                    }

                    VStack(alignment: .leading, spacing: PHSpacing.s12) {
                        if let creado = reserva.creadoEn {
                            fila("Se solicitó el", PHDate.displayFromTimestamp(creado))
                        }
                        if let desde = reserva.desde, let hasta = reserva.hasta {
                            fila("Estadía", "\(PHDate.displayFromAPIDateOnly(desde)) → \(PHDate.displayFromAPIDateOnly(hasta))")
                        }
                        if let noches = reserva.noches {
                            fila("Noches", "\(noches)")
                        }
                        if let mascotas = reserva.mascotas {
                            fila("Mascotas", "\(mascotas)")
                        }
                        fila("Código", reserva.codigo)
                    }
                    .padding(PHSpacing.s16)
                    .background(PHColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

                    VStack(alignment: .leading, spacing: PHSpacing.s12) {
                        Text("Cuánto se ganó")
                            .phText(PHFont.titleMD, color: PHColor.ink)
                        if let precioNoche = reserva.precioNoche {
                            fila("Precio por noche", PHFormato.precio(precioNoche))
                        }
                        if let limpieza = reserva.limpieza {
                            fila("Tarifa de limpieza", PHFormato.precio(limpieza))
                        }
                        if let servicio = reserva.servicio {
                            fila("Tarifa de servicio", PHFormato.precio(servicio))
                        }
                        if let total = reserva.total {
                            Divider()
                            fila("Total", PHFormato.precio(total), destacar: true)
                        }
                    }
                    .padding(PHSpacing.s16)
                    .background(PHColor.primaryContainer)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

                    if let mascotas = reserva.mascotasDetalle, !mascotas.isEmpty {
                        VStack(alignment: .leading, spacing: PHSpacing.s8) {
                            Text("Mascotas de esta reserva")
                                .phText(PHFont.titleMD, color: PHColor.ink)
                            VStack(spacing: PHSpacing.s8) {
                                ForEach(mascotas) { mascota in
                                    HStack(spacing: PHSpacing.s12) {
                                        PHAvatar(name: mascota.nombre, urlString: MediaURL.resolver(mascota.fotos.first), size: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(mascota.nombre).phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                                            if let raza = mascota.raza, !raza.isEmpty {
                                                Text(raza).phText(PHFont.micro, color: PHColor.muted)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(PHSpacing.s12)
                                    .background(PHColor.surfaceSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
            .background(PHColor.canvas)
            .navigationTitle("Detalle de la reserva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var estadoBadge: some View {
        switch reserva.estado {
        case .pendiente: PHBadge("Pendiente de aprobación", style: .warning)
        case .confirmada: PHBadge("Confirmada", style: .success)
        case .rechazada: PHBadge("Rechazada", style: .error)
        case .cancelada: PHBadge("Cancelada", style: .error)
        case .completada: PHBadge("Completada", style: .primary)
        }
    }

    private func fila(_ etiqueta: String, _ valor: String, destacar: Bool = false) -> some View {
        HStack {
            Text(etiqueta).phText(PHFont.bodySM, color: PHColor.muted)
            Spacer()
            Text(valor).phText(destacar ? PHFont.titleMD : PHFont.bodySM.weight(.medium), color: PHColor.ink)
        }
    }
}
