//
//  NuevaReservaView.swift
//  Features/Reserva
//

import SwiftUI

struct NuevaReservaView: View {
    @State private var viewModel: NuevaReservaViewModel
    @Environment(\.dismiss) private var dismiss

    init(hospedaje: Hospedaje) {
        _viewModel = State(initialValue: NuevaReservaViewModel(hospedaje: hospedaje))
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
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                Text(viewModel.hospedaje.titulo)
                    .phText(PHFont.titleMD, color: PHColor.ink)

                DatePicker(
                    "Llegada",
                    selection: $viewModel.desde,
                    in: Date.now...,
                    displayedComponents: .date
                )
                DatePicker(
                    "Salida",
                    selection: $viewModel.hasta,
                    in: viewModel.desde...,
                    displayedComponents: .date
                )

                if !viewModel.fechasValidas {
                    Text("La fecha de salida debe ser posterior a la de llegada.")
                        .phText(PHFont.captionSM, color: PHColor.error)
                }

                Stepper(
                    "Mascotas: \(viewModel.mascotasSeleccionadas)",
                    value: $viewModel.mascotasSeleccionadas,
                    in: 1...viewModel.maxMascotas
                )
                Text("Este hospedaje admite máximo \(viewModel.maxMascotas) mascota(s).")
                    .phText(PHFont.micro, color: PHColor.mutedSoft)

                Divider()

                VStack(alignment: .leading, spacing: PHSpacing.s8) {
                    Text("Resumen estimado")
                        .phText(PHFont.titleMD, color: PHColor.ink)
                    filaResumen("Precio por noche", PHFormato.precio(viewModel.hospedaje.precioNoche))
                    filaResumen("Noches", "\(viewModel.noches)")
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

                PHPrimaryButton("Confirmar reserva", isLoading: viewModel.isLoading) {
                    Task { await viewModel.confirmar() }
                }
                .disabled(!viewModel.puedeReservar)
            }
            .padding(PHSpacing.s16)
        }
    }

    private func confirmacion(_ respuesta: CrearReservaResponse) -> some View {
        VStack(spacing: PHSpacing.s16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(PHColor.success)
            Text("¡Reserva confirmada!")
                .phText(PHFont.displaySM, color: PHColor.ink)
            Text("Código \(respuesta.reserva.codigo)")
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.muted)

            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                filaResumen("Noches", "\(respuesta.detalle.noches)")
                filaResumen("Total", PHFormato.precio(respuesta.reserva.total ?? viewModel.estimadoTotal), destacado: true)
            }
            .padding(PHSpacing.s16)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))

            Text("Reserva confirmada — el pago se coordina directamente con el anfitrión. PetHouse no procesa cobros en esta versión de la app.")
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
