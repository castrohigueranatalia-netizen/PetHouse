//
//  PublicarHospedajeView.swift
//  Features/Anfitrion
//
//  Sirve para publicar un hospedaje nuevo y para editar uno existente — ver
//  PublicarHospedajeViewModel.hospedajeExistente. `alGuardar` recibe el `Hospedaje` final en
//  ambos casos, para que MisHospedajesView pueda insertarlo o reemplazarlo en su lista.
//

import SwiftUI

struct PublicarHospedajeView: View {
    let alGuardar: (Hospedaje) -> Void

    @State private var viewModel: PublicarHospedajeViewModel
    @Environment(\.dismiss) private var dismiss

    init(hospedajeExistente: Hospedaje? = nil, alGuardar: @escaping (Hospedaje) -> Void) {
        self.alGuardar = alGuardar
        _viewModel = State(initialValue: PublicarHospedajeViewModel(hospedajeExistente: hospedajeExistente))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let guardado = viewModel.guardado {
                    exito(guardado)
                } else {
                    formulario
                }
            }
            .navigationTitle(viewModel.esEdicion ? "Editar hospedaje" : "Publicar hospedaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
                }
            }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s16) {
                PHAdjuntarFotos(
                    titulo: "Fotos del hospedaje",
                    subtitulo: "Ayudan a los dueños a confiar en el espacio antes de reservar.",
                    maximo: 8,
                    urls: Binding(get: { viewModel.fotos }, set: { viewModel.fotos = $0 }),
                    subir: { await viewModel.subirFoto($0) }
                )

                PHTextField(label: "Título", placeholder: "Ej. Guardería La Huellita", text: $viewModel.titulo)

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Tipo").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    Picker("Tipo", selection: $viewModel.tipo) {
                        ForEach(TipoHospedaje.allCases) { tipo in
                            Text(tipo.etiqueta).tag(tipo)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Descripción").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    TextEditor(text: $viewModel.descripcion)
                        .frame(minHeight: 100)
                        .padding(PHSpacing.s8)
                        .background(PHColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                }

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Localidad").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    Picker("Localidad", selection: $viewModel.localidad) {
                        Text("Elige una localidad").tag(Localidad?.none)
                        ForEach(Localidad.allCases) { localidad in
                            Text(localidad.etiqueta).tag(Localidad?.some(localidad))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PHColor.ink)
                }
                PHTextField(label: "Barrio (opcional)", placeholder: "Ej. Chapinero Alto", text: $viewModel.barrio)

                HStack {
                    PHTextField(label: "Latitud", placeholder: "4.71", text: $viewModel.latTexto, keyboardType: .numbersAndPunctuation)
                    PHTextField(label: "Longitud", placeholder: "-74.07", text: $viewModel.lngTexto, keyboardType: .numbersAndPunctuation)
                }
                PHSecondaryButton("Usar mi ubicación actual", systemImage: "location") {
                    Task { await viewModel.usarUbicacionActual() }
                }

                PHTextField(label: "Precio por noche (COP)", placeholder: "Ej. 60000", text: $viewModel.precioNocheTexto, keyboardType: .numberPad)

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    PHTextField(
                        label: "Precio por un solo día (COP, opcional)",
                        placeholder: "Ej. 35000",
                        text: $viewModel.precioDiaTexto,
                        keyboardType: .numberPad
                    )
                    Text("Para huéspedes que dejan a su mascota en la mañana y la recogen esa misma noche, sin quedarse a dormir. Déjalo vacío si no ofreces esta opción.")
                        .phText(PHFont.captionSM, color: PHColor.muted)
                }

                rangoHorario(
                    titulo: "Limitar horario de entrega",
                    descripcion: "Ej. de 7:00 a 9:00. Sin activar esto, el huésped puede elegir cualquier hora al reservar.",
                    desde: $viewModel.horarioEntregaDesde, hasta: $viewModel.horarioEntregaHasta,
                    defaultDesde: horaPorDefecto(7), defaultHasta: horaPorDefecto(9)
                )

                rangoHorario(
                    titulo: "Limitar horario de recogida",
                    descripcion: "Ej. de 18:00 a 19:00.",
                    desde: $viewModel.horarioRecogidaDesde, hasta: $viewModel.horarioRecogidaHasta,
                    defaultDesde: horaPorDefecto(18), defaultHasta: horaPorDefecto(19)
                )

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Convivencia").phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    Picker("Convivencia", selection: $viewModel.convivencia) {
                        ForEach(Convivencia.allCases) { opcion in
                            Text(opcion.etiqueta).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                PHTextField(label: "Máximo de mascotas", placeholder: "1", text: $viewModel.maxMascotasTexto, keyboardType: .numberPad)
                PHTextField(label: "Servicios (separados por coma)", placeholder: "paseos, alimentación, monitoreo", text: $viewModel.serviciosTexto)
                PHTextField(label: "Condiciones / reglas (separadas por coma)", placeholder: "no fumar, correa obligatoria", text: $viewModel.reglasTexto)

                if let error = viewModel.error {
                    Text(error.localizedDescription).phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton(viewModel.esEdicion ? "Guardar cambios" : "Publicar", isLoading: viewModel.isLoading) {
                    Task { await viewModel.guardar() }
                }
                .disabled(!viewModel.puedeGuardar)
            }
            .padding(PHSpacing.s16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Rango de horas en que este hospedaje acepta entrega/recogida (ver
    /// db/37-horarios-hospedaje.sql) — con el interruptor apagado, `desde`/`hasta` quedan en
    /// `nil` (sin restricción, el huésped elige cualquier hora al reservar); al activarlo se
    /// llenan con valores por defecto que el anfitrión puede ajustar.
    private func rangoHorario(
        titulo: String, descripcion: String,
        desde: Binding<Date?>, hasta: Binding<Date?>,
        defaultDesde: Date, defaultHasta: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Toggle(titulo, isOn: Binding(
                get: { desde.wrappedValue != nil },
                set: { activo in
                    desde.wrappedValue = activo ? defaultDesde : nil
                    hasta.wrappedValue = activo ? defaultHasta : nil
                }
            ))
            Text(descripcion).phText(PHFont.captionSM, color: PHColor.muted)
            if desde.wrappedValue != nil {
                HStack(spacing: PHSpacing.s16) {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text("Desde").phText(PHFont.captionSM, color: PHColor.muted)
                        DatePicker(
                            "", selection: Binding(get: { desde.wrappedValue ?? defaultDesde }, set: { desde.wrappedValue = $0 }),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text("Hasta").phText(PHFont.captionSM, color: PHColor.muted)
                        DatePicker(
                            "", selection: Binding(get: { hasta.wrappedValue ?? defaultHasta }, set: { hasta.wrappedValue = $0 }),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                    Spacer()
                }
            }
        }
    }

    private func horaPorDefecto(_ hora: Int) -> Date {
        Calendar.current.date(bySettingHour: hora, minute: 0, second: 0, of: .now) ?? .now
    }

    private func exito(_ guardado: Hospedaje) -> some View {
        VStack(spacing: PHSpacing.s16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(PHColor.success)
            Text(viewModel.esEdicion ? "¡Cambios guardados!" : "¡Hospedaje publicado!")
                .phText(PHFont.displaySM, color: PHColor.ink)
            Text(guardado.titulo)
                .phText(PHFont.bodyMD, color: PHColor.muted)
            PHPrimaryButton("Listo") {
                alGuardar(guardado)
                dismiss()
            }
            .padding(.horizontal, PHSpacing.s32)
        }
        .padding(.top, PHSpacing.s32)
        .frame(maxWidth: .infinity)
    }
}
