//
//  AnfitrionDashboardView.swift
//  Features/Anfitrion
//
//  Se abre desde el toolbar de MisHospedajesView — resume, en toda la cuenta de anfitrión
//  (no un hospedaje a la vez), cuántas mascotas ha hospedado, cuánto ha ganado, y qué
//  mejorar en sus publicaciones para recibir más reservas. Cada recomendación es tocable y
//  lleva DIRECTO a resolverla (ver `AccionRecomendacion`), no a un menú donde haya que volver
//  a buscar qué tocar.
//

import Charts
import SwiftUI

/// Los dos destinos que se PUSHean sobre el stack de navegación — unificados en un solo
/// `.navigationDestination` (mismo motivo que `DestinoMisHospedajes` en MisHospedajesView:
/// dos `.navigationDestination` distintos en la misma vista es un bug ya visto varias veces
/// en esta versión de SwiftUI). `.editar` y `.publicarHospedaje` van aparte, por `.sheet`, ya
/// que `PublicarHospedajeView` trae su propio `NavigationStack`.
private enum DestinoPush: Hashable {
    case hospedaje(Hospedaje)
    case reservasRecibidas(Hospedaje)
}

private enum DestinoSheet: Identifiable {
    case editar(Hospedaje)
    case publicarHospedaje

    var id: String {
        switch self {
        case .editar(let hospedaje): "editar-\(hospedaje.id)"
        case .publicarHospedaje: "publicarHospedaje"
        }
    }
}

struct AnfitrionDashboardView: View {
    @State private var viewModel = AnfitrionDashboardViewModel()
    @State private var destinoPush: DestinoPush?
    @State private var destinoSheet: DestinoSheet?

    var body: some View {
        content
            .navigationTitle("Tu panel")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .navigationDestination(item: $destinoPush) { destino in
                switch destino {
                case .hospedaje(let hospedaje):
                    HospedajeDetailView(hospedajeId: hospedaje.id, esPropio: true) { editado in
                        viewModel.guardarLocal(editado)
                    }
                case .reservasRecibidas(let hospedaje):
                    ReservasRecibidasView(hospedaje: hospedaje)
                }
            }
            .sheet(item: $destinoSheet) { destino in
                switch destino {
                case .editar(let hospedaje):
                    PublicarHospedajeView(hospedajeExistente: hospedaje) { guardado in
                        viewModel.guardarLocal(guardado)
                    }
                case .publicarHospedaje:
                    PublicarHospedajeView { guardado in
                        viewModel.guardarLocal(guardado)
                    }
                }
            }
    }

