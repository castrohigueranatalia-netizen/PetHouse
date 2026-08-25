//
//  CalendarioHospedajeView.swift
//  Features/Anfitrion
//
//  Calendario mensual de un hospedaje propio — ver CalendarioHospedajeViewModel. Se abre
//  desde MisHospedajesView, junto a "Ver reservas recibidas" y "Pausar hospedaje".
//

import SwiftUI

struct CalendarioHospedajeView: View {
    @State private var viewModel: CalendarioHospedajeViewModel
    @State private var reservaSeleccionada: Reserva?

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
        .task { await viewModel.cargar() }
        .sheet(item: $reservaSeleccionada) { reserva in
            detalleReserva(reserva)
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
        let esHoy = Calendar.current.isDateInToday(dia)
        let numero = Calendar.current.component(.day, from: dia)

        return Button {
            reservaSeleccionada = reserva
        } label: {
            Text("\(numero)")
                .phText(PHFont.bodySM.weight(reserva != nil ? .semibold : .regular), color: colorTexto(reserva))
                .frame(width: 40, height: 40)
                .background(colorFondo(reserva))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(esHoy ? PHColor.primary : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(reserva == nil)
        .accessibilityLabel(etiquetaAccesibilidad(dia: numero, reserva: reserva))
    }

    private func colorFondo(_ reserva: Reserva?) -> Color {
        switch reserva?.estado {
        case .confirmada: PHColor.primary
        case .pendiente: PHColor.primaryContainer
        default: .clear
        }
    }

    private func colorTexto(_ reserva: Reserva?) -> Color {
        reserva?.estado == .confirmada ? .white : PHColor.ink
    }

    private func etiquetaAccesibilidad(dia: Int, reserva: Reserva?) -> String {
        guard let reserva else { return "Día \(dia), libre" }
        let estado = reserva.estado == .confirmada ? "reservado" : "solicitud pendiente"
        return "Día \(dia), \(estado) por \(reserva.usuarioNombre ?? "un huésped")"
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
}
