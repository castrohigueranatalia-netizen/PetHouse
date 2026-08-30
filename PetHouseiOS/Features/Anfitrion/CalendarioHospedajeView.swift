//
//  CalendarioHospedajeView.swift
//  Features/Anfitrion
//
//  Calendario mensual de un hospedaje propio — ver CalendarioHospedajeViewModel. Se abre
//  desde MisHospedajesView, junto a "Ver reservas recibidas" y "Pausar hospedaje". Además de
//  mostrar reservas, el anfitrión puede bloquear fechas a mano (ver BloquearFechasSheet) sin
//  necesidad de una reserva real.
//

import SwiftUI

/// UN SOLO `.sheet(item:)` para los dos tipos de día que se pueden tocar en la grilla — ver
/// el comentario largo sobre este mismo patrón (con `.navigationDestination`) en
/// MisHospedajesView/LoginView/NotificacionesView/MisReservasView: más de un modificador de
/// presentación por separado en la misma vista es poco confiable en esta versión de SwiftUI.
private enum DiaCalendario: Identifiable {
    case reserva(Reserva)
    case bloqueo(FechaBloqueada)

    // `.sheet(item:)` pide `Identifiable`, no `Hashable` (a diferencia de
    // `.navigationDestination(item:)`) — un id de texto armado a mano alcanza.
    var id: String {
        switch self {
        case .reserva(let reserva): "reserva-\(reserva.id)"
        case .bloqueo(let bloqueo): "bloqueo-\(bloqueo.id)"
        }
    }
}

struct CalendarioHospedajeView: View {
    @State private var viewModel: CalendarioHospedajeViewModel
    @State private var diaSeleccionado: DiaCalendario?
    @State private var mostrarBloquear = false

    private static let formatoMes: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let diasSemana = ["L", "M", "M", "J", "V", "S", "D"]

