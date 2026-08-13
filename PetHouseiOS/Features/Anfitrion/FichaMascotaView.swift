//
//  FichaMascotaView.swift
//  Features/Anfitrion
//
//  Ficha completa de una mascota — el anfitrión la abre desde una solicitud de reserva
//  (ver ReservasRecibidasView) para evaluar si puede aceptarla: edad, raza, tamaño, peso,
//  si tiene vacunas al día y si necesita medicamentos, antes de tocar Aceptar/Rechazar.
//

import SwiftUI

struct FichaMascotaView: View {
    let mascota: Mascota
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    encabezado

                    seccionDatos

                    seccionSalud

                    if let notas = mascota.notas, !notas.isEmpty {
                        seccionNotas(notas)
                    }
                }
                .padding(PHSpacing.s16)
            }
            .background(PHColor.canvas)
            .navigationTitle("Ficha de la mascota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var encabezado: some View {
        HStack(spacing: PHSpacing.s16) {
            ZStack {
                Circle().fill(PHColor.primaryContainer)
                Image(systemName: iconoEspecie)
                    .font(.title)
                    .foregroundStyle(PHColor.onPrimaryContainer)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(mascota.nombre)
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text(mascota.especie.capitalized)
                    .phText(PHFont.bodySM, color: PHColor.muted)
            }
            Spacer()
        }
    }

    private var seccionDatos: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Datos")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: PHSpacing.s8) {
                if let raza = mascota.raza, !raza.isEmpty {
                    fila("Raza", raza)
                }
                if let edad = mascota.edad {
                    fila("Edad", "\(edad) año\(edad == 1 ? "" : "s")")
                }
                if let tamano = mascota.tamanoLegible {
                    fila("Tamaño", tamano)
                }
                if let peso = mascota.pesoKg {
                    fila("Peso", String(format: "%.1f kg", peso))
                }
                if mascota.raza == nil && mascota.edad == nil && mascota.tamano == nil && mascota.pesoKg == nil {
                    Text("El huésped no agregó más datos de \(mascota.nombre).")
                        .phText(PHFont.bodySM, color: PHColor.mutedSoft)
                }
            }
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private var seccionSalud: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s12) {
            Text("Salud")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                HStack {
                    Image(systemName: mascota.vacunasDia ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(mascota.vacunasDia ? PHColor.success : PHColor.mutedSoft)
                    Text(mascota.vacunasDia ? "Vacunas al día" : "Vacunas no confirmadas al día")
                        .phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                }
                HStack {
                    Image(systemName: mascota.necesitaMedicamentos ? "pills.fill" : "checkmark")
                        .foregroundStyle(mascota.necesitaMedicamentos ? PHColor.warning : PHColor.success)
                    Text(mascota.necesitaMedicamentos ? "Necesita tomar medicamentos" : "No necesita medicamentos")
                        .phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
                }
            }
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private func seccionNotas(_ notas: String) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text(mascota.necesitaMedicamentos ? "Detalle de los medicamentos" : "Notas")
                .phText(PHFont.titleMD, color: PHColor.ink)
            Text(notas)
                .phText(PHFont.bodySM, color: PHColor.body)
        }
        .padding(PHSpacing.s16)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
    }

    private func fila(_ etiqueta: String, _ valor: String) -> some View {
        HStack {
            Text(etiqueta).phText(PHFont.bodySM, color: PHColor.muted)
            Spacer()
            Text(valor).phText(PHFont.bodySM.weight(.medium), color: PHColor.ink)
        }
    }

    private var iconoEspecie: String {
        switch mascota.especie.lowercased() {
        case "perro": "pawprint.fill"
        case "gato": "cat.fill"
        default: "pawprint"
        }
    }
}