    private func abrir(_ accion: AccionRecomendacion) {
        switch accion {
        case .editar(let hospedaje):
            destinoSheet = .editar(hospedaje)
        case .verHospedaje(let hospedaje):
            destinoPush = .hospedaje(hospedaje)
        case .verReservasRecibidas(let hospedaje):
            destinoPush = .reservasRecibidas(hospedaje)
        case .publicarHospedaje:
            destinoSheet = .publicarHospedaje
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.historial.isEmpty && viewModel.hospedajes.isEmpty {
            PHLoadingStateView(mensaje: "Calculando tus números…")
        } else if let error = viewModel.error, viewModel.historial.isEmpty && viewModel.hospedajes.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s24) {
                    seccionEstadisticas
                    seccionTip
                    seccionIngresosPorMes
                    seccionCompararHospedajes
                    seccionRecomendaciones
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    private var seccionEstadisticas: some View {
        HStack(spacing: PHSpacing.s12) {
            tarjetaEstadistica(
                valor: "\(viewModel.totalMascotasHospedadas)",
                titulo: "Mascotas hospedadas",
                icono: "pawprint.fill"
            )
            tarjetaEstadistica(
                valor: PHFormato.precio(viewModel.totalGanado),
                titulo: "Total ganado",
                icono: "dollarsign.circle.fill"
            )
            tarjetaEstadistica(
                valor: "\(viewModel.totalEstadias)",
                titulo: "Estadías",
                icono: "checkmark.seal.fill"
            )
        }
    }

    /// Consejo rotativo — ver `AnfitrionDashboardViewModel.tipDelDia`.
    private var seccionTip: some View {
        HStack(alignment: .top, spacing: PHSpacing.s12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(PHColor.warning)
            Text(viewModel.tipDelDia)
                .phText(PHFont.bodySM, color: PHColor.body)
        }
        .padding(PHSpacing.s16)
        .background(PHColor.warningContainer)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    /// Gráfica de barras de ingresos por mes (ver `AnfitrionDashboardViewModel.ingresosPorMes`)
    /// — solo tiene sentido con al menos una estadía completada; sin eso, `seccionEstadisticas`
    /// ya deja claro que todavía no hay nada que graficar.
    @ViewBuilder
    private var seccionIngresosPorMes: some View {
        if !viewModel.ingresosPorMes.isEmpty {
            VStack(alignment: .leading, spacing: PHSpacing.s12) {
                Text("Ingresos por mes")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                Chart(viewModel.ingresosPorMes) { punto in
                    BarMark(
                        x: .value("Mes", punto.mes, unit: .month),
                        y: .value("Ingreso", punto.monto)
                    )
                    .foregroundStyle(PHColor.primary)
                    .cornerRadius(6)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
            .padding(PHSpacing.s16)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
        }
    }

    /// Comparación por hospedaje (ver `AnfitrionDashboardViewModel.resumenPorHospedaje`) —
    /// solo aparece con más de un hospedaje propio, donde de verdad tiene sentido comparar.
    @ViewBuilder
    private var seccionCompararHospedajes: some View {
        if viewModel.resumenPorHospedaje.count > 1 {
            VStack(alignment: .leading, spacing: PHSpacing.s12) {
                Text("Tus hospedajes")
                    .phText(PHFont.titleMD, color: PHColor.ink)
                VStack(spacing: PHSpacing.s8) {
                    ForEach(viewModel.resumenPorHospedaje) { resumen in
                        HStack(spacing: PHSpacing.s12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resumen.hospedaje.titulo)
                                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                                    .lineLimit(1)
                                HStack(spacing: PHSpacing.s4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(PHColor.warning)
                                    Text(String(format: "%.1f", resumen.hospedaje.rating))
                                        .phText(PHFont.captionSM, color: PHColor.muted)
                                    Text("· \(resumen.estadias) estadía\(resumen.estadias == 1 ? "" : "s")")
                                        .phText(PHFont.captionSM, color: PHColor.muted)
                                }
                            }
                            Spacer()
                            Text(PHFormato.precio(resumen.ganado))
                                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.primary)
                        }
                        .padding(PHSpacing.s12)
                        .background(PHColor.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                    }
                }
            }
            .padding(PHSpacing.s16)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
        }
    }

    private func tarjetaEstadistica(valor: String, titulo: String, icono: String) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Image(systemName: icono)
                .font(.system(size: 20))
                .foregroundStyle(PHColor.primary)
            Text(valor)
                .phText(PHFont.displaySM, color: PHColor.ink)
            Text(titulo)
                .phText(PHFont.captionSM, color: PHColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private var seccionRecomendaciones: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Qué puedes mejorar")
                .phText(PHFont.titleMD, color: PHColor.ink)

            if viewModel.recomendaciones.isEmpty {
                HStack(spacing: PHSpacing.s8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PHColor.success)
                    Text("Tus hospedajes están completos — no tenemos más sugerencias por ahora.")
                        .phText(PHFont.bodySM, color: PHColor.muted)
                }
            } else {
                VStack(spacing: PHSpacing.s8) {
                    ForEach(viewModel.recomendaciones) { recomendacion in
                        // Tocarla lleva DIRECTO a resolverla (editar el hospedaje, reactivarlo,
                        // o revisar sus solicitudes) — ver `abrir(_:)`.
                        Button { abrir(recomendacion.accion) } label: {
                            HStack(alignment: .top, spacing: PHSpacing.s12) {
                                Image(systemName: recomendacion.icono)
                                    .foregroundStyle(PHColor.primary)
                                    .frame(width: 20)
                                Text(recomendacion.texto)
                                    .phText(PHFont.bodySM, color: PHColor.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(PHColor.mutedSoft)
                                    .font(.caption)
                            }
                            .padding(PHSpacing.s12)
                            .background(PHColor.surfaceSoft)
                            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
