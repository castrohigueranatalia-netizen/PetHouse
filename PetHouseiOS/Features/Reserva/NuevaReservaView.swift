//
//  NuevaReservaView.swift
//  Features/Reserva
//

import SwiftUI

struct NuevaReservaView: View {
    @State private var viewModel: NuevaReservaViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @State private var mascotaParaCompletar: Mascota?

    init(hospedaje: Hospedaje, mascotasDisponibles: [Mascota]) {
        _viewModel = State(initialValue: NuevaReservaViewModel(hospedaje: hospedaje, mascotasDisponibles: mascotasDisponibles))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let confirmada = viewModel.reservaConfirmada {
                    confirmacion(confirmada)
                } else {
                    formulario
                }
            }
            .navigationTitle("Reservar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
        // `mascotasDisponibles` es un snapshot tomado al abrir esta pantalla — al volver de
        // completar una ficha, hay que refrescarlo a mano con lo último de la sesión.
        .sheet(item: $mascotaParaCompletar, onDismiss: {
            viewModel.actualizarMascotas(session.mascotas)
        }) { mascota in
            MascotaFormView(mascota: mascota, session: session)
        }
        .task { await viewModel.cargarDisponibilidad() }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                Text(viewModel.hospedaje.titulo)
                    .phText(PHFont.titleMD, color: PHColor.ink)

                if viewModel.ofreceMismoDia {
                    Picker("Tipo de reserva", selection: $viewModel.mismoDia) {
                        Text("Por noches").tag(false)
                        Text("Mismo día").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if viewModel.mismoDia {
                        Text("Dejas a tu mascota y la recoges esa misma noche, sin que se quede a dormir.")
                            .phText(PHFont.captionSM, color: PHColor.muted)
                    }
                }

                PHSelectorRangoFechas(
                    desde: $viewModel.desde,
                    hasta: $viewModel.hasta,
                    soloUnDia: viewModel.mismoDia,
                    diaOcupado: { viewModel.diaOcupado($0) }
                )

                if !viewModel.fechasValidas {
                    Text("La fecha de salida debe ser posterior a la de llegada.")
                        .phText(PHFont.captionSM, color: PHColor.error)
                } else if viewModel.rangoOcupado {
                    Text("Esas fechas ya no están disponibles — elige otras.")
                        .phText(PHFont.captionSM, color: PHColor.error)
                }

                seccionHorarios

                seccionMascotas

                Divider()

                VStack(alignment: .leading, spacing: PHSpacing.s8) {
                    Text("Resumen estimado")
                        .phText(PHFont.titleMD, color: PHColor.ink)
                    if viewModel.mismoDia {
                        filaResumen("Precio por día", PHFormato.precio(viewModel.precioBase))
                        filaResumen("Duración", "Mismo día")
                    } else {
                        filaResumen("Precio por noche", PHFormato.precio(viewModel.precioBase))
                        filaResumen("Noches", "\(viewModel.noches)")
                    }
                    filaResumen("Limpieza (estimado)", PHFormato.precio(viewModel.estimadoLimpieza))
                    filaResumen("Servicio (estimado)", PHFormato.precio(viewModel.estimadoServicio))
                    Divider()
                    filaResumen("Total estimado", PHFormato.precio(viewModel.estimadoTotal), destacado: true)
                    Text("El total final lo confirma el servidor al reservar.")
                        .phText(PHFont.micro, color: PHColor.mutedSoft)
                }
                .padding(PHSpacing.s16)
                .background(PHColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

                Text("El pago se coordina directamente con el anfitrión — PetHouse todavía no procesa cobros en la app.")
                    .phText(PHFont.captionSM, color: PHColor.muted)

                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton("Enviar solicitud", isLoading: viewModel.isLoading) {
                    Task { await viewModel.confirmar() }
                }
                .disabled(!viewModel.puedeReservar)
            }
            .padding(PHSpacing.s16)
        }
    }

