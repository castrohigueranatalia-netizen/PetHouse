//
//  ReservaDetailView.swift
//  Features/Reserva
//
//  Detalle de una reserva: toda la info de la reserva (fechas, noches, mascotas, desglose
//  de precio, código, plan de actividades) + del hospedaje (fotos, servicios, anfitrión) +
//  un botón para escribirle al anfitrión — antes no había forma de iniciar un chat nuevo
//  desde ningún lado de la app (ver ReservaDetailViewModel).
//

import SwiftUI

struct ReservaDetailView: View {
    @State private var viewModel: ReservaDetailViewModel

    init(reserva: Reserva) {
        _viewModel = State(initialValue: ReservaDetailViewModel(reserva: reserva))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                encabezadoHospedaje

                seccionReserva

                if let mascotas = viewModel.reserva.mascotasDetalle, !mascotas.isEmpty {
                    seccionMascotas(mascotas)
                }

                if !viewModel.plan.isEmpty {
                    seccionPlan
                }

                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }
            }
            .padding(PHSpacing.s16)
            .padding(.bottom, PHSpacing.s64)
        }
        .background(PHColor.canvas)
        .navigationTitle("Reserva")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.cargar() }
        .safeAreaInset(edge: .bottom) {
            if viewModel.reserva.anfitrionId != nil {
                botonMensaje
            }
        }
        .navigationDestination(item: Binding(get: { viewModel.conversacion }, set: { _ in })) { conversacion in
            ChatDetailView(conversacion: conversacion)
                .onDisappear { viewModel.limpiarConversacion() }
        }
    }

    @ViewBuilder
    private var encabezadoHospedaje: some View {
        if viewModel.isLoading && viewModel.hospedaje == nil {
            PHLoadingStateView(mensaje: "Cargando hospedaje…")
                .frame(height: 160)
        } else {
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                PHCachedAsyncImage(
                    urlString: MediaURL.resolver(viewModel.hospedaje?.fotos?.first ?? viewModel.reserva.fotos?.first),
                    ladoMaximoPt: 400
                ) {
                    Rectangle()
                        .fill(PHColor.surfaceStrong)
                        .overlay(Image(systemName: "photo").font(.title2).foregroundStyle(PHColor.mutedSoft))
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

                Text(viewModel.hospedaje?.titulo ?? viewModel.reserva.hospedajeTitulo ?? "Hospedaje")
                    .phText(PHFont.displaySM, color: PHColor.ink)

                let localidad = viewModel.hospedaje?.localidad ?? viewModel.reserva.ciudad
                let lugar = [viewModel.reserva.barrio ?? viewModel.hospedaje?.barrio, localidad].compactMap { $0 }
                if !lugar.isEmpty {
                    Text(lugar.joined(separator: ", "))
                        .phText(PHFont.bodySM, color: PHColor.muted)
                }

                if let anfitrion = viewModel.hospedaje?.anfitrionNombre {
                    HStack(spacing: PHSpacing.s8) {
                        PHAvatar(name: anfitrion, size: 32)
                        Text("Hospedado por \(anfitrion)")
                            .phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                    }
                    .padding(.top, PHSpacing.s4)
                }
            }
        }
    }

    private var seccionReserva: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            HStack {
                Text("Tu reserva")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Spacer()
                estadoBadge
            }

            if let desde = viewModel.reserva.desde, let hasta = viewModel.reserva.hasta {
                filaDato("Fechas", "\(PHDate.displayFromAPIDateOnly(desde)) → \(PHDate.displayFromAPIDateOnly(hasta))")
            }
            if let noches = viewModel.reserva.noches {
                filaDato("Noches", "\(noches)")
            }
            if let mascotas = viewModel.reserva.mascotas {
                filaDato("Mascotas", "\(mascotas)")
            }
            if let precioNoche = viewModel.reserva.precioNoche {
                filaDato("Precio por noche", PHFormato.precio(precioNoche))
            }
            if let limpieza = viewModel.reserva.limpieza {
                filaDato("Tarifa de limpieza", PHFormato.precio(limpieza))
            }
            if let servicio = viewModel.reserva.servicio {
                filaDato("Tarifa de servicio", PHFormato.precio(servicio))
            }
            if let total = viewModel.reserva.total {
                Divider()
                filaDato("Total", PHFormato.precio(total), destacar: true)
            }

            Text("Código \(viewModel.reserva.codigo)")
                .phText(PHFont.micro, color: PHColor.mutedSoft)
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private func filaDato(_ etiqueta: String, _ valor: String, destacar: Bool = false) -> some View {
        HStack {
            Text(etiqueta).phText(PHFont.bodySM, color: PHColor.muted)
            Spacer()
            Text(valor).phText(destacar ? PHFont.titleMD : PHFont.bodySM.weight(.medium), color: PHColor.ink)
        }
    }

    @ViewBuilder
    private var estadoBadge: some View {
        switch viewModel.reserva.estado {
        case .pendiente: PHBadge("Pendiente de aprobación", style: .warning)
        case .confirmada: PHBadge("Confirmada", style: .success)
        case .rechazada: PHBadge("Rechazada", style: .error)
        case .cancelada: PHBadge("Cancelada", style: .error)
        case .completada: PHBadge("Completada", style: .primary)
        }
    }

    private func seccionMascotas(_ mascotas: [Mascota]) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("Mascotas de esta reserva")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: PHSpacing.s8) {
                ForEach(mascotas) { mascota in
                    HStack(spacing: PHSpacing.s12) {
                        PHAvatar(name: mascota.nombre, size: 32)
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

    private var seccionPlan: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("Plan de actividades")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: PHSpacing.s4) {
                ForEach(viewModel.plan) { item in
                    HStack {
                        Text(item.nombre).phText(PHFont.bodySM, color: PHColor.ink)
                        Spacer()
                        Text(PHFormato.precio(item.precio)).phText(PHFont.bodySM, color: PHColor.muted)
                    }
                    .padding(PHSpacing.s12)
                    .background(PHColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
                }
            }
        }
    }

    private var botonMensaje: some View {
        PHPrimaryButton("Escribir al anfitrión", systemImage: "message", isLoading: viewModel.iniciandoChat) {
            Task { await viewModel.iniciarChat() }
        }
        .padding(PHSpacing.s16)
        .background(.ultraThinMaterial)
    }
}
