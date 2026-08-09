//
//  PublicarHospedajeView.swift
//  Features/Anfitrion
//

import SwiftUI

struct PublicarHospedajeView: View {
    let alPublicar: (HospedajeCreado) -> Void

    @State private var viewModel = PublicarHospedajeViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let publicado = viewModel.publicado {
                    exito(publicado)
                } else {
                    formulario
                }
            }
            .navigationTitle("Publicar hospedaje")
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

                PHTextField(label: "Ciudad", placeholder: "Ej. Bogotá", text: $viewModel.ciudad)
                PHTextField(label: "Barrio (opcional)", placeholder: "Ej. Chapinero", text: $viewModel.barrio)

                HStack {
                    PHTextField(label: "Latitud", placeholder: "4.71", text: $viewModel.latTexto, keyboardType: .numbersAndPunctuation)
                    PHTextField(label: "Longitud", placeholder: "-74.07", text: $viewModel.lngTexto, keyboardType: .numbersAndPunctuation)
                }
                PHSecondaryButton("Usar mi ubicación actual", systemImage: "location") {
                    Task { await viewModel.usarUbicacionActual() }
                }

                PHTextField(label: "Precio por noche (COP)", placeholder: "Ej. 60000", text: $viewModel.precioNocheTexto, keyboardType: .numberPad)

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
                PHTextField(label: "Reglas (separadas por coma)", placeholder: "no fumar, correa obligatoria", text: $viewModel.reglasTexto)

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    PHTextField(label: "Fotos: URLs separadas por coma (opcional)", placeholder: "https://…, https://…", text: $viewModel.fotosURLsTexto)
                    Text("Todavía no hay subida de fotos desde la app — pega URLs de imágenes ya alojadas en otro lado. Ver README.")
                        .phText(PHFont.micro, color: PHColor.mutedSoft)
                }

                if let error = viewModel.error {
                    Text(error.localizedDescription).phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton("Publicar", isLoading: viewModel.isLoading) {
                    Task { await viewModel.publicar() }
                }
                .disabled(!viewModel.puedePublicar)
            }
            .padding(PHSpacing.s16)
        }
    }

    private func exito(_ publicado: HospedajeCreado) -> some View {
        VStack(spacing: PHSpacing.s16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(PHColor.success)
            Text("¡Hospedaje publicado!")
                .phText(PHFont.displaySM, color: PHColor.ink)
            Text(publicado.titulo)
                .phText(PHFont.bodyMD, color: PHColor.muted)
            PHPrimaryButton("Listo") {
                alPublicar(publicado)
                dismiss()
            }
            .padding(.horizontal, PHSpacing.s32)
        }
        .padding(.top, PHSpacing.s32)
        .frame(maxWidth: .infinity)
    }
}