    /// El anfitrión necesita saber a qué hora esperar al huésped, no solo qué días — antes
    /// solo se pedían las fechas (ver db/36-horarios-entrega.sql). Aplica tanto a "por
    /// noches" (entrega el día de llegada, recogida el día de salida — días DISTINTOS, así
    /// que no se comparan entre sí) como a "mismo día" (las dos caen el mismo día, ver
    /// `NuevaReservaViewModel.horasValidas`). Chips con horas concretas en vez de una rueda de
    /// reloj libre — más rápido de tocar, y ya acotado al rango que el anfitrión configuró
    /// para este hospedaje (ver `opcionesEntrega`/`opcionesRecogida`, db/37-horarios-hospedaje.sql).
    private var seccionHorarios: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("¿A qué hora?")
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)

            selectorHora(
                titulo: viewModel.mismoDia ? "La llevas" : "Llegas ese día",
                opciones: viewModel.opcionesEntrega,
                seleccionada: viewModel.horaEntrega
            ) { viewModel.horaEntrega = $0 }

            selectorHora(
                titulo: viewModel.mismoDia ? "La recoges" : "La recoges ese día",
                opciones: viewModel.opcionesRecogida,
                seleccionada: viewModel.horaRecogida
            ) { viewModel.horaRecogida = $0 }

            if viewModel.horaEntrega == nil || viewModel.horaRecogida == nil {
                Text("Elige a qué hora llevas y a qué hora recoges a tu mascota.")
                    .phText(PHFont.captionSM, color: PHColor.muted)
            } else if !viewModel.horasValidas {
                Text("La hora de recogida debe ser posterior a la de entrega.")
                    .phText(PHFont.captionSM, color: PHColor.error)
            }
        }
    }

    private func selectorHora(titulo: String, opciones: [String], seleccionada: String?, onSeleccionar: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s4) {
            Text(titulo).phText(PHFont.captionSM, color: PHColor.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PHSpacing.s8) {
                    ForEach(opciones, id: \.self) { opcion in
                        PHChip(PHDate.displayFromAPITimeOnly(opcion), isSelected: seleccionada == opcion) {
                            onSeleccionar(opcion)
                        }
                    }
                }
            }
        }
    }

    private var seccionMascotas: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("¿Quién va?")
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)

            if viewModel.mascotasDisponibles.isEmpty {
                Text("Agrega una mascota en tu perfil antes de reservar.")
                    .phText(PHFont.bodySM, color: PHColor.error)
            } else {
                VStack(spacing: PHSpacing.s8) {
                    ForEach(viewModel.mascotasDisponibles) { mascota in
                        filaMascota(mascota)
                    }
                }
                Text("Este hospedaje admite máximo \(viewModel.maxMascotas) mascota(s).")
                    .phText(PHFont.micro, color: PHColor.mutedSoft)
            }
        }
    }

    @ViewBuilder
    private func filaMascota(_ mascota: Mascota) -> some View {
        if mascota.fichaCompleta {
            let seleccionada = viewModel.mascotaIdsSeleccionadas.contains(mascota.id)
            Button {
                viewModel.alternar(mascota)
            } label: {
                HStack(spacing: PHSpacing.s12) {
                    Image(systemName: seleccionada ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(seleccionada ? PHColor.primary : PHColor.mutedSoft)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mascota.nombre)
                            .phText(PHFont.bodyMD.weight(.medium), color: PHColor.ink)
                        if let raza = mascota.raza, !raza.isEmpty {
                            Text(raza)
                                .phText(PHFont.captionSM, color: PHColor.muted)
                        }
                    }
                    Spacer()
                }
                .padding(PHSpacing.s12)
                .background(PHColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            // No se puede seleccionar — tocarla lleva directo a completar su ficha (raza,
            // edad, tamaño, peso y una foto), no a "elegirla" a medio llenar.
            Button {
                mascotaParaCompletar = mascota
            } label: {
                HStack(spacing: PHSpacing.s12) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(PHColor.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mascota.nombre)
                            .phText(PHFont.bodyMD.weight(.medium), color: PHColor.muted)
                        Text("Falta \(mascota.camposFaltantes.joined(separator: ", "))")
                            .phText(PHFont.captionSM, color: PHColor.warning)
                    }
                    Spacer()
                    Text("Completar")
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.primary)
                }
                .padding(PHSpacing.s12)
                .background(PHColor.surfaceSoft.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func confirmacion(_ respuesta: CrearReservaResponse) -> some View {
        VStack(spacing: PHSpacing.s16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(PHColor.success)
            Text("¡Solicitud enviada!")
                .phText(PHFont.displaySM, color: PHColor.ink)
            Text("Código \(respuesta.reserva.codigo)")
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.muted)

            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                if respuesta.reserva.esMismoDia {
                    filaResumen("Duración", "Mismo día")
                } else {
                    filaResumen("Noches", "\(respuesta.detalle.noches)")
                }
                filaResumen("Total", PHFormato.precio(respuesta.reserva.total ?? viewModel.estimadoTotal), destacado: true)
            }
            .padding(PHSpacing.s16)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

            Text("Tu solicitud quedó pendiente — el anfitrión debe aceptarla. Revisa el estado en \"Mis reservas\". El pago se coordina directamente con el anfitrión; PetHouse no procesa cobros en esta versión de la app.")
                .phText(PHFont.bodySM, color: PHColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PHSpacing.s16)

            PHPrimaryButton("Ver mis reservas") { dismiss() }
                .padding(.horizontal, PHSpacing.s32)
        }
        .padding(.top, PHSpacing.s32)
        .frame(maxWidth: .infinity)
    }

    private func filaResumen(_ titulo: String, _ valor: String, destacado: Bool = false) -> some View {
        HStack {
            Text(titulo).phText(destacado ? PHFont.bodyMD.weight(.semibold) : PHFont.bodySM, color: destacado ? PHColor.ink : PHColor.muted)
            Spacer()
            Text(valor).phText(destacado ? PHFont.bodyMD.weight(.bold) : PHFont.bodySM, color: PHColor.ink)
        }
    }
}