    init(hospedaje: Hospedaje) {
        _viewModel = State(initialValue: CalendarioHospedajeViewModel(hospedaje: hospedaje))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                if viewModel.isLoading && viewModel.reservas.isEmpty {
                    PHLoadingStateView(mensaje: "Cargando calendario…")
                } else if let error = viewModel.error, viewModel.reservas.isEmpty {
                    PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
                } else {
                    selectorMes
                    grilla
                    leyenda
                }
            }
            .padding(PHSpacing.s16)
        }
        .background(PHColor.canvas)
        .navigationTitle(viewModel.hospedaje.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PHIconButton(systemImage: "calendar.badge.minus", accessibilityLabel: "Bloquear fechas") {
                    mostrarBloquear = true
                }
            }
        }
        .task { await viewModel.cargar() }
        .sheet(isPresented: $mostrarBloquear) {
            BloquearFechasSheet(hospedaje: viewModel.hospedaje) {
                Task { await viewModel.cargar() }
            }
        }
        .sheet(item: $diaSeleccionado) { dia in
            switch dia {
            case .reserva(let reserva):
                detalleReserva(reserva)
            case .bloqueo(let bloqueo):
                detalleBloqueo(bloqueo)
            }
        }
    }

    private var selectorMes: some View {
        HStack {
            PHIconButton(systemImage: "chevron.left", accessibilityLabel: "Mes anterior") {
                viewModel.mesAnterior()
            }
            Spacer()
            Text(Self.formatoMes.string(from: viewModel.mesMostrado).capitalized)
                .phText(PHFont.titleMD, color: PHColor.ink)
            Spacer()
            PHIconButton(systemImage: "chevron.right", accessibilityLabel: "Mes siguiente") {
                viewModel.mesSiguiente()
            }
        }
    }

    private var grilla: some View {
        VStack(spacing: PHSpacing.s8) {
            HStack {
                ForEach(Array(Self.diasSemana.enumerated()), id: \.offset) { _, letra in
                    Text(letra)
                        .frame(maxWidth: .infinity)
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: PHSpacing.s8) {
                ForEach(Array(viewModel.diasDeLaGrilla.enumerated()), id: \.offset) { _, dia in
                    if let dia {
                        casillaDia(dia)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }

    private func casillaDia(_ dia: Date) -> some View {
        let reserva = viewModel.reserva(en: dia)
        // Una reserva real siempre "gana" — un bloqueo no debería poder coexistir con una
        // reserva en la misma fecha (el servidor ya lo impide al crear el bloqueo), pero por
        // las dudas se prioriza mostrar/abrir la reserva.
        let bloqueo = reserva == nil ? viewModel.bloqueo(en: dia) : nil
        let esHoy = Calendar.current.isDateInToday(dia)
        let numero = Calendar.current.component(.day, from: dia)

        return Button {
            if let reserva {
                diaSeleccionado = .reserva(reserva)
            } else if let bloqueo {
                diaSeleccionado = .bloqueo(bloqueo)
            }
        } label: {
            Text("\(numero)")
                .phText(PHFont.bodySM.weight(reserva != nil || bloqueo != nil ? .semibold : .regular), color: colorTexto(reserva: reserva, bloqueo: bloqueo))
                .frame(width: 40, height: 40)
                .background(colorFondo(reserva: reserva, bloqueo: bloqueo))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(esHoy ? PHColor.primary : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(reserva == nil && bloqueo == nil)
        .accessibilityLabel(etiquetaAccesibilidad(dia: numero, reserva: reserva, bloqueo: bloqueo))
    }

    private func colorFondo(reserva: Reserva?, bloqueo: FechaBloqueada?) -> Color {
        if bloqueo != nil { return PHColor.mutedSoft }
        switch reserva?.estado {
        case .confirmada: return PHColor.primary
        case .pendiente: return PHColor.primaryContainer
        default: return .clear
        }
    }

    private func colorTexto(reserva: Reserva?, bloqueo: FechaBloqueada?) -> Color {
        if bloqueo != nil { return .white }
        return reserva?.estado == .confirmada ? .white : PHColor.ink
    }

    private func etiquetaAccesibilidad(dia: Int, reserva: Reserva?, bloqueo: FechaBloqueada?) -> String {
        if let reserva {
            let estado = reserva.estado == .confirmada ? "reservado" : "solicitud pendiente"
            return "Día \(dia), \(estado) por \(reserva.usuarioNombre ?? "un huésped")"
        }
        if bloqueo != nil { return "Día \(dia), bloqueado" }
        return "Día \(dia), libre"
    }

    private var leyenda: some View {
        HStack(spacing: PHSpacing.s16) {
            HStack(spacing: PHSpacing.s4) {
                Circle().fill(PHColor.primary).frame(width: 14, height: 14)
                Text("Confirmada").phText(PHFont.captionSM, color: PHColor.muted)
            }
            HStack(spacing: PHSpacing.s4) {
                Circle().fill(PHColor.primaryContainer).frame(width: 14, height: 14)
                Text("Pendiente").phText(PHFont.captionSM, color: PHColor.muted)
            }
            HStack(spacing: PHSpacing.s4) {
                Circle().fill(PHColor.mutedSoft).frame(width: 14, height: 14)
                Text("Bloqueada").phText(PHFont.captionSM, color: PHColor.muted)
            }
        }
    }

    private func detalleReserva(_ reserva: Reserva) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            HStack {
                Text(reserva.usuarioNombre ?? "Huésped")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Spacer()
                PHBadge(
                    reserva.estado == .confirmada ? "Confirmada" : "Solicitud nueva",
                    style: reserva.estado == .confirmada ? .success : .warning
                )
            }
            if let desde = reserva.desde, let hasta = reserva.hasta {
                Label(
                    "\(PHDate.displayFromAPIDateOnly(desde)) → \(PHDate.displayFromAPIDateOnly(hasta))",
                    systemImage: "calendar"
                )
                .phText(PHFont.bodySM, color: PHColor.body)
            }
            Text(reserva.codigo)
                .phText(PHFont.captionSM, color: PHColor.mutedSoft)
            Spacer()
        }
        .padding(PHSpacing.s16)
        .presentationDetents([.fraction(0.3)])
        .presentationDragIndicator(.visible)
    }

    private func detalleBloqueo(_ bloqueo: FechaBloqueada) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            HStack {
                Text("Fechas bloqueadas")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Spacer()
                PHBadge("Bloqueada", style: .warning)
            }
            Label(
                "\(PHDate.displayFromAPIDateOnly(bloqueo.desde)) → \(PHDate.displayFromAPIDateOnly(bloqueo.hasta))",
                systemImage: "calendar"
            )
            .phText(PHFont.bodySM, color: PHColor.body)
            if let motivo = bloqueo.motivo, !motivo.isEmpty {
                Text(motivo).phText(PHFont.bodySM, color: PHColor.muted)
            }
            PHTextButton("Desbloquear estas fechas", role: .destructive) {
                Task {
                    await viewModel.desbloquear(bloqueo)
                    diaSeleccionado = nil
                }
            }
            Spacer()
        }
        .padding(PHSpacing.s16)
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
    }
}
